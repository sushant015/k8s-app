const API = window.APP_CONFIG?.apiBaseUrl || '/api';
let token = localStorage.getItem('token') || '';

function getVoterId() {
  let id = localStorage.getItem('voterId');
  if (!id) {
    id = crypto.randomUUID();
    localStorage.setItem('voterId', id);
  }
  return id;
}

async function api(path, options = {}) {
  const headers = { 'Content-Type': 'application/json', ...options.headers };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  if (options.voter) headers['X-Voter-Id'] = getVoterId();

  const res = await fetch(`${API}${path}`, { ...options, headers });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || data.message || 'Request failed');
  return data;
}

function route() {
  const path = location.pathname;
  if (path.startsWith('/poll/')) return renderPollPage(path.split('/')[2]);
  if (path === '/admin/login') return renderLogin();
  if (path === '/admin' || path === '/admin/') return renderAdminDashboard();
  return renderHome();
}

function renderNav() {
  const nav = document.getElementById('nav');
  nav.innerHTML = token
    ? `<a href="/admin">Dashboard</a> | <a href="#" id="logout">Logout</a>`
    : `<a href="/admin/login">Admin Login</a>`;
  document.getElementById('logout')?.addEventListener('click', (e) => {
    e.preventDefault();
    token = '';
    localStorage.removeItem('token');
    location.href = '/';
  });
}

function renderHome() {
  document.getElementById('main').innerHTML = `
    <div class="card">
      <h2>Welcome</h2>
      <p style="color:var(--muted);margin-bottom:1rem">
        Access a poll using its unique URL: <code>/poll/{slug}</code>
      </p>
      <p><a href="/admin/login">Admin Login</a> to create and manage polls.</p>
    </div>`;
}

function renderLogin() {
  document.getElementById('main').innerHTML = `
    <div class="card">
      <h2>Admin Login</h2>
      <div id="login-error" class="error"></div>
      <input id="email" type="email" placeholder="Email" value="admin@votepoll.local" />
      <input id="password" type="password" placeholder="Password (default: password)" />
      <button id="login-btn">Login</button>
    </div>`;

  document.getElementById('login-btn').addEventListener('click', async () => {
    try {
      const data = await api('/auth/login', {
        method: 'POST',
        body: JSON.stringify({
          email: document.getElementById('email').value,
          password: document.getElementById('password').value,
        }),
      });
      token = data.token;
      localStorage.setItem('token', token);
      location.href = '/admin';
    } catch (err) {
      document.getElementById('login-error').textContent = err.message;
    }
  });
}

async function renderAdminDashboard() {
  if (!token) { location.href = '/admin/login'; return; }

  document.getElementById('main').innerHTML = `
    <div class="card"><h2>Create Poll</h2>
      <div id="create-error" class="error"></div>
      <input id="title" placeholder="Poll Title" />
      <textarea id="description" placeholder="Description" rows="3"></textarea>
      <input id="slug" placeholder="URL Slug (e.g. team-lunch)" />
      <input id="startAt" type="datetime-local" />
      <input id="endAt" type="datetime-local" />
      <div id="options-container">
        <input class="option-input" placeholder="Option 1" />
        <input class="option-input" placeholder="Option 2" />
      </div>
      <button class="secondary" id="add-option">+ Add Option</button>
      <button id="create-poll">Create Poll</button>
    </div>
    <div class="card"><h2>Your Polls</h2><div id="poll-list">Loading...</div></div>`;

  document.getElementById('add-option').addEventListener('click', () => {
    const input = document.createElement('input');
    input.className = 'option-input';
    input.placeholder = 'Another option';
    document.getElementById('options-container').appendChild(input);
  });

  document.getElementById('create-poll').addEventListener('click', async () => {
    try {
      const options = [...document.querySelectorAll('.option-input')]
        .map(i => i.value.trim()).filter(Boolean);
      await api('/polls', {
        method: 'POST',
        body: JSON.stringify({
          title: document.getElementById('title').value,
          description: document.getElementById('description').value,
          slug: document.getElementById('slug').value,
          startAt: new Date(document.getElementById('startAt').value).toISOString(),
          endAt: new Date(document.getElementById('endAt').value).toISOString(),
          options,
        }),
      });
      loadPolls();
    } catch (err) {
      document.getElementById('create-error').textContent = err.message;
    }
  });

  loadPolls();
}

async function loadPolls() {
  try {
    const polls = await api('/polls');
    document.getElementById('poll-list').innerHTML = polls.length === 0
      ? '<p style="color:var(--muted)">No polls yet.</p>'
      : polls.map(p => `
        <div class="poll-list-item">
          <div>
            <strong>${p.title}</strong>
            <span class="badge ${p.status}">${p.status}</span>
            <div style="color:var(--muted);font-size:0.85rem">/poll/${p.slug}</div>
          </div>
          <div class="action-row">
            ${p.status !== 'PUBLISHED' && token ? `<button onclick="publishPollResults('${p.slug}')">Publish Results</button>` : ''}
            <button class="secondary" onclick="location.href='/poll/${p.slug}'">${p.status === 'ENDED' || p.status === 'PUBLISHED' ? 'View Results' : 'View Poll'}</button>
          </div>
        </div>`).join('');
  } catch (err) {
    document.getElementById('poll-list').innerHTML = `<p class="error">${err.message}</p>`;
  }
}

async function publishPollResults(slug) {
  try {
    await api(`/results/${slug}/publish`, { method: 'POST' });
    await loadPolls();
    if (location.pathname.startsWith('/poll/')) {
      await renderPollPage(slug);
    }
  } catch (err) {
    alert(err.message);
  }
}

async function renderPollPage(slug) {
  document.getElementById('main').innerHTML = '<div class="card">Loading poll...</div>';
  try {
    const poll = await api(`/polls/${slug}`);
    const now = new Date();
    const started = now >= new Date(poll.startAt);
    const ended = now > new Date(poll.endAt);
    const canVote = poll.status === 'ACTIVE' && started && !ended;
    const showResults = poll.status === 'PUBLISHED' || (token && ended);

    let body = `<h2>${poll.title}</h2>`;
    if (poll.description) body += `<p style="color:var(--muted);margin-bottom:1rem">${poll.description}</p>`;

    if (canVote) {
      body += `<div id="vote-error" class="error"></div>`;
      poll.options.forEach(o => {
        body += `<button class="option-btn" onclick="submitVote('${slug}','${o.id}')">${o.label}</button>`;
      });
    } else if (showResults) {
      const results = await api(`/results/${slug}`);
      body += `<p><strong>Total votes: ${results.totalVotes}</strong></p>`;
      results.options.forEach(o => {
        body += `<div class="bar-row">
          <div class="bar-label"><span>${o.label}</span><span>${o.voteCount} (${o.percentage}%)</span></div>
          <div class="bar-track"><div class="bar-fill" style="width:${o.percentage}%"></div></div>
        </div>`;
      });
      if (poll.status !== 'PUBLISHED') {
        body += `<p style="color:var(--muted);margin-top:1rem">Results are preliminary until published by admin.</p>`;
      }
      if (token && poll.status === 'ENDED') {
        body += `<button id="publish-results-btn" style="margin-top:1rem">Publish Results</button>`;
      }
    } else if (token && poll.status !== 'PUBLISHED') {
      // Admin view of an active or draft poll
      const results = await api(`/results/${slug}`);
      body += `<p>This poll is not yet published.</p>`;
      body += `<p><strong>Current vote count: ${results.totalVotes}</strong></p>`;
    } else {
      body += `<p style="color:var(--muted)">This poll is not yet open for voting.</p>`;
    }

    document.getElementById('main').innerHTML = `<div class="card">${body}</div>`;

    if (token && poll.status === 'ENDED') {
      document.getElementById('publish-results-btn')?.addEventListener('click', () => publishPollResults(slug));
    }
  } catch (err) {
    document.getElementById('main').innerHTML = `<div class="card"><p class="error">${err.message}</p></div>`;
  }
}

async function submitVote(slug, optionId) {
  try {
    await api(`/votes/${slug}`, {
      method: 'POST',
      voter: true,
      body: JSON.stringify({ optionId }),
    });
    document.getElementById('main').innerHTML = `<div class="card"><p class="success">Thank you! Your vote has been recorded.</p></div>`;
  } catch (err) {
    document.getElementById('vote-error').textContent = err.message;
  }
}

renderNav();
route();
