import { state, ui } from './state.js';
import { renderChecklist } from './utils.js';
import { bootstrapSupabase, setAuthMode, handleAuthSubmit, handleResendConfirmation, handleSignOut } from './auth.js';
import { loadSessions, filterSessions, editTitle, editTranscript, confirmDeleteSession } from './sessions.js';

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
  ui.sessionDetail = document.getElementById('sessionDetail');
}

function bindUI() {
  ui.authTabs.forEach(tab => {
    tab.addEventListener('click', () => setAuthMode(tab.dataset.mode));
  });

  ui.authForm.addEventListener('submit', handleAuthSubmit);
  ui.passwordInput.addEventListener('input', () => {
    renderChecklist(ui.passwordChecklist, ui.passwordInput.value);
  });

  ui.resendConfirmBtn.addEventListener('click', handleResendConfirmation);
  ui.signOutBtn.addEventListener('click', handleSignOut);
  ui.searchInput.addEventListener('input', filterSessions);
}

// Expose functions to window for inline onclick handlers
window.editTitle = editTitle;
window.editTranscript = editTranscript;
window.confirmDeleteSession = confirmDeleteSession;
window.loadSessions = loadSessions;

document.addEventListener('DOMContentLoaded', () => {
  cacheElements();
  bindUI();
  renderChecklist(ui.passwordChecklist);
  bootstrapSupabase();
});
