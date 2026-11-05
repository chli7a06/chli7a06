// Wash HUD (client/wash.lua): 'wash' shows / updates it, 'washHide' hides it.
(() => {
    const hud = document.getElementById('washHud');
    const $ = id => document.getElementById(id);
    const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
    let lastRows = '';

    const row = r => {
        const cls = ['wash-row', r.done && 'is-done', r.active && 'is-active', r.warn && 'is-warn'].filter(Boolean).join(' ');
        const key = r.kbd ? `<kbd>${esc(r.kbd)}</kbd>` : '';
        const value = r.value != null ? `<span class="wash-row__value">${esc(r.value)}</span>` : '';
        return `<div class="${cls}">${key}<span class="wash-row__name">${esc(r.label)}</span>${value}</div>`;
    };

    window.addEventListener('message', ({ data: msg }) => {
        if (!msg) return;
        if (msg.action === 'washHide') {
            hud.hidden = true;
            lastRows = '';
            return;
        }
        if (msg.action !== 'wash') return;

        const d = msg.data || {};
        const pct = Math.max(0, Math.min(100, d.pct || 0));
        $('washTitle').textContent = d.title || '';
        $('washSub').textContent = d.sub || '';
        $('washPct').textContent = Math.floor(pct);
        $('washBar').style.width = pct + '%';
        $('washIconHose').hidden = !!d.auto;
        $('washIconAuto').hidden = !d.auto;
        hud.classList.toggle('is-flowing', !!d.flowing);

        const rows = (d.rows || []).map(row).join('');
        if (rows !== lastRows) {
            $('washList').innerHTML = rows;
            lastRows = rows;
        }
        hud.hidden = false;
    });
})();
