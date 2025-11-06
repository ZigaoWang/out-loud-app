import { state, ui } from './state.js';
import { validatePassword, renderChecklist, clearAuthParams } from './utils.js';
import { displayAlert, hideAlert } from './ui.js';
import { loadSessions } from './sessions.js';

export function setAuthMode(mode) {
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

export async function handleAuthSubmit(event) {
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

export async function handleResendConfirmation() {
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

export async function handleSignOut() {
  await state.supabase.auth.signOut();
  applyLoggedOutState();
  setAuthMode('sign-in');
  state.passwordRecovery = false;
}

export function applyAuthenticatedState(session) {
  ui.authPanel.classList.add('hidden');
  ui.appPanel.classList.remove('hidden');
  ui.userActions.classList.remove('hidden');
  ui.activeUserEmail.textContent = session.user.email;
  loadSessions();
}

export function applyLoggedOutState() {
  ui.authPanel.classList.remove('hidden');
  ui.appPanel.classList.add('hidden');
  ui.detailPanel.classList.add('hidden');
  ui.userActions.classList.add('hidden');
  ui.activeUserEmail.textContent = '';
  ui.sessionsList.innerHTML = '';
  state.sessions = [];
  state.activeSession = null;
}

export async function checkAuth() {
  if (!state.supabase) return;
  const { data } = await state.supabase.auth.getSession();
  if (data.session) {
    applyAuthenticatedState(data.session);
  } else {
    applyLoggedOutState();
  }
}

export function setupAuthListener() {
  state.supabase.auth.onAuthStateChange((event, session) => {
    if (event === 'PASSWORD_RECOVERY') {
      state.passwordRecovery = true;
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

export async function bootstrapSupabase() {
  try {
    const response = await fetch('config.json');
    const config = await response.json();
    const { createClient } = window.supabase;
    state.supabase = createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY);
    setupAuthListener();
    await checkAuth();
  } catch (error) {
    displayAlert(ui.authAlert, 'Missing config.json - copy config.example.json and add Supabase keys.', 'error');
  }
}
