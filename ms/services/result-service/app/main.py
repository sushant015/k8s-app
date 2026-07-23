import os
from contextlib import asynccontextmanager
from decimal import Decimal

import asyncpg
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql://votepoll:changeme@localhost:5432/votepoll",
)


class OptionResult(BaseModel):
    optionId: str
    label: str
    voteCount: int
    percentage: float


class PollResults(BaseModel):
    pollId: str
    slug: str
    totalVotes: int
    published: bool
    options: list[OptionResult]


pool: asyncpg.Pool | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global pool
    pool = await asyncpg.create_pool(DATABASE_URL, min_size=2, max_size=10)
    yield
    await pool.close()


app = FastAPI(title="result-service", lifespan=lifespan)


@app.get("/health")
async def health():
    if pool is None:
        raise HTTPException(status_code=503, detail="Pool not ready")
    async with pool.acquire() as conn:
        await conn.fetchval("SELECT 1")
    return {"status": "UP", "service": "result-service"}


async def compute_results(conn, slug: str) -> PollResults:
    poll = await conn.fetchrow(
        """
        SELECT p.id, p.slug, p.status
        FROM polls.polls p WHERE p.slug = $1
        """,
        slug,
    )
    if not poll:
        raise HTTPException(status_code=404, detail="Poll not found")

    options = await conn.fetch(
        """
        SELECT o.id, o.label, o.sort_order
        FROM polls.options o
        WHERE o.poll_id = $1
        ORDER BY o.sort_order
        """,
        poll["id"],
    )

    vote_counts = await conn.fetch(
        """
        SELECT option_id, COUNT(*) AS cnt
        FROM votes.votes
        WHERE poll_id = $1
        GROUP BY option_id
        """,
        poll["id"],
    )
    counts = {str(r["option_id"]): r["cnt"] for r in vote_counts}
    total = sum(counts.values())

    snapshot = await conn.fetchrow(
        "SELECT published FROM results.snapshots WHERE poll_id = $1",
        poll["id"],
    )
    published = snapshot["published"] if snapshot else poll["status"] == "PUBLISHED"

    option_results = []
    for opt in options:
        oid = str(opt["id"])
        cnt = counts.get(oid, 0)
        pct = round((cnt / total * 100) if total > 0 else 0, 2)
        option_results.append(
            OptionResult(
                optionId=oid,
                label=opt["label"],
                voteCount=cnt,
                percentage=float(pct),
            )
        )

    return PollResults(
        pollId=str(poll["id"]),
        slug=poll["slug"],
        totalVotes=total,
        published=published,
        options=option_results,
    )


@app.get("/results/{slug}", response_model=PollResults)
async def get_results(slug: str):
    async with pool.acquire() as conn:
        return await compute_results(conn, slug)


@app.post("/results/{slug}/compute")
async def compute_and_store(slug: str):
    async with pool.acquire() as conn:
        results = await compute_results(conn, slug)
        poll_id = results.pollId

        async with conn.transaction():
            snapshot_id = await conn.fetchval(
                """
                INSERT INTO results.snapshots (poll_id, total_votes, published, computed_at)
                VALUES ($1::uuid, $2, FALSE, NOW())
                ON CONFLICT (poll_id) DO UPDATE
                SET total_votes = EXCLUDED.total_votes, computed_at = NOW()
                RETURNING id
                """,
                poll_id,
                results.totalVotes,
            )

            await conn.execute(
                "DELETE FROM results.option_totals WHERE snapshot_id = $1",
                snapshot_id,
            )

            for opt in results.options:
                await conn.execute(
                    """
                    INSERT INTO results.option_totals
                    (snapshot_id, option_id, option_label, vote_count, percentage)
                    VALUES ($1, $2::uuid, $3, $4, $5)
                    """,
                    snapshot_id,
                    opt.optionId,
                    opt.label,
                    opt.voteCount,
                    Decimal(str(opt.percentage)),
                )

        return {"message": "Results computed", "totalVotes": results.totalVotes}


@app.post("/results/{slug}/publish")
async def publish_results(slug: str):
    async with pool.acquire() as conn:
        poll = await conn.fetchrow(
            "SELECT id, status FROM polls.polls WHERE slug = $1", slug
        )
        if not poll:
            raise HTTPException(status_code=404, detail="Poll not found")

        results = await compute_results(conn, slug)

        async with conn.transaction():
            await conn.execute(
                """
                INSERT INTO results.snapshots (poll_id, total_votes, published, published_at, computed_at)
                VALUES ($1, $2, TRUE, NOW(), NOW())
                ON CONFLICT (poll_id) DO UPDATE
                SET total_votes = EXCLUDED.total_votes,
                    published = TRUE,
                    published_at = NOW(),
                    computed_at = NOW()
                """,
                poll["id"],
                results.totalVotes,
            )
            await conn.execute(
                "UPDATE polls.polls SET status = 'PUBLISHED' WHERE id = $1",
                poll["id"],
            )

        return {"message": "Results published", "slug": slug}
