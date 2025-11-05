function showTestFlightModal() {
    document.getElementById('testflightModal').style.display = 'flex';
}

function closeTestFlightModal() {
    document.getElementById('testflightModal').style.display = 'none';
}

window.onclick = function(event) {
    const modal = document.getElementById('testflightModal');
    if (event.target === modal) {
        closeTestFlightModal();
    }
}
