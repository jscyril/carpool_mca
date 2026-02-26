// ============================================================
// UniRide Admin — app.js
// Handles API calls, state management, and DOM rendering.
// ============================================================

const API_BASE = 'http://localhost:8000'; // Change to Render URL for production

let state = {
    accessToken: null,
    sessionToken: null,
    phone: null,
    users: [],
    currentVerificationType: 'identity',
};

// Init: restore session if tokens saved
window.addEventListener('load', () => {
    const saved = localStorage.getItem('admin_access_token');
    if (saved) {
        state.accessToken = saved;
        showMainPage();
        loadStats();
    }
});

// ── Auth helpers ──────────────────────────────────────────────────

function apiHeaders(auth = false) {
    const h = { 'Content-Type': 'application/json' };
    if (auth && state.accessToken) h['Authorization'] = `Bearer ${state.accessToken}`;
    return h;
}

async function apiFetch(path, opts = {}) {
    try {
        const resp = await fetch(`${API_BASE}${path}`, opts);
        const text = await resp.text();
        let data = null;
        try { data = JSON.parse(text); } catch (_) { }
        return { ok: resp.ok, status: resp.status, data };
    } catch (e) {
        return { ok: false, status: 0, data: { detail: 'Cannot connect to server' } };
    }
}

// ── Login flow ────────────────────────────────────────────────────

async function sendOtp() {
    const phoneEl = document.getElementById('phone-input');
    const phone = '+91' + phoneEl.value.trim();
    if (phoneEl.value.trim().length < 10) return showError('phone-error', 'Enter a valid 10-digit number');

    setLoading('send-otp-btn', true);
    const res = await apiFetch('/auth/login/send-otp', {
        method: 'POST',
        headers: apiHeaders(),
        body: JSON.stringify({ phone }),
    });
    setLoading('send-otp-btn', false);

    if (res.ok && res.data?.session_token) {
        state.sessionToken = res.data.session_token;
        state.phone = phone;
        document.getElementById('otp-phone-display').textContent = phone;
        document.getElementById('step-phone').classList.add('hidden');
        document.getElementById('step-otp').classList.remove('hidden');
        hideError('phone-error');
    } else {
        showError('phone-error', res.data?.detail || 'Failed to send OTP');
    }
}

async function verifyOtp() {
    const otp = document.getElementById('otp-input').value.trim();
    if (otp.length !== 6) return showError('otp-error', 'Enter the 6-digit OTP');

    setLoading('verify-otp-btn', true);
    const res = await apiFetch('/auth/login/verify-otp', {
        method: 'POST',
        headers: apiHeaders(),
        body: JSON.stringify({ session_token: state.sessionToken, otp }),
    });
    setLoading('verify-otp-btn', false);

    if (res.ok && res.data?.access_token) {
        // Verify this user is admin
        state.accessToken = res.data.access_token;
        const meRes = await apiFetch('/users/me', { headers: apiHeaders(true) });
        if (!meRes.ok || !meRes.data?.is_admin) {
            state.accessToken = null;
            showError('otp-error', 'Access denied. This account is not an admin.');
            return;
        }
        localStorage.setItem('admin_access_token', state.accessToken);
        if (res.data.refresh_token) {
            localStorage.setItem('admin_refresh_token', res.data.refresh_token);
        }
        showMainPage();
        loadStats();
    } else {
        showError('otp-error', res.data?.detail || 'Invalid OTP');
    }
}

function backToPhone() {
    document.getElementById('step-otp').classList.add('hidden');
    document.getElementById('step-phone').classList.remove('hidden');
}

function logout() {
    const rt = localStorage.getItem('admin_refresh_token');
    if (rt) {
        fetch(`${API_BASE}/auth/logout`, {
            method: 'POST',
            headers: apiHeaders(),
            body: JSON.stringify({ refresh_token: rt }),
        }).catch(() => { });
    }
    localStorage.removeItem('admin_access_token');
    localStorage.removeItem('admin_refresh_token');
    state.accessToken = null;
    document.getElementById('login-page').classList.remove('hidden');
    document.getElementById('login-page').classList.add('active');
    document.getElementById('main-page').classList.add('hidden');
    document.getElementById('main-page').classList.remove('active');
}

// ── Navigation ────────────────────────────────────────────────────

function showMainPage() {
    document.getElementById('login-page').classList.add('hidden');
    document.getElementById('login-page').classList.remove('active');
    document.getElementById('main-page').classList.remove('hidden');
    document.getElementById('main-page').classList.add('active');
}

function showSection(name, el) {
    document.querySelectorAll('.section').forEach(s => {
        s.classList.remove('active');
        s.classList.add('hidden');
    });
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
    document.getElementById(`section-${name}`).classList.remove('hidden');
    document.getElementById(`section-${name}`).classList.add('active');
    if (el) el.classList.add('active');

    // Lazy-load section data
    if (name === 'dashboard') loadStats();
    if (name === 'users') loadUsers();
    if (name === 'verifications') loadVerifications();
    if (name === 'sos') loadSos();
}

// ── Dashboard Stats ───────────────────────────────────────────────

async function loadStats() {
    const res = await apiFetch('/admin/stats', { headers: apiHeaders(true) });
    if (!res.ok) return;
    const d = res.data;
    document.getElementById('stats-grid').innerHTML = `
    <div class="stat-card">
      <div class="stat-icon">👥</div>
      <div class="stat-value">${d.users.total}</div>
      <div class="stat-label">Total Users</div>
    </div>
    <div class="stat-card">
      <div class="stat-icon">✅</div>
      <div class="stat-value">${d.users.active}</div>
      <div class="stat-label">Active Users</div>
    </div>
    <div class="stat-card">
      <div class="stat-icon">🪪</div>
      <div class="stat-value">${d.users.identity_verified}</div>
      <div class="stat-label">Identity Verified</div>
    </div>
    <div class="stat-card">
      <div class="stat-icon">🚗</div>
      <div class="stat-value">${d.users.driver_verified}</div>
      <div class="stat-label">Drivers Verified</div>
    </div>
    <div class="stat-card accent">
      <div class="stat-icon">⏳</div>
      <div class="stat-value">${d.verifications.pending_identity + d.verifications.pending_driver}</div>
      <div class="stat-label">Pending Reviews</div>
    </div>
    <div class="stat-card">
      <div class="stat-icon">🛣️</div>
      <div class="stat-value">${d.rides.active_open}</div>
      <div class="stat-label">Open Rides</div>
    </div>
    <div class="stat-card warn">
      <div class="stat-icon">🆘</div>
      <div class="stat-value">${d.sos.total_triggered}</div>
      <div class="stat-label">SOS Triggered</div>
    </div>
  `;
}

// ── Users ─────────────────────────────────────────────────────────

async function loadUsers() {
    const tbody = document.getElementById('users-tbody');
    tbody.innerHTML = '<tr><td colspan="7" class="loading-row">Loading users...</td></tr>';
    const res = await apiFetch('/admin/users?page_size=100', { headers: apiHeaders(true) });
    if (!res.ok) {
        tbody.innerHTML = `<tr><td colspan="7" class="error-row">${res.data?.detail || 'Error loading users'}</td></tr>`;
        return;
    }
    state.users = res.data;
    renderUsers(state.users);
}

function renderUsers(users) {
    const tbody = document.getElementById('users-tbody');
    if (!users.length) {
        tbody.innerHTML = '<tr><td colspan="7" class="empty-row">No users found</td></tr>';
        return;
    }
    tbody.innerHTML = users.map(u => `
    <tr>
      <td><strong>${esc(u.full_name)}</strong></td>
      <td>${esc(u.phone_number)}</td>
      <td>${u.email ? esc(u.email) : '<span class="badge badge-muted">None</span>'}</td>
      <td>${u.is_identity_verified ? '<span class="badge badge-green">✓</span>' : '<span class="badge badge-muted">✗</span>'}</td>
      <td>${u.is_driver_verified ? '<span class="badge badge-blue">✓</span>' : '<span class="badge badge-muted">✗</span>'}</td>
      <td>${u.is_active ? '<span class="badge badge-green">Active</span>' : '<span class="badge badge-red">Disabled</span>'}</td>
      <td>
        ${u.is_active
            ? `<button class="btn-sm btn-danger" onclick="deactivateUser('${u.user_id}')">Deactivate</button>`
            : `<button class="btn-sm btn-success" onclick="activateUser('${u.user_id}')">Activate</button>`}
      </td>
    </tr>
  `).join('');
}

function filterUsers() {
    const q = document.getElementById('user-search').value.toLowerCase();
    const filtered = state.users.filter(u =>
        u.full_name.toLowerCase().includes(q) ||
        u.phone_number.includes(q) ||
        (u.email || '').toLowerCase().includes(q)
    );
    renderUsers(filtered);
}

async function deactivateUser(userId) {
    if (!confirm('Deactivate this user?')) return;
    const res = await apiFetch(`/admin/users/${userId}/deactivate`, {
        method: 'PUT', headers: apiHeaders(true), body: JSON.stringify({}),
    });
    if (res.ok) { toast('User deactivated'); loadUsers(); }
    else toast(res.data?.detail || 'Error', true);
}

async function activateUser(userId) {
    const res = await apiFetch(`/admin/users/${userId}/activate`, {
        method: 'PUT', headers: apiHeaders(true), body: JSON.stringify({}),
    });
    if (res.ok) { toast('User activated'); loadUsers(); }
    else toast(res.data?.detail || 'Error', true);
}

// ── Verifications ─────────────────────────────────────────────────

async function loadVerifications() {
    state.currentVerificationType = 'identity';
    await fetchVerifications('identity');
}

function switchTab(type, el) {
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    if (el) el.classList.add('active');
    state.currentVerificationType = type;
    fetchVerifications(type);
}

async function fetchVerifications(type) {
    const container = document.getElementById('verifications-list');
    container.innerHTML = '<p class="loading-row">Loading...</p>';
    const res = await apiFetch(`/admin/verifications/${type}/pending`, { headers: apiHeaders(true) });
    if (!res.ok) { container.innerHTML = `<p class="error-row">${res.data?.detail || 'Error'}</p>`; return; }
    const items = res.data;
    if (!items.length) { container.innerHTML = '<p class="empty-state">No pending verifications 🎉</p>'; return; }
    container.innerHTML = items.map(v => `
    <div class="verification-card">
      <div class="vc-header">
        <div class="vc-avatar">${v.full_name.charAt(0).toUpperCase()}</div>
        <div>
          <div class="vc-name">${esc(v.full_name)}</div>
          <div class="vc-phone">${esc(v.phone_number)}</div>
          ${v.email ? `<div class="vc-email">${esc(v.email)}</div>` : ''}
        </div>
      </div>
      ${v.college_id_number ? `<div class="vc-field"><strong>College ID:</strong> ${esc(v.college_id_number)}</div>` : ''}
      ${v.license_number ? `<div class="vc-field"><strong>Licence No:</strong> ${esc(v.license_number)}</div>` : ''}
      ${v.document_url || v.license_document_url ? `
        <div class="vc-doc">
          <a href="${esc(v.document_url || v.license_document_url)}" target="_blank" class="doc-link">View Document ↗</a>
        </div>` : ''}
      <div class="vc-submitted">Submitted: ${formatDate(v.submitted_at)}</div>
      <div class="vc-actions">
        <button class="btn-sm btn-success" onclick="approveVerification('${v.user_id}', '${type}')">✓ Approve</button>
        <button class="btn-sm btn-danger" onclick="rejectVerification('${v.user_id}', '${type}')">✗ Reject</button>
      </div>
    </div>
  `).join('');
}

async function approveVerification(userId, type) {
    const res = await apiFetch(`/admin/verifications/${type}/${userId}/approve`, {
        method: 'PUT', headers: apiHeaders(true), body: JSON.stringify({ notes: null }),
    });
    if (res.ok) { toast(`${type} verification approved`); fetchVerifications(type); }
    else toast(res.data?.detail || 'Error', true);
}

async function rejectVerification(userId, type) {
    const notes = prompt('Rejection reason (optional):') || null;
    const res = await apiFetch(`/admin/verifications/${type}/${userId}/reject`, {
        method: 'PUT', headers: apiHeaders(true), body: JSON.stringify({ notes }),
    });
    if (res.ok) { toast(`${type} verification rejected`); fetchVerifications(type); }
    else toast(res.data?.detail || 'Error', true);
}

// ── SOS Alerts ────────────────────────────────────────────────────

async function loadSos() {
    const tbody = document.getElementById('sos-tbody');
    tbody.innerHTML = '<tr><td colspan="5" class="loading-row">Loading...</td></tr>';
    const res = await apiFetch('/admin/sos/active', { headers: apiHeaders(true) });
    if (!res.ok) { tbody.innerHTML = `<tr><td colspan="5" class="error-row">${res.data?.detail || 'Error'}</td></tr>`; return; }
    const alerts = res.data;
    if (!alerts.length) {
        tbody.innerHTML = '<tr><td colspan="5" class="empty-row">No active SOS alerts ✓</td></tr>';
        return;
    }
    tbody.innerHTML = alerts.map(a => `
    <tr class="sos-row">
      <td><code>${a.alert_id.substring(0, 8)}…</code></td>
      <td><code>${a.user_id.substring(0, 8)}…</code></td>
      <td><code>${a.ride_id.substring(0, 8)}…</code></td>
      <td>${formatDate(a.triggered_at)}</td>
      <td>${a.latitude && a.longitude
            ? `<a href="https://www.openstreetmap.org/?mlat=${a.latitude}&mlon=${a.longitude}&zoom=16" target="_blank" class="map-link">📍 View Map</a>`
            : 'Unknown'}</td>
    </tr>
  `).join('');
}

// ── Utility ───────────────────────────────────────────────────────

function esc(s) {
    if (!s) return '';
    return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function formatDate(iso) {
    if (!iso) return '—';
    try {
        return new Date(iso).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
    } catch (_) { return iso; }
}

function showError(id, msg) {
    const el = document.getElementById(id);
    if (el) { el.textContent = msg; el.classList.remove('hidden'); }
}

function hideError(id) {
    const el = document.getElementById(id);
    if (el) el.classList.add('hidden');
}

function setLoading(id, loading) {
    const el = document.getElementById(id);
    if (el) el.disabled = loading;
}

function toast(msg, isError = false) {
    const el = document.getElementById('toast');
    el.textContent = msg;
    el.className = 'toast' + (isError ? ' toast-error' : '');
    setTimeout(() => el.classList.add('hidden'), 3000);
}

// Auto-refresh SOS every 30 seconds when that section is active
setInterval(() => {
    const sosSection = document.getElementById('section-sos');
    if (sosSection && sosSection.classList.contains('active')) {
        loadSos();
    }
}, 30000);
