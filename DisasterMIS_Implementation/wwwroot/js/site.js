// DisasterMIS – site.js
// Lightweight helpers for the dark-theme UI


// ── Active nav link highlight (fallback for edge cases) ──────────────────────
(function () {
    const path = window.location.pathname.split('/')[1].toLowerCase();
    document.querySelectorAll('.nav-item').forEach(function (el) {
        const href = (el.getAttribute('href') || '').toLowerCase();
        if (path && href.includes(path)) {
            el.classList.add('active');
        }
    });
})();

// ── Auto-close modals on Escape key ──────────────────────────────────────────
document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') {
        document.querySelectorAll('[id^="completeModal_"], [id^="approveModal_"]').forEach(function (m) {
            m.style.display = 'none';
        });
    }
});

// ── Close modal when clicking the overlay ────────────────────────────────────
document.addEventListener('click', function (e) {
    if (e.target.matches('[id^="completeModal_"], [id^="approveModal_"]')) {
        e.target.style.display = 'none';
    }
});

// ── Progress bars: animate on load ───────────────────────────────────────────
window.addEventListener('load', function () {
    document.querySelectorAll('.progress-bar-fill').forEach(function (bar) {
        const w = bar.style.width;
        bar.style.width = '0';
        setTimeout(function () { bar.style.width = w; }, 100);
    });
});

// ── Confirm-delete shortcut: add class "confirm-delete" to any form ───────────
document.querySelectorAll('form.confirm-delete').forEach(function (form) {
    form.addEventListener('submit', function (e) {
        if (!confirm('Are you sure? This action cannot be undone.')) {
            e.preventDefault();
        }
    });
});
