import { state, ui } from './state.js';
import { formatDuration, escapeHtml } from './utils.js';
import { displayAlert } from './ui.js';

export async function loadSessions() {
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

export function renderSessions(sessions) {
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

export function filterSessions() {
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

export async function openSessionDetail(sessionId) {
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
        <button class="btn link" onclick="window.editTitle('${sessionId}')" style="margin: 0; font-size: 14px;">Edit</button>
      </div>
      <p class="muted" style="margin-top: 4px;">${new Date(session.start_time).toLocaleString()} • ${formatDuration(session.duration)}</p>
    </div>
    ${audioPlayer}
    <div class="detail-section">
      <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px;">
        <h4 style="margin: 0;">Transcript</h4>
        <button class="btn link" onclick="window.editTranscript('${sessionId}')" style="margin: 0; font-size: 14px;">Edit</button>
      </div>
      <p id="sessionTranscript">${escapeHtml(session.transcript)}</p>
    </div>
    ${analysis}
    ${keywords}
    <button class="btn danger" type="button" onclick="window.confirmDeleteSession('${sessionId}')">Delete session</button>
  `;

  ui.detailPanel.classList.remove('hidden');
}

export async function editTitle(sessionId) {
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

export async function editTranscript(sessionId) {
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

export async function confirmDeleteSession(sessionId) {
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
