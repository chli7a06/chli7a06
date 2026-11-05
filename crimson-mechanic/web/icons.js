/* Local, dependency-free automotive pictograms. Keys never depend on translated labels. */
window.MechanicIcons = (() => {
    const shapes = {
        parts: 'M3 10 6 5h11l4 5 2 2v6h-3v-2H4v2H1v-6Zm4-3-2 4h14l-3-4ZM4 12v2h3v-2Zm13 0v2h3v-2Z',
        wheels: 'M12 1a11 11 0 1 0 0 22 11 11 0 0 0 0-22Zm0 3 2 6 6-2-4 5 4 4-6-1-2 5-2-5-6 1 4-4-4-5 6 2Z',
        paint: 'M8 2h9v6H8Zm1 7h7l4 3-2 3-5-2-4 9-4-2 4-9H5V9Z',
        lights: 'M13 4c6 0 9 3 9 8s-3 8-9 8H9V4ZM1 5h6v2H1Zm0 6h6v2H1Zm0 6h6v2H1Z',
        extras: 'M15 2a7 7 0 0 0-7 9L1 18a3 3 0 0 0 5 5l8-8a7 7 0 0 0 8-9l-5 5-4-4 5-5Z',
        performance: 'M7 3h9v3h4v4h3v9h-4v-2H7l-4-4H1V7h4v3h2V6h4V5H7Z',
        stance: 'm14 1 3 1-2 5 4 2-1 2-9-4 1-2 2 1Zm-6 8 10 4-1 2-10-4Zm-2 4 10 4-1 2-3-1-2 5-3-1 2-5-4-2Z',
        spoiler: 'M1 6h22v4H1Zm4 5h3v7H5Zm11 0h3v7h-3Z',
        front: 'M2 6h3v3h14V6h3v11l-3 2H5l-3-2Zm4 6v2h12v-2Z',
        rear: 'M2 6h3v4h14V6h3v12H2Zm3 7v2h3v-2Zm11 0v2h3v-2Z',
        skirts: 'M3 10h17l3 6H1Zm3 2v2h12v-2Z',
        exhaust: 'm2 12 8-7 4 4-8 8Zm10 0 7-7 4 4-8 8ZM4 14l-1 2 2 1 1-2Zm12 0-1 2 2 1 1-2Z',
        grille: 'M1 6h22l-2 13H3Zm3 3v2h16V9Zm1 5v2h14v-2Z',
        hood: 'M3 3h4l1 3h8l1-3h4l-3 18H6Zm6 5 1 10h4l1-10Z',
        fender: 'M2 19V9l6-5h14v5H11l-4 4v6Z',
        roof: 'M1 16 5 7l4-2h6l4 2 4 9h-4l-2-3H7l-2 3Z',
        horn: 'M9 5a8 8 0 1 0 0 16 8 8 0 0 0 0-16Zm0 4a4 4 0 1 1 0 8 4 4 0 0 1 0-8Zm9 0 5-5v16l-5-4Z',
        livery: 'M4 3h7L8 9H1Zm9 0h7l-3 6h-7ZM8 10h7l-3 6H5Zm9 0h7l-3 6h-7ZM4 17h7l-3 6H1Z',
        window: 'M5 4h14l4 15H1Zm2 3-3 9h16l-3-9Z',
        plate: 'M1 6h22v13H1Zm3 3v7h17V9Zm2 2h13v3H6Z',
        seat: 'M5 2h7v10l7 3v6H4V7Zm9 13H7v3h7Z',
        gauge: 'M12 2A11 11 0 0 0 2 19h20A11 11 0 0 0 12 2Zm0 3a8 8 0 0 1 8 11H4a8 8 0 0 1 8-11Zm5 2-3 8h-4Z',
        speaker: 'M3 1h18v22H3Zm9 3a2 2 0 1 0 0 4 2 2 0 0 0 0-4Zm0 6a5 5 0 1 0 0 10 5 5 0 0 0 0-10Z'
    };
    const mods = {0:'spoiler',1:'front',2:'rear',3:'skirts',4:'exhaust',5:'parts',6:'grille',7:'hood',8:'fender',9:'fender',10:'roof',11:'performance',12:'wheels',13:'performance',14:'horn',15:'stance',16:'parts',23:'wheels',24:'wheels',25:'plate',26:'plate',27:'parts',28:'extras',29:'gauge',30:'gauge',31:'speaker',32:'seat',33:'wheels',34:'performance',35:'plate',36:'speaker',37:'hood',38:'stance',39:'performance',40:'grille',41:'stance',42:'fender',43:'extras',44:'parts',45:'extras',46:'window',48:'livery',49:'lights'};
    const aliases = {repair:'extras',wheelType:'wheels',customTyres:'wheels',smoke:'exhaust',paint1:'paint',paint2:'paint',pearl:'paint',wheelColor:'paint',interior:'seat',dashboard:'gauge',windowTint:'window',plateIndex:'plate',xenon:'lights',neon:'lights',neonColor:'lights',turbo:'performance'};
    function create(key, category) {
        const name = key.startsWith('mod:') ? mods[key.slice(4)] : aliases[key] || key;
        const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        svg.setAttribute('viewBox', '0 0 24 24');
        svg.setAttribute('class', 'part-icon');
        svg.setAttribute('aria-hidden', 'true');
        svg.setAttribute('focusable', 'false');
        const path = document.createElementNS(svg.namespaceURI, 'path');
        path.setAttribute('fill-rule', 'evenodd');
        path.setAttribute('d', shapes[name] || shapes[aliases[category] || category] || shapes.extras);
        svg.append(path);
        return svg;
    }
    return { create };
})();
