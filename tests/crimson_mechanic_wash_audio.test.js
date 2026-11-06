const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
let now = 0;
const listeners = {};
let watchdog;
const instances = [];
class Audio {
    constructor(src) { this.src = src; this.paused = true; this.plays = 0; instances.push(this); }
    play() { this.paused = false; this.plays++; return Promise.resolve(); }
    pause() { this.paused = true; }
    removeAttribute(name) { if (name === 'src') this.src = ''; }
    load() {}
}
vm.runInNewContext(fs.readFileSync('crimson-mechanic/web/wash-audio.js', 'utf8'), {
    Audio, Date: { now: () => now },
    window: { addEventListener: (name, fn) => { listeners[name] = fn; } },
    setInterval: fn => { watchdog = fn; },
});
const send = streams => listeners.message({ data: { action: 'washAudio', streams } });
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
console.log('PASS: water/foam audio loops, owner/spectator mixing, stage changes, release and missing-heartbeat cleanup');
