export function displayAlert(container, message, type = 'success') {
  container.textContent = message;
  container.className = `alert ${type}`;
  container.classList.remove('hidden');
}

export function hideAlert(container) {
  container.classList.add('hidden');
  container.textContent = '';
}

export function showStatus(statusBanner, message, type = 'info') {
  if (!statusBanner) return;
  statusBanner.textContent = message;
  statusBanner.classList.remove('hidden', 'success', 'error', 'info');
  statusBanner.classList.add(type);
}

export function hideStatus(statusBanner) {
  if (!statusBanner) return;
  statusBanner.classList.add('hidden');
  statusBanner.classList.remove('success', 'error', 'info');
}
