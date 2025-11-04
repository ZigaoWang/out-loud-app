const passwordRules = [
  { id: 'length', label: 'At least 8 characters', test: value => value.length >= 8 },
  { id: 'lower', label: 'Lowercase letter', test: value => /[a-z]/.test(value) },
  { id: 'upper', label: 'Uppercase letter', test: value => /[A-Z]/.test(value) },
  { id: 'digit', label: 'Number', test: value => /\d/.test(value) },
  { id: 'symbol', label: 'Symbol (e.g. !@#$)', test: value => /[^A-Za-z0-9]/.test(value) },
];

const ui = {};
const state = {
  supabase: null,
  authMode: 'sign-in',
  sessions: [],
  activeSession: null,
  passwordRecovery: false,
  pendingResendEmail: null,
};
let authTemporarilyHidden = false;

document.addEventListener('DOMContentLoaded', () => {
  cacheElements();
  bindUI();
  renderChecklist(ui.passwordChecklist);
  renderChecklist(ui.resetChecklist);
  bootstrapSupabase();
});

function cacheElements() {
  ui.statusBanner = document.getElementById('statusBanner');
  ui.statusPanel = document.getElementById('statusPanel');
  ui.authPanel = document.getElementById('authPanel');
  ui.appPanel = document.getElementById('appPanel');
  ui.detailPanel = document.getElementById('detailPanel');
  ui.authTabs = Array.from(document.querySelectorAll('.auth-tab'));
  ui.authForm = document.getElementById('authForm');
  ui.emailInput = document.getElementById('email');
  ui.passwordInput = document.getElementById('password');
  ui.authSubmitBtn = document.getElementById('authSubmitBtn');
  ui.passwordHelper = document.getElementById('passwordHelper');
  ui.passwordChecklist = document.getElementById('passwordChecklist');
  ui.forgotPasswordBtn = document.getElementById('forgotPasswordBtn');
  ui.resendConfirmBtn = document.getElementById('resendConfirmBtn');
  ui.authAlert = document.getElementById('authAlert');
  ui.userActions = document.getElementById('userActions');
  ui.signOutBtn = document.getElementById('signOutBtn');
  ui.activeUserEmail = document.getElementById('activeUserEmail');
  ui.searchInput = document.getElementById('searchInput');
  ui.sessionsList = document.getElementById('sessionsList');
  ui.resetModalLayer = document.getElementById('resetModalLayer');
  ui.resetAlert = document.getElementById('resetAlert');
  ui.cancelResetBtn = document.getElementById('cancelResetBtn');
  ui.submitResetBtn = document.getElementById('submitResetBtn');
  ui.newPasswordInput = document.getElementById('newPassword');
  ui.confirmPasswordInput = document.getElementById('confirmPassword');
  ui.resetChecklist = document.getElementById('resetChecklist');
  ui.sessionDetail = document.getElementById('sessionDetail');
  ui.forgotPasswordModal = document.getElementById('forgotPasswordModal');
  ui.resetEmailInput = document.getElementById('resetEmail');
  ui.forgotAlert = document.getElementById('forgotAlert');
  ui.cancelForgotBtn = document.getElementById('cancelForgotBtn');
  ui.submitForgotBtn = document.getElementById('submitForgotBtn');
}

function bindUI() {
  ui.authTabs.forEach(tab => {
    tab.addEventListener('click', () => setAuthMode(tab.dataset.mode));
  });

  ui.authForm.addEventListener('submit', handleAuthSubmit);
  ui.passwordInput.addEventListener('input', () => {
    renderChecklist(ui.passwordChecklist, ui.passwordInput.value);
  });

  ui.forgotPasswordBtn.addEventListener('click', showForgotPasswordModal);
  ui.resendConfirmBtn.addEventListener('click', handleResendConfirmation);
  ui.signOutBtn.addEventListener('click', handleSignOut);
  ui.searchInput.addEventListener('input', filterSessions);
  ui.cancelResetBtn.addEventListener('click', hideResetModal);
  ui.submitResetBtn.addEventListener('click', handleResetPasswordSubmit);
  ui.newPasswordInput.addEventListener('input', () => renderChecklist(ui.resetChecklist, ui.newPasswordInput.value));
  ui.cancelForgotBtn.addEventListener('click', hideForgotPasswordModal);
  ui.submitForgotBtn.addEventListener('click', handleForgotPasswordSubmit);
  ui.resetModalLayer.addEventListener('click', event => {
    if (event.target === ui.resetModalLayer) {
      hideResetModal();
    }
  });
  ui.forgotPasswordModal.addEventListener('click', event => {
    if (event.target === ui.forgotPasswordModal) {
      hideForgotPasswordModal();
    }
  });
}

function showStatus(message, type = 'info') {
  if (!ui.statusBanner) return;
  hideStatusPanel();
  ui.statusBanner.textContent = message;
  ui.statusBanner.classList.remove('hidden', 'success', 'error', 'info');
  ui.statusBanner.classList.add(type);
}

function hideStatus() {
  if (!ui.statusBanner) return;
  ui.statusBanner.classList.add('hidden');
  ui.statusBanner.classList.remove('success', 'error', 'info');
}

function showStatusPanel({ title, message, actions = [], hideAuth = false }) {
  if (!ui.statusPanel) return;
  ui.statusPanel.classList.remove('recovery');
  ui.statusPanel.innerHTML = `
    <div class="panel-content">
      <h2>${title}</h2>
      <p>${message}</p>
      <div class="actions">
        ${actions.map(action => `
          <button class="btn ${action.variant || 'primary'}" data-action="${action.id}">
            ${action.label}
          </button>
        `).join('')}
      </div>
    </div>
  `;

  ui.statusPanel.classList.add('active');
  hideStatus();

  if (hideAuth) {
    hideAuthPanels();
    document.body.classList.add('status-only');
  } else {
    restoreAuthPanels();
    document.body.classList.remove('status-only');
  }

  const buttons = ui.statusPanel.querySelectorAll('button[data-action]');
  buttons.forEach(button => {
    const id = button.getAttribute('data-action');
    const action = actions.find(item => item.id === id);
    if (action && typeof action.onClick === 'function') {
      button.addEventListener('click', action.onClick, { once: true });
    }
  });
}

function hideStatusPanel() {
  if (!ui.statusPanel) return;
  ui.statusPanel.classList.remove('active');
  ui.statusPanel.classList.remove('recovery');
  ui.statusPanel.innerHTML = '';
  document.body.classList.remove('status-only');
  restoreAuthPanels();
  state.passwordRecovery = false;
}

function hideAuthPanels() {
  if (authTemporarilyHidden) return;
  authTemporarilyHidden = true;
  ui.authPanel?.classList.add('hidden-panel');
  ui.appPanel?.classList.add('hidden-panel');
  ui.userActions?.classList.add('hidden-panel');
}

function restoreAuthPanels() {
  if (!authTemporarilyHidden) return;
  ui.authPanel?.classList.remove('hidden-panel');
  ui.appPanel?.classList.remove('hidden-panel');
  ui.userActions?.classList.remove('hidden-panel');
  authTemporarilyHidden = false;
}

async function handleResendConfirmation() {
  if (!state.pendingResendEmail) return;

  const email = state.pendingResendEmail;
  ui.resendConfirmBtn.disabled = true;
  ui.resendConfirmBtn.textContent = 'Sending…';

  try {
    const { error } = await state.supabase.auth.resend({
      type: 'signup',
      email,
    });
    if (error) throw error;

    displayAlert(ui.authAlert, `Confirmation email sent to ${email}.`, 'success');
    ui.resendConfirmBtn.classList.add('hidden');
    state.pendingResendEmail = null;
  } catch (error) {
    displayAlert(ui.authAlert, error.message || 'Unable to resend confirmation email.', 'error');
  } finally {
    ui.resendConfirmBtn.disabled = false;
    ui.resendConfirmBtn.textContent = 'Resend confirmation email';
  }
}

function showRecoveryPanel() {
  if (!ui.statusPanel) return;
  state.passwordRecovery = true;
  hideStatus();
  hideAuthPanels();
  document.body.classList.add('status-only');

  ui.statusPanel.classList.add('active', 'recovery');
  ui.statusPanel.innerHTML = `
    <div class="panel-content recovery">
      <h2>Reset Your Password</h2>
      <p>Set a new password to regain access to Out Loud.</p>
      <form id="recoveryForm" class="recovery-form">
        <div id="recoveryAlert" class="panel-alert hidden"></div>
        <div class="input-group">
          <label for="newPasswordInline">New password</label>
          <input id="newPasswordInline" type="password" autocomplete="new-password" placeholder="Enter new password" />
        </div>
        <div class="input-group">
          <label for="confirmPasswordInline">Confirm password</label>
          <input id="confirmPasswordInline" type="password" autocomplete="new-password" placeholder="Confirm new password" />
        </div>
        <div class="actions">
          <button type="submit" class="btn primary">Update Password</button>
          <button type="button" class="btn secondary" id="recoveryCancel">Cancel</button>
        </div>
      </form>
    </div>
  `;

  const form = document.getElementById('recoveryForm');
  const alertBox = document.getElementById('recoveryAlert');
  const newPasswordInput = document.getElementById('newPasswordInline');
  const confirmInput = document.getElementById('confirmPasswordInline');
  const cancelButton = document.getElementById('recoveryCancel');
  const submitButton = form.querySelector('button[type="submit"]');

  const showPanelAlert = (message, type = 'error') => {
    alertBox.textContent = message;
    alertBox.className = `panel-alert ${type}`;
    alertBox.classList.remove('hidden');
  };

  const hidePanelAlert = () => {
    alertBox.classList.add('hidden');
    alertBox.textContent = '';
  };

  cancelButton.addEventListener('click', () => {
    hideStatusPanel();
    setAuthMode('sign-in');
  });

  form.addEventListener('submit', async event => {
    event.preventDefault();
    hidePanelAlert();

    const newPassword = newPasswordInput.value;
    const confirmPassword = confirmInput.value;

    if (!validatePassword(newPassword)) {
      showPanelAlert('Password must meet all requirements.');
      return;
    }

    if (newPassword !== confirmPassword) {
      showPanelAlert('Passwords do not match.');
      return;
    }

    submitButton.disabled = true;
    submitButton.textContent = 'Updating…';

    try {
      const { error } = await state.supabase.auth.updateUser({ password: newPassword });
      if (error) throw error;

      showStatusPanel({
        title: 'Password Updated',
        message: 'Your password has been updated. You can now sign in with your new credentials.',
        actions: [
          {
            id: 'signin',
            label: 'Sign In on Web',
            onClick: () => {
              hideStatusPanel();
              restoreAuthPanels();
              setAuthMode('sign-in');
            }
          }
        ]
      });
      await checkAuth();
    } catch (error) {
      showPanelAlert(error.message || 'Unable to update password.');
    } finally {
      submitButton.disabled = false;
      submitButton.textContent = 'Update Password';
    }
  });

  newPasswordInput.focus();
}

function clearAuthParams() {
  const url = new URL(window.location.href);
  const keys = ['access_token', 'refresh_token', 'expires_in', 'token_type', 'type', 'code', 'error', 'error_code', 'error_description', 'reset'];
  keys.forEach(key => url.searchParams.delete(key));
  url.hash = '';
  window.history.replaceState({}, document.title, url.toString());
}

async function handleAuthRedirect() {
  const searchParams = new URLSearchParams(window.location.search);
  const hashParams = new URLSearchParams(window.location.hash.replace(/^#/, ''));
  const params = hashParams.get('type') ? hashParams : searchParams.get('type') ? searchParams : null;
  const code = searchParams.get('code');

  if (!params && !code) {
    const resetFlag = searchParams.get('reset');
    if (resetFlag === '1') {
      showStatusPanel({
        title: 'Password Reset Email Sent',
        message: 'Check your inbox for the password reset link. Once you update your password you can sign in again.',
        actions: [
          {
            id: 'signin',
            label: 'Sign In on Web',
            onClick: () => {
              hideStatusPanel();
              restoreAuthPanels();
              setAuthMode('sign-in');
            }
          },
          {
            id: 'close',
            label: 'Close Window',
            variant: 'secondary',
            onClick: () => {
              hideResetModal();
              hideStatusPanel();
            }
          }
        ]
      });
      clearAuthParams();
    }
    return;
  }

  if (window.location.pathname !== '/status.html') {
    const query = window.location.search;
    const hash = window.location.hash;
    window.location.replace(`/status.html${query}${hash}`);
    return;
  }

  if (code) {
    showStatusPanel({
      title: 'Confirming Your Email…',
      message: 'Hang tight while we verify your link.',
      actions: [],
      hideAuth: true
    });

    try {
      const { data, error } = await state.supabase.auth.exchangeCodeForSession(code);
      if (error) throw error;
      if (data?.session) {
        showStatusPanel({
          title: 'Email Confirmed ✉️',
          message: 'Your account is ready. You can safely close this tab and continue in the Out Loud app, or sign in here to review your sessions.',
          actions: [
            {
              id: 'signin',
              label: 'Sign In on Web',
              onClick: () => {
                hideStatusPanel();
                restoreAuthPanels();
                setAuthMode('sign-in');
              }
            },
            {
              id: 'close',
              label: 'Close Window',
              variant: 'secondary',
              onClick: () => {
                hideStatusPanel();
                window.close();
              }
            }
          ],
          hideAuth: true
        });
      }
    } catch (error) {
      showStatusPanel({
        title: 'Confirmation Failed',
        message: error.message || 'We could not verify the email link. Try requesting a new confirmation email or contact support.',
        actions: [
          {
            id: 'retry',
            label: 'Back to Sign In',
            onClick: () => {
              hideStatusPanel();
              restoreAuthPanels();
              setAuthMode('sign-in');
            }
          }
        ],
        hideAuth: true
      });
    }

    clearAuthParams();
    return;
  }

  const type = params.get('type');
  const errorDescription = params.get('error_description');

  if (errorDescription) {
    const errorCode = params.get('error_code');
    const message = errorCode === 'otp_expired'
      ? 'This link has expired. Request a new confirmation email or reset your password.'
      : errorDescription;

    showStatusPanel({
      title: errorCode === 'otp_expired' ? 'Link Expired' : 'Link Error',
      message,
      actions: [
        {
          id: 'signin',
          label: 'Back to Sign In',
          onClick: () => {
            hideStatusPanel();
            setAuthMode('sign-in');
          }
        },
        {
          id: 'reset',
          label: 'Reset Password',
          onClick: () => {
            showRecoveryPanel();
          }
        }
      ],
      hideAuth: true
    });
    clearAuthParams();
    return;
  }

  const accessToken = params.get('access_token');
  const refreshToken = params.get('refresh_token');

  if (accessToken && refreshToken) {
    try {
      const { error } = await state.supabase.auth.setSession({
        access_token: accessToken,
        refresh_token: refreshToken,
      });
      if (error) throw error;
    } catch (error) {
      showStatus(error.message || 'Unable to verify the authentication link. Please try again.', 'error');
      clearAuthParams();
      return;
    }
  }

  if (type === 'signup') {
    showStatusPanel({
      title: 'Email Confirmed ✉️',
      message: 'Your account is ready. You can safely close this tab and continue in the Out Loud app, or sign in here to review your sessions.',
      actions: [
        {
          id: 'signin',
          label: 'Sign In on Web',
          onClick: () => {
            hideStatusPanel();
            restoreAuthPanels();
            setAuthMode('sign-in');
          }
        },
        {
          id: 'close',
          label: 'Close Window',
          variant: 'secondary',
          onClick: () => {
            hideStatusPanel();
            window.close();
          }
        }
      ],
      hideAuth: true
    });
    setAuthMode('sign-in');
  } else if (type === 'recovery') {
    showRecoveryPanel();
  }

  clearAuthParams();
}

async function bootstrapSupabase() {
  try {
    const response = await fetch('config.json');
    const config = await response.json();
    const { createClient } = window.supabase;
    state.supabase = createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY);
    setupAuthListener();
    await handleAuthRedirect();
    await checkAuth();
  } catch (error) {
    displayAlert(ui.authAlert, 'Missing config.json - copy config.example.json and add Supabase keys.', 'error');
  }
}

function setupAuthListener() {
  state.supabase.auth.onAuthStateChange((event, session) => {
    if (event === 'PASSWORD_RECOVERY') {
      state.passwordRecovery = true;
      showRecoveryPanel();
      return;
    }

    if (session) {
      applyAuthenticatedState(session);
    } else if (!state.passwordRecovery) {
      applyLoggedOutState();
          }
        });
        setAuthMode('sign-in');
      }

async function checkAuth() {
  if (!state.supabase) return;
  const { data } = await state.supabase.auth.getSession();
  if (data.session) {
    applyAuthenticatedState(data.session);
  } else {
    applyLoggedOutState();
  }
}

function setAuthMode(mode) {
  state.authMode = mode;
  ui.authTabs.forEach(tab => tab.classList.toggle('active', tab.dataset.mode === mode));
  ui.authSubmitBtn.textContent = mode === 'sign-in' ? 'Sign In' : 'Create Account';
  ui.passwordHelper.classList.toggle('active', mode === 'sign-up');
  ui.forgotPasswordBtn.classList.toggle('hidden', mode === 'sign-up');
  renderChecklist(ui.passwordChecklist, ui.passwordInput.value);
  hideAlert(ui.authAlert);
  state.pendingResendEmail = null;
  ui.resendConfirmBtn.classList.add('hidden');
}

function renderChecklist(container, value = '') {
  container.innerHTML = '';
  passwordRules.forEach(rule => {
    const valid = rule.test(value || '');
    const li = document.createElement('li');
    li.className = valid ? 'valid' : '';
    li.innerHTML = `<span class="check-symbol">${valid ? '✓' : ''}</span>${rule.label}`;
    container.appendChild(li);
  });
}

function validatePassword(password) {
  return passwordRules.every(rule => rule.test(password));
}

async function handleAuthSubmit(event) {
  event.preventDefault();
  hideAlert(ui.authAlert);

  const email = ui.emailInput.value.trim().toLowerCase();
  const password = ui.passwordInput.value;

  if (!email || !password) {
    displayAlert(ui.authAlert, 'Email and password are required.', 'error');
    return;
  }

  if (state.authMode === 'sign-up' && !validatePassword(password)) {
    displayAlert(ui.authAlert, 'Please choose a stronger password that meets all requirements.', 'error');
    return;
  }

  ui.authSubmitBtn.disabled = true;
  ui.authSubmitBtn.textContent = state.authMode === 'sign-in' ? 'Signing in…' : 'Creating account…';

  try {
    if (state.authMode === 'sign-in') {
      const { error } = await state.supabase.auth.signInWithPassword({ email, password });
      if (error) throw error;
      displayAlert(ui.authAlert, 'Signed in successfully.', 'success');
      state.pendingResendEmail = null;
      ui.resendConfirmBtn.classList.add('hidden');
    } else {
      const { error } = await state.supabase.auth.signUp({
        email,
        password,
        options: {
          emailRedirectTo: window.location.origin,
        },
      });
      if (error) throw error;
      displayAlert(ui.authAlert, 'Check your inbox to confirm your account before signing in.', 'success');
      setAuthMode('sign-in');
      state.pendingResendEmail = email;
      ui.resendConfirmBtn.classList.remove('hidden');
    }
  } catch (error) {
    const message = error?.message || error?.error_description || 'Authentication failed.';
    const lower = message.toLowerCase();

    if (state.authMode === 'sign-in' && (lower.includes('confirm') || lower.includes('verification'))) {
      displayAlert(ui.authAlert, 'Please confirm your email before signing in.', 'info');
      state.pendingResendEmail = email;
      ui.resendConfirmBtn.classList.remove('hidden');
    } else if (state.authMode === 'sign-up' && lower.includes('already') && lower.includes('registered')) {
      displayAlert(ui.authAlert, 'Account already exists. If you still need to verify it, use the button below to resend the confirmation email.', 'info');
      state.pendingResendEmail = email;
      ui.resendConfirmBtn.classList.remove('hidden');
      setAuthMode('sign-in');
    } else {
      displayAlert(ui.authAlert, message, 'error');
      state.pendingResendEmail = null;
      ui.resendConfirmBtn.classList.add('hidden');
    }
  } finally {
    ui.authSubmitBtn.disabled = false;
    ui.authSubmitBtn.textContent = state.authMode === 'sign-in' ? 'Sign In' : 'Create Account';
  }
}

function showForgotPasswordModal() {
  ui.resetEmailInput.value = ui.emailInput.value;
  ui.forgotPasswordModal.classList.remove('hidden');
  hideAlert(ui.forgotAlert);
  ui.resetEmailInput.focus();
}

function hideForgotPasswordModal() {
  ui.forgotPasswordModal.classList.add('hidden');
}

async function handleForgotPasswordSubmit() {
  hideAlert(ui.forgotAlert);
  const email = ui.resetEmailInput.value.trim().toLowerCase();
  if (!email) {
    displayAlert(ui.forgotAlert, 'Please enter your email address.', 'error');
    return;
  }

  ui.submitForgotBtn.disabled = true;
  ui.submitForgotBtn.textContent = 'Sending...';

  try {
    const { error } = await state.supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}?reset=1`,
    });
    if (error) throw error;
    displayAlert(ui.forgotAlert, 'Reset link sent! Check your email.', 'success');
    setTimeout(() => hideForgotPasswordModal(), 2000);
  } catch (error) {
    displayAlert(ui.forgotAlert, error.message || 'Unable to send reset email.', 'error');
  } finally {
    ui.submitForgotBtn.disabled = false;
    ui.submitForgotBtn.textContent = 'Send reset link';
  }
}

async function handleSignOut() {
  await state.supabase.auth.signOut();
  applyLoggedOutState();
  setAuthMode('sign-in');
  state.passwordRecovery = false;
}

function applyAuthenticatedState(session) {
  hideStatus();
  hideStatusPanel();
  ui.authPanel.classList.add('hidden');
  ui.appPanel.classList.remove('hidden');
  ui.userActions.classList.remove('hidden');
  ui.activeUserEmail.textContent = session.user.email;
  loadSessions();
}

function applyLoggedOutState() {
  hideStatusPanel();
  ui.authPanel.classList.remove('hidden');
  ui.appPanel.classList.add('hidden');
  ui.detailPanel.classList.add('hidden');
  ui.userActions.classList.add('hidden');
  ui.activeUserEmail.textContent = '';
  ui.sessionsList.innerHTML = '';
  state.sessions = [];
  state.activeSession = null;
}

async function loadSessions() {
  try {
    const { data, error } = await state.supabase
      .from('sessions')
      .select('*')
      .order('start_time', { ascending: false });
    if (error) throw error;
    state.sessions = data || [];
    renderSessions(state.sessions);
  } catch (error) {
    displayAlert(ui.authAlert, error.message || 'Failed to load sessions.', 'error');
  }
}

function renderSessions(sessions) {
  if (!sessions.length) {
    ui.sessionsList.innerHTML = `
      <div class="empty-state">
        <h3>No sessions yet</h3>
        <p class="muted">Record in the Out Loud app to populate your dashboard.</p>
      </div>`;
    return;
  }

  ui.sessionsList.innerHTML = sessions
    .map(session => {
      const date = new Date(session.start_time).toLocaleString();
      const duration = formatDuration(session.duration);
      const summary = session.analysis?.summary || session.transcript || '';
      return `
        <article class="session-card" data-session-id="${session.id}">
          <div class="session-title">${escapeHtml(session.title || 'Untitled Session')}</div>
          <div class="session-meta">${date} • ${duration}</div>
          <div class="session-snippet">${escapeHtml(summary).slice(0, 240)}${summary.length > 240 ? '…' : ''}</div>
        </article>`;
    })
    .join('');

  Array.from(document.querySelectorAll('.session-card')).forEach(card => {
    card.addEventListener('click', () => openSessionDetail(card.dataset.sessionId));
  });
}

function filterSessions() {
  const query = ui.searchInput.value.trim().toLowerCase();
  if (!query) {
    renderSessions(state.sessions);
    return;
  }

  const filtered = state.sessions.filter(session => {
    const fields = [session.title, session.transcript, session.analysis?.summary]
      .filter(Boolean)
      .map(value => value.toLowerCase());
    return fields.some(field => field.includes(query));
  });

  renderSessions(filtered);
}

async function openSessionDetail(sessionId) {
  const session = state.sessions.find(item => String(item.id) === String(sessionId));
  if (!session) return;
  state.activeSession = session;

  document.querySelectorAll('.session-card').forEach(card => card.classList.remove('active'));
  document.querySelector(`[data-session-id="${sessionId}"]`)?.classList.add('active');

  let audioPlayer = '';
  if (session.audio_path) {
    try {
      const { data } = await state.supabase.storage.from('audio-recordings').createSignedUrl(session.audio_path, 3600);
      if (data?.signedUrl) {
        audioPlayer = `
          <div class="detail-section">
            <h4>Recording</h4>
            <audio controls style="width: 100%;">
              <source src="${data.signedUrl}" type="audio/mp4">
              Your browser does not support audio playback.
            </audio>
          </div>`;
      }
    } catch (error) {
      console.error('Audio load error', error);
    }
  }

  const keywords = session.analysis?.keywords?.length
    ? `<div class="detail-section"><h4>Keywords</h4><p>${session.analysis.keywords.join(', ')}</p></div>`
    : '';

  const analysis = session.analysis
    ? `<div class="detail-section"><h4>AI Analysis</h4><p>${escapeHtml(session.analysis.summary)}</p></div>`
    : '';

  ui.sessionDetail.innerHTML = `
    <div>
      <div style="display: flex; align-items: center; gap: 12px; margin-bottom: 8px;">
        <h2 id="sessionTitle" style="margin: 0; flex: 1;">${escapeHtml(session.title || 'Untitled Session')}</h2>
        <button class="btn link" onclick="editTitle('${sessionId}')" style="margin: 0; font-size: 14px;">Edit</button>
      </div>
      <p class="muted" style="margin-top: 4px;">${new Date(session.start_time).toLocaleString()} • ${formatDuration(session.duration)}</p>
    </div>
    ${audioPlayer}
    <div class="detail-section">
      <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px;">
        <h4 style="margin: 0;">Transcript</h4>
        <button class="btn link" onclick="editTranscript('${sessionId}')" style="margin: 0; font-size: 14px;">Edit</button>
      </div>
      <p id="sessionTranscript">${escapeHtml(session.transcript)}</p>
    </div>
    ${analysis}
    ${keywords}
    <button class="btn danger" type="button" onclick="confirmDeleteSession('${sessionId}')">Delete session</button>
  `;

  ui.detailPanel.classList.remove('hidden');
}

async function editTitle(sessionId) {
  const session = state.sessions.find(s => String(s.id) === String(sessionId));
  if (!session) return;

  const newTitle = prompt('Edit title:', session.title || '');
  if (newTitle === null || newTitle === session.title) return;

  try {
    const { error } = await state.supabase
      .from('sessions')
      .update({ title: newTitle })
      .eq('id', sessionId);
    if (error) throw error;

    session.title = newTitle;
    document.getElementById('sessionTitle').textContent = newTitle || 'Untitled Session';
    renderSessions(state.sessions);
  } catch (error) {
    alert('Failed to update title: ' + error.message);
  }
}

async function editTranscript(sessionId) {
  const session = state.sessions.find(s => String(s.id) === String(sessionId));
  if (!session) return;

  const newTranscript = prompt('Edit transcript:', session.transcript || '');
  if (newTranscript === null || newTranscript === session.transcript) return;

  try {
    const { error } = await state.supabase
      .from('sessions')
      .update({ transcript: newTranscript })
      .eq('id', sessionId);
    if (error) throw error;

    session.transcript = newTranscript;
    document.getElementById('sessionTranscript').textContent = newTranscript;
    renderSessions(state.sessions);
  } catch (error) {
    alert('Failed to update transcript: ' + error.message);
  }
}

async function confirmDeleteSession(sessionId) {
  if (!confirm('Delete this session permanently?')) return;
  try {
    const { error } = await state.supabase
      .from('sessions')
      .delete()
      .eq('id', sessionId);
    if (error) throw error;
    ui.detailPanel.classList.add('hidden');
    loadSessions();
  } catch (error) {
    alert(error.message || 'Failed to delete session.');
  }
}

function showResetModal() {
  ui.resetModalLayer.classList.remove('hidden');
  ui.newPasswordInput.value = '';
  ui.confirmPasswordInput.value = '';
  renderChecklist(ui.resetChecklist, '');
  hideAlert(ui.resetAlert);
  ui.newPasswordInput.focus();
}

function hideResetModal() {
  ui.resetModalLayer.classList.add('hidden');
  state.passwordRecovery = false;
  restoreAuthPanels();
}

async function handleResetPasswordSubmit() {
  hideAlert(ui.resetAlert);
  const newPassword = ui.newPasswordInput.value;
  const confirmPassword = ui.confirmPasswordInput.value;

  if (!validatePassword(newPassword)) {
    displayAlert(ui.resetAlert, 'Password must meet all requirements.', 'error');
    return;
  }

  if (newPassword !== confirmPassword) {
    displayAlert(ui.resetAlert, 'Passwords do not match.', 'error');
    return;
  }

  ui.submitResetBtn.disabled = true;
  ui.submitResetBtn.textContent = 'Updating…';

  try {
    const { error } = await state.supabase.auth.updateUser({ password: newPassword });
    if (error) throw error;
    displayAlert(ui.resetAlert, 'Password updated. You are now signed in.', 'success');
    hideResetModal();
    await checkAuth();
  } catch (error) {
    displayAlert(ui.resetAlert, error.message || 'Unable to update password.', 'error');
  } finally {
    ui.submitResetBtn.disabled = false;
    ui.submitResetBtn.textContent = 'Update password';
  }
}

function displayAlert(container, message, type = 'success') {
  container.textContent = message;
  container.className = `alert ${type}`;
  container.classList.remove('hidden');
}

function hideAlert(container) {
  container.classList.add('hidden');
  container.textContent = '';
}

function formatDuration(seconds = 0) {
  const mins = Math.floor(seconds / 60);
  const secs = Math.round(seconds % 60);
  if (mins >= 1) {
    return `${mins}m ${String(secs).padStart(2, '0')}s`;
  }
  return `${secs}s`;
}

function escapeHtml(value = '') {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}
