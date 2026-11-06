const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
let now = 0;
const listeners = {};
let watchdog;
const instances = [];
const reports = [];
class Audio {
    constructor(src) { this.src = src; this.paused = true; this.plays = 0; this.events = {}; instances.push(this); }
    play() {
        this.plays++;
        if (Audio.blockNext) {
            Audio.blockNext = false;
            return { catch: fn => fn({ name: 'NotAllowedError' }) };
        }
        this.paused = false;
        if (this.events.playing) this.events.playing();
        return Promise.resolve();
    }
    addEventListener(name, fn) { this.events[name] = fn; }
    pause() { this.paused = true; }
    removeAttribute(name) { if (name === 'src') this.src = ''; }
    load() {}
}
const context = vm.createContext({
    Audio, Date: { now: () => now },
    window: { addEventListener: (name, fn) => { listeners[name] = fn; } },
    setInterval: fn => { watchdog = fn; },
    document: { getElementById: () => null },
    fetch: (url, request) => { assert.equal(url, 'https://renamed-mechanic/washAudioStatus'); reports.push(JSON.parse(request.body)); return Promise.resolve({ ok: true }); },
});
vm.runInContext('Object.hasOwn = undefined;', context);
const audioSource = fs.readFileSync('crimson-mechanic/web/wash-audio.js', 'utf8');
const bundle = fs.readFileSync('crimson-mechanic/web/wash.js', 'utf8');
assert.ok(bundle.includes(audioSource.trim()));
vm.runInContext(bundle, context);
const messageHandler = listeners.message;
vm.runInContext(audioSource, context);
assert.equal(listeners.message, messageHandler, 'legacy HTML loading both files must not create duplicate audio handlers');
const send = streams => listeners.message({ data: { action: 'washAudio', resource: 'renamed-mechanic', streams } });
send([{ id: '11', kind: 'water', volume: .65 }, { id: '22', kind: 'foam', volume: .2 }]);
assert.equal(instances.length, 2);
assert.ok(instances.every(a => a.loop && !a.paused && a.plays === 1));
assert.equal(instances[0].src, 'audio/wash_water.ogg');
assert.equal(instances[1].src, 'audio/wash_foam.ogg');
now = 100;
send([{ id: '11', kind: 'water', volume: .4 }, { id: '22', kind: 'foam', volume: .1 }]);
assert.equal(instances.length, 2, 'heartbeats must not restart playback');
assert.equal(instances[0].plays, 1);
assert.equal(instances[0].volume, .4);
send([{ id: '11', kind: 'foam', volume: .5 }]);
assert.ok(instances[0].paused && instances[1].paused);
assert.equal(instances.length, 3);
assert.equal(instances[2].src, 'audio/wash_foam.ogg');
send([]);
assert.ok(instances.every(a => a.paused), 'release/cleanup must stop all missing streams');
send([{ id: '33', kind: 'http://untrusted', volume: 1 }]);
assert.equal(instances.length, 3, 'only packaged water/foam files may be played');
send([{ id: '11', kind: 'water', volume: 1 }]);
now += 751; watchdog();
assert.ok(instances.at(-1).paused, 'lost heartbeat must not leave a stuck sound loop');
send([{ id: '11', kind: 'water', volume: .5 }]);
listeners.pagehide();
assert.ok(instances.at(-1).paused);
assert.ok(reports.some(r => r.status === 'ready') && reports.some(r => r.status === 'playing'));
Audio.blockNext = true;
send([{ id: '11', kind: 'water', volume: .5 }]);
assert.ok(reports.some(r => r.status === 'error' && r.code === 'blocked'), 'autoplay rejection must be reported to Lua');
const failed = instances.at(-1); failed.error = { code: 4 }; failed.events.error(); failed.events.error();
assert.equal(reports.filter(r => r.code === 'file').length, 1, 'file errors must report once instead of failing silently');
send([]);
console.log('PASS: bundled HUD audio without GetParentResourceName/Object.hasOwn, renamed-resource handshake, no duplicate players and cleanup');
