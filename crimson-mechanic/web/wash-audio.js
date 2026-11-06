// Dedicated wash loops: independent of particle rendering and HUD visibility.
(() => {
    const files = { water: 'audio/wash_water.ogg', foam: 'audio/wash_foam.ogg' };
    const playing = new Map();
    let lastMessage = 0;
    const reportedErrors = new Set();
    const report = (status, code) => {
        if (typeof GetParentResourceName !== 'function') return;
        fetch(`https://${GetParentResourceName()}/washAudioStatus`, {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ status, code: code || '' }),
        }).catch(() => {});
    };
    const reportError = code => {
        if (reportedErrors.has(code)) return;
        reportedErrors.add(code);
        report('error', code);
    };

    const stop = id => {
        const entry = playing.get(id);
        if (!entry) return;
        entry.audio.pause();
        entry.audio.removeAttribute('src');
        entry.audio.load();
        playing.delete(id);
    };
    const stopAll = () => [...playing.keys()].forEach(stop);

    window.addEventListener('message', ({ data }) => {
        if (!data || data.action !== 'washAudio') return;
        lastMessage = Date.now();
        const seen = new Set();
        for (const stream of (Array.isArray(data.streams) ? data.streams : []).slice(0, 4)) {
            // Object.hasOwn is unavailable in older FiveM CEF builds. A missing
            // method here aborts every message before any Audio can be created.
            if (!stream || !Object.prototype.hasOwnProperty.call(files, stream.kind)) continue;
            const id = String(stream.id);
            const volume = Math.max(0, Math.min(1, Number(stream.volume) || 0));
            if (!volume || id.length > 32 || seen.has(id)) continue;
            seen.add(id);
            let entry = playing.get(id);
            if (entry && entry.kind !== stream.kind) { stop(id); entry = null; }
            if (!entry) {
                const audio = new Audio(files[stream.kind]);
                audio.loop = true;
                audio.preload = 'auto';
                entry = { kind: stream.kind, audio, lastAttempt: -Infinity };
                playing.set(id, entry);
                audio.addEventListener('error', () => {
                    if (playing.get(id) !== entry) return;
                    reportError(audio.error && audio.error.code === 3 ? 'decode' : 'file');
                });
                audio.addEventListener('playing', () => {
                    if (playing.get(id) === entry && !entry.confirmed) {
                        entry.confirmed = true;
                        report('playing', stream.kind);
                    }
                });
            }
            entry.audio.volume = volume;
            if (entry.audio.paused && Date.now() - entry.lastAttempt >= 1000) {
                entry.lastAttempt = Date.now();
                try {
                    const result = entry.audio.play();
                    if (result && result.catch) result.catch(error => {
                        if (playing.get(id) !== entry || (error && error.name === 'AbortError')) return;
                        reportError(error && error.name === 'NotAllowedError' ? 'blocked' : 'play');
                    });
                } catch (error) {
                    reportError('play');
                }
            }
        }
        for (const id of playing.keys()) if (!seen.has(id)) stop(id);
    });
    // No heartbeat after a cancelled/failed client loop must leave an audio loop.
    setInterval(() => { if (Date.now() - lastMessage > 750) stopAll(); }, 250);
    window.addEventListener('pagehide', stopAll);
    report('ready');
})();
