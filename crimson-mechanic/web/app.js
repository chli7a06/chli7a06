(() => {
    'use strict';

    const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'crimson-mechanic';
    const root = document.getElementById('tuner');
    const $ = id => document.getElementById('t-' + id);
    let st = null;
    let pending = false;

    // ------------------------------------------------------------
    // Transport
    // ------------------------------------------------------------

    async function post(name, data = {}) {
        if (!st) return null;
        const session = st.session;
        try {
            const res = await fetch(`https://${resource}/${name}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ session, ...data }),
            });
            const json = await res.json();
            if (!st || st.session !== session) return null;
            return json && json.ok ? json : null;
        } catch (_) {
            return null;
        }
    }

    const eq = (a, b) => JSON.stringify(a) === JSON.stringify(b);
    const money = n => '$' + Number(n || 0).toLocaleString('en-US');

    function el(tag, className, text) {
        const node = document.createElement(tag);
        if (className) node.className = className;
        if (text !== undefined) node.textContent = text;
        return node;
    }

    function status(text) {
        $('status').textContent = text || '';
        if (text) setTimeout(() => { if ($('status').textContent === text) $('status').textContent = ''; }, 2500);
    }

    // ------------------------------------------------------------
    // State helpers
    // ------------------------------------------------------------

    const currentItems = () => (st.categories.find(c => c.id === st.cat) || { items: [] }).items;

    function findItem(key) {
        for (const cat of st.categories) for (const item of cat.items) if (item.key === key) return item;
        return null;
    }

    const changed = key => st.cart.lines.some(l => l.key === key);

    function describe(item) {
        const v = item.value;
        if (item.type === 'paint') {
            const t = item.types.find(o => o.v === v.t);
            const c = v.rgb ? null : item.options.find(o => o.v === v.c);
            const name = v.rgb ? toHex(v.rgb).toUpperCase() : (c ? c.l : v.c);
            return `${t ? t.l : ''} ${name}`.trim();
        }
        if (item.type === 'multi') {
            const on = item.fields.filter((_, i) => v[i]);
            return on.length ? on.join(', ') : st.locale.off || 'Off';
        }
        if (item.type === 'sliders') return changed(item.key) ? 'Custom' : 'Stock';
        const opt = (item.options || []).find(o => eq(o.v, v));
        if (opt) return opt.l;
        return Array.isArray(v) && v.length === 3 ? toHex(v).toUpperCase() : 'Custom';
    }

    // ------------------------------------------------------------
    // Actions
    // ------------------------------------------------------------

    function applyReply(r) {
        if (r.categories) {
            st.categories = r.categories;
            if (!findItem(st.key)) st.key = (currentItems()[0] || {}).key;
        } else {
            const item = findItem(r.key);
            if (item) item.value = r.value;
        }
        st.cart = r.cart;
        render();
    }

    async function set(key, value) {
        if (pending) return;
        pending = true;
        const r = await post('tuner:set', { key, value });
        pending = false;
        if (!r) return status('Not available for this vehicle');
        applyReply(r);
    }

    // Sliders and the colour picker stream values: debounce, keep the local
    // value, only take the cart back (re-rendering would break the drag).
    let streamTimer = null;
    let streamSeq = 0;
    function stream(item) {
        clearTimeout(streamTimer);
        streamTimer = setTimeout(async () => {
            const seq = ++streamSeq;
            const r = await post('tuner:set', { key: item.key, value: item.value });
            if (r && seq === streamSeq) {
                st.cart = r.cart;
                renderList();
                renderCart();
            }
        }, 60);
    }

    // ------------------------------------------------------------
    // Colour picker (saturation/value square + hue bar + hex)
    // ------------------------------------------------------------

    const clamp = (n, a, b) => Math.min(b, Math.max(a, n));
    const toHex = rgb => '#' + rgb.map(n => clamp(Math.round(n), 0, 255).toString(16).padStart(2, '0')).join('');
    function fromHex(hex) {
        const m = /^#?([0-9a-f]{6})$/i.exec((hex || '').trim());
        if (!m) return null;
        const n = parseInt(m[1], 16);
        return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
    }
    function hsvToRgb(h, s, v) {
        const f = n => {
            const k = (n + h / 60) % 6;
            return v - v * s * Math.max(0, Math.min(k, 4 - k, 1));
        };
        return [f(5), f(3), f(1)].map(x => Math.round(x * 255));
    }
    function rgbToHsv([r, g, b]) {
        r /= 255; g /= 255; b /= 255;
        const max = Math.max(r, g, b), d = max - Math.min(r, g, b);
        let h = 0;
        if (d) {
            if (max === r) h = ((g - b) / d) % 6;
            else if (max === g) h = (b - r) / d + 2;
            else h = (r - g) / d + 4;
            h = (h * 60 + 360) % 360;
        }
        return [h, max ? d / max : 0, max];
    }

    function colorPicker(initial, onChange) {
        let [h, s, v] = rgbToHsv(initial || [255, 255, 255]);
        const wrap = el('div', 'picker');
        const sv = el('div', 'sv');
        const dot = el('span', 'sv-dot');
        sv.append(el('div', 'sv-white'), el('div', 'sv-black'), dot);
        const side = el('div', 'picker-side');
        const hue = el('input', 'hue');
        hue.type = 'range';
        hue.min = 0;
        hue.max = 359;
        const row = el('div', 'picker-row');
        const preview = el('span', 'preview');
        const hex = el('input', 'hex');
        hex.maxLength = 7;
        hex.spellcheck = false;
        const rgbText = el('span', 'rgb');
        row.append(preview, hex, rgbText);
        side.append(el('span', 'sub', st.locale.customColor || 'Custom colour'), hue, row);
        wrap.append(sv, side);

        function paint(emit) {
            const rgb = hsvToRgb(h, s, v);
            sv.style.background = `hsl(${h}, 100%, 50%)`;
            dot.style.left = `${s * 100}%`;
            dot.style.top = `${(1 - v) * 100}%`;
            hue.value = h;
            preview.style.background = toHex(rgb);
            if (document.activeElement !== hex) hex.value = toHex(rgb).toUpperCase();
            rgbText.textContent = rgb.join(', ');
            if (emit) onChange(rgb);
        }

        const pick = e => {
            const r = sv.getBoundingClientRect();
            s = clamp((e.clientX - r.left) / r.width, 0, 1);
            v = 1 - clamp((e.clientY - r.top) / r.height, 0, 1);
            paint(true);
        };
        sv.onpointerdown = e => { sv.setPointerCapture(e.pointerId); pick(e); };
        sv.onpointermove = e => { if (sv.hasPointerCapture(e.pointerId)) pick(e); };
        hue.oninput = () => { h = Number(hue.value); paint(true); };
        hex.oninput = () => {
            const rgb = fromHex(hex.value);
            if (!rgb) return;
            [h, s, v] = rgbToHsv(rgb);
            paint(true);
        };
        hex.onblur = () => paint(false);
        paint(false);
        return wrap;
    }

    async function remove(key) {
        const r = await post('tuner:remove', { key });
        if (r) applyReply(r);
    }

    function select(key) {
        st.key = key;
        post('tuner:focus', { key });
        renderList();
        renderEditor();
    }

    function selectCategory(id) {
        st.cat = id;
        const first = currentItems()[0];
        st.key = first && first.key;
        post('tuner:focus', first ? { key: first.key } : { category: id });
        render();
    }

    // ------------------------------------------------------------
    // Rendering
    // ------------------------------------------------------------

    function renderTabs() {
        const tabs = $('tabs');
        tabs.replaceChildren();
        for (const cat of st.categories) {
            const b = el('button', cat.id === st.cat ? 'active' : '', cat.label);
            b.prepend(MechanicIcons.create(cat.id));
            b.setAttribute('aria-pressed', String(cat.id === st.cat));
            b.onclick = () => selectCategory(cat.id);
            tabs.append(b);
        }
    }

    function renderList() {
        const list = $('list');
        list.replaceChildren();
        const items = currentItems();
        if (!items.length) return list.append(el('p', 'empty', st.locale.none));
        for (const item of items) {
            const row = el('button', 'row');
            if (item.key === st.key) row.classList.add('active');
            if (changed(item.key)) row.classList.add('changed');
            row.append(MechanicIcons.create(item.key, st.cat), el('span', 'name', item.label), el('span', 'value', describe(item)));
            row.title = `${item.label}: ${describe(item)}`;
            row.setAttribute('aria-pressed', String(item.key === st.key));
            row.onclick = () => select(item.key);
            list.append(row);
        }
    }

    function chip(label, selected, onClick, extra) {
        const b = el('button', selected ? 'selected' : '', label);
        b.setAttribute('aria-pressed', String(selected));
        if (extra) b.append(el('small', '', extra));
        b.onclick = onClick;
        return b;
    }

    function swatchGrid(options, isSelected, onPick) {
        const wrap = el('div');
        const picked = el('div', 'picked');
        const grid = el('div', 'swatches');
        for (const o of options) {
            const b = el('button', isSelected(o) ? 'selected' : '');
            b.title = o.l;
            b.setAttribute('aria-label', o.l);
            if (o.v === false || o.v === -1) b.classList.add('off');
            else b.style.background = o.hex || '#888';
            if (isSelected(o)) picked.textContent = o.l;
            b.onmouseenter = () => { picked.textContent = o.l; };
            b.onclick = () => onPick(o);
            grid.append(b);
        }
        grid.onmouseleave = () => {
            const sel = options.find(isSelected);
            picked.textContent = sel ? sel.l : '';
        };
        wrap.append(picked, grid);
        return wrap;
    }

    function renderEditor() {
        const body = $('editor');
        body.replaceChildren();
        const item = findItem(st.key);
        $('item').textContent = item ? item.label : '';
        if (!item) {
            $('price').textContent = '';
            return body.append(el('p', 'empty', st.locale.none));
        }
        // performance options carry their own per-level price
        const perOption = (item.options || []).some(o => o.p);
        $('price').textContent = perOption ? '' : money(item.price);

        if (item.type === 'options') {
            const chips = el('div', 'chips');
            for (const o of item.options) {
                chips.append(chip(o.l, eq(o.v, item.value), () => set(item.key, o.v), o.p ? money(o.p) : null));
            }
            body.append(chips);
        } else if (item.type === 'swatch') {
            body.append(swatchGrid(item.options, o => eq(o.v, item.value), o => set(item.key, o.v)));
            if (item.custom) {
                const start = Array.isArray(item.value) ? item.value : null;
                body.append(colorPicker(start, rgb => {
                    item.value = rgb;
                    stream(item);
                }));
            }
        } else if (item.type === 'paint') {
            const colorOf = v => v.rgb ? { rgb: v.rgb } : { c: v.c };
            body.append(el('span', 'sub', st.locale.paintType));
            const types = el('div', 'chips');
            for (const t of item.types) {
                types.append(chip(t.l, t.v === item.value.t, () => set(item.key, { t: t.v, ...colorOf(item.value) })));
            }
            body.append(types, swatchGrid(item.options, o => !item.value.rgb && o.v === item.value.c, o => set(item.key, { t: item.value.t, c: o.v })));
            if (item.custom) {
                const preset = item.options.find(o => o.v === item.value.c);
                const start = item.value.rgb || (preset && fromHex(preset.hex));
                body.append(colorPicker(start, rgb => {
                    item.value = { t: item.value.t, rgb };
                    stream(item);
                }));
            }
        } else if (item.type === 'multi') {
            const chips = el('div', 'chips');
            item.fields.forEach((name, i) => {
                chips.append(chip(name, !!item.value[i], () => {
                    const next = item.fields.map((_, j) => !!item.value[j]);
                    next[i] = !next[i];
                    set(item.key, next);
                }));
            });
            body.append(chips);
        } else if (item.type === 'sliders') {
            for (const f of item.fields) {
                const row = el('label', 'slider');
                const input = el('input');
                const out = el('span', '', Number(item.value[f.id] ?? 0).toFixed(3));
                input.type = 'range';
                input.min = f.min;
                input.max = f.max;
                input.step = f.step;
                input.value = item.value[f.id] ?? 0;
                input.oninput = () => {
                    item.value = { ...item.value, [f.id]: Number(input.value) };
                    out.textContent = Number(input.value).toFixed(3);
                    stream(item);
                };
                row.append(el('span', '', f.label), input, out);
                body.append(row);
            }
        }
    }

    function renderCart() {
        const cart = $('cart');
        cart.replaceChildren();
        if (!st.cart.lines.length) cart.append(el('li', 'none', st.locale.empty));
        for (const line of st.cart.lines) {
            const li = el('li');
            const x = el('button', '', '✕');
            x.title = 'Remove';
            x.onclick = () => remove(line.key);
            li.append(el('span', '', line.label), el('span', '', money(line.price)), x);
            li.title = line.label;
            cart.append(li);
        }
        $('total').textContent = money(st.cart.total);
        $('confirm').disabled = !st.cart.lines.length;
    }

    function render() {
        renderTabs();
        renderList();
        renderEditor();
        renderCart();
    }

    // ------------------------------------------------------------
    // Static controls
    // ------------------------------------------------------------

    $('left').onclick = () => post('tuner:rotate', { delta: -20 });
    $('right').onclick = () => post('tuner:rotate', { delta: 20 });
    $('cancel').onclick = () => post('tuner:cancel');
    $('close').onclick = () => post('tuner:cancel');
    $('confirm').onclick = async () => {
        if (pending || !st.cart.lines.length) return;
        pending = true;
        $('confirm').disabled = true;
        const ok = await post('tuner:confirm');
        pending = false;
        if (!ok && st) $('confirm').disabled = false;
    };

    const orbit = root.querySelector('.orbit');
    let drag = null, queued = 0, last = 0;
    orbit.onpointerdown = e => { drag = e.clientX; orbit.setPointerCapture(e.pointerId); };
    orbit.onpointermove = e => {
        if (drag === null) return;
        queued += (e.clientX - drag) * 0.35;
        drag = e.clientX;
        if (performance.now() - last > 30) {
            post('tuner:rotate', { delta: queued });
            queued = 0;
            last = performance.now();
        }
    };
    orbit.onpointerup = () => { if (queued) post('tuner:rotate', { delta: queued }); drag = null; queued = 0; };
    orbit.onpointercancel = () => { drag = null; queued = 0; };

    // Game input stays on for push-to-talk; switch it off while typing in text fields.
    const isText = t => t && t.tagName === 'INPUT' && t.type !== 'range';
    document.addEventListener('focusin', e => { if (st && isText(e.target)) post('tuner:typing', { typing: true }); });
    document.addEventListener('focusout', e => { if (st && isText(e.target)) post('tuner:typing', { typing: false }); });

    window.addEventListener('keydown', e => {
        if (!st) return;
        if (e.key === 'Escape') { e.preventDefault(); if (!e.repeat) post('tuner:cancel'); }
        else if (e.target.tagName !== 'INPUT' && (e.key === 'a' || e.key === 'ArrowLeft')) post('tuner:rotate', { delta: -15 });
        else if (e.target.tagName !== 'INPUT' && (e.key === 'd' || e.key === 'ArrowRight')) post('tuner:rotate', { delta: 15 });
    });

    // ------------------------------------------------------------
    // Messages
    // ------------------------------------------------------------

    window.addEventListener('message', ({ data: msg }) => {
        if (!msg || !msg.action) return;
        if (msg.action === 'open') {
            const d = msg.data;
            st = { session: d.session, categories: d.categories || [], cart: d.cart, locale: d.locale || {} };
            st.cat = (st.categories[0] || {}).id;
            st.key = (currentItems()[0] || {}).key;
            pending = false;
            $('mode').textContent = st.locale.mode || '';
            $('title').textContent = d.title || '';
            $('subtitle').textContent = d.subtitle || '';
            $('rotate').textContent = st.locale.rotate || '';
            $('cart-title').textContent = st.locale.cart || '';
            $('total-label').textContent = st.locale.total || '';
            $('confirm').textContent = st.locale.confirm || 'Confirm';
            $('cancel').textContent = st.locale.cancel || 'Cancel';
            $('status').textContent = '';
            root.hidden = false;
            render();
            if (st.key) post('tuner:focus', { key: st.key });
        } else if (msg.action === 'close') {
            clearTimeout(streamTimer);
            streamSeq++;
            root.hidden = true;
            st = null;
            drag = null;
            queued = 0;
        }
    });
})();
