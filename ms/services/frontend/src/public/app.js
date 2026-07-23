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
  if (!res.ok) {
    const text = await res.text();
    try {
      const data = JSON.parse(text);
      throw new Error(data.error || data.message || 'Request failed');
    } catch (e) {
      throw new Error(text || `Request failed with status ${res.status}`);
    }
  }
  const data = await res.json().catch(() => ({})); // Gracefully handle empty responses
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
  const pollListEl = document.getElementById('poll-list');
  if (!pollListEl) return; // Do nothing if the poll list isn't on the page

  try {
    const polls = await api('/polls');
    pollListEl.innerHTML = polls.length === 0
      ? '<p style="color:var(--muted)">No polls yet.</p>'
      : polls.map(p => `
        <div class="poll-list-item">
          <div>
            <strong>${p.title}</strong>
            <span class="badge ${p.status}">${p.status}</span>
            <div style="color:var(--muted);font-size:0.85rem">/poll/${p.slug}</div>
          </div>
          <div class="action-row">${getAdminPollActions(p)}</div>
        </div>`).join('');
  } catch (err) {
    pollListEl.innerHTML = `<p class="error">${err.message}</p>`;
  }
}

function getAdminPollActions(poll) {
  let actions = `<button class="secondary" onclick="location.href='/poll/${poll.slug}'">View</button>`;
  if (poll.status === 'ACTIVE') actions += `<button onclick="updatePollStatus('${poll.slug}', 'PAUSED')">Pause</button>`;
  if (poll.status === 'PAUSED') actions += `<button onclick="updatePollStatus('${poll.slug}', 'ACTIVE')">Resume</button>`;
  if (poll.status === 'ACTIVE' || poll.status === 'PAUSED') actions += `<button onclick="updatePollStatus('${poll.slug}', 'ENDED')">End Now</button>`;
  if (poll.status === 'ENDED') actions += `<button onclick="updatePollStatus('${poll.slug}', 'PUBLISHED')">Publish Results</button>`;
  return actions;
}

async function updatePollStatus(slug, status) {
  if (!confirm(`Are you sure you want to set status to "${status}" for poll "${slug}"?`)) return;
  try {
    await api(`/polls/${slug}/status`, { method: 'PATCH', body: JSON.stringify({ status }) });
    await loadPolls(); // Refresh admin dashboard
    if (location.pathname.endsWith(slug)) {
      await renderPollPage(slug); // Refresh poll page if currently viewing
    }
  } catch (err) {
    alert(`Error: ${err.message}`);
  }
}

async function publishPollResults(slug) {
  if (!confirm(`Are you sure you want to publish the results for "${slug}"? This cannot be undone.`)) {
    return;
  }

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

    const isAdmin = !!token;
    const canVote = poll.status === 'ACTIVE' && !isAdmin;
    // An admin can see results for any poll that is not DRAFT or SCHEDULED.
    // The public can only see results if the poll is PUBLISHED.
    const showResults = poll.status === 'PUBLISHED' ||
      (isAdmin && ['ACTIVE', 'PAUSED', 'ENDED', 'PUBLISHED'].includes(poll.status));
    const showAdminActions = isAdmin && poll.status !== 'PUBLISHED';

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
      if (isAdmin && poll.status === 'ENDED') {
        body += `<p style="color:var(--muted);margin-top:1rem">Results are not yet public.</p>`;
      }
    } else if (poll.status === 'SCHEDULED') {
      body += `<p style="color:var(--muted)">This poll is scheduled to start at ${new Date(poll.startAt).toLocaleString()}.</p>`;
    } else if (poll.status === 'PAUSED') {
      body += `<p style="color:var(--muted)">Voting for this poll has been temporarily paused by the administrator.</p>`;
    } else {
      body += `<p style="color:var(--muted)">Voting for this poll has ended. Results will be available once published.</p>`;
    }

    let adminActionsHtml = '';
    if (showAdminActions) {
      adminActionsHtml = `<div class="admin-actions">${getAdminPollActions(poll)}</div>`;
    }
    document.getElementById('main').innerHTML = `<div class="card">${body}${adminActionsHtml}</div>`;

    if (showAdminActions) {
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
