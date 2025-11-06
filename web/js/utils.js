export const passwordRules = [
  { id: 'length', label: 'At least 8 characters', test: value => value.length >= 8 },
  { id: 'lower', label: 'Lowercase letter', test: value => /[a-z]/.test(value) },
  { id: 'upper', label: 'Uppercase letter', test: value => /[A-Z]/.test(value) },
  { id: 'digit', label: 'Number', test: value => /\d/.test(value) },
  { id: 'symbol', label: 'Symbol (e.g. !@#$)', test: value => /[^A-Za-z0-9]/.test(value) },
];

export function validatePassword(password) {
  return passwordRules.every(rule => rule.test(password));
}

export function renderChecklist(container, value = '') {
  container.innerHTML = '';
  passwordRules.forEach(rule => {
    const valid = rule.test(value || '');
    const li = document.createElement('li');
    li.className = valid ? 'valid' : '';
    li.innerHTML = `<span class="check-symbol">${valid ? '✓' : ''}</span>${rule.label}`;
    container.appendChild(li);
  });
}

export function formatDuration(seconds = 0) {
  const mins = Math.floor(seconds / 60);
  const secs = Math.round(seconds % 60);
  if (mins >= 1) {
    return `${mins}m ${String(secs).padStart(2, '0')}s`;
  }
  return `${secs}s`;
}

export function escapeHtml(value = '') {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

export function clearAuthParams() {
  const url = new URL(window.location.href);
  const keys = ['access_token', 'refresh_token', 'expires_in', 'token_type', 'type', 'code', 'error', 'error_code', 'error_description', 'reset'];
  keys.forEach(key => url.searchParams.delete(key));
  url.hash = '';
  window.history.replaceState({}, document.title, url.toString());
}
