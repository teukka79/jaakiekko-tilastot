'use strict';
// ====================== Apurit ======================
const $ = (s, r = document) => r.querySelector(s);
const WEEKDAYS = ['sunnuntai', 'maanantai', 'tiistai', 'keskiviikko', 'torstai', 'perjantai', 'lauantai'];
const fmtDay = d => `${WEEKDAYS[d.getDay()]} ${d.getDate()}.${d.getMonth() + 1}.`;
const fmtTime = d => timeString(d);
const shortDate = iso => { const p = String(iso).split('-'); return p.length === 3 ? `${+p[2]}.${+p[1]}.` : iso; };

function badgeHue(name) { let v = 7; for (const ch of name) v = (v * 31 + ch.codePointAt(0)) % 360; return v; }
function badgeHTML(name) {
  const h = badgeHue(name);
  return `<span class="badge" style="background:hsl(${h},38%,30.5%);border-radius:22%;font-size:calc(var(--sz) * .3)">${esc(Store.abbr(name))}</span>`;
}
function logoHTML(team, size = 28) {
  const url = Store.logoURL(team);
  const scale = url && url.includes('nhle.com') ? 1 : 0.76;
  const inner = Math.round(size * scale);
  const body = url ? `<img src="${esc(url)}" data-team="${esc(team)}" loading="lazy" alt="">` : badgeHTML(team);
  return `<span class="logo" style="width:${size}px;height:${size}px;--sz:${inner}px"><span style="display:flex;width:${inner}px;height:${inner}px">${body}</span></span>`;
}
document.addEventListener('error', e => {
  const img = e.target;
  if (img && img.tagName === 'IMG' && img.dataset.team) { img.parentElement.innerHTML = badgeHTML(img.dataset.team); }
}, true);

function starsHTML(value, { size = 15, id = '', ro = false } = {}) {
  let s = `<span class="stars${ro ? ' ro' : ''}" style="--fs:${size}px">`;
  for (let i = 1; i <= 3; i++) s += `<span class="${i <= value ? 'on' : ''}" style="font-size:${size}px"${ro ? '' : ` data-act="star" data-id="${esc(id)}" data-n="${i}"`}>${i <= value ? '★' : '☆'}</span>`;
  return s + '</span>';
}
const chip = t => `<span class="chip">${esc(t)}</span>`;
const label = t => `<div class="label">${esc(t)}</div>`;
const spinner = () => '<span class="spinner"></span>';

// ====================== Modaalit ======================
const modals = [];
function openModal({ width = 560, html = '', pad = 22, onClose } = {}) {
  const ov = document.createElement('div'); ov.className = 'overlay';
  ov.innerHTML = `<div class="modal" style="width:${width}px;padding:${pad}px">${html}</div>`;
  $('#modals').appendChild(ov);
  const m = { el: ov, body: ov.firstElementChild, alive: true, refresh: null, close() { if (!m.alive) return; m.alive = false; ov.remove(); const i = modals.indexOf(m); if (i >= 0) modals.splice(i, 1); onClose && onClose(); } };
  ov.addEventListener('mousedown', e => { if (e.target === ov) m.close(); });
  ov.addEventListener('click', e => { if (e.target.closest('[data-close]')) m.close(); });
  modals.push(m); return m;
}
document.addEventListener('keydown', e => { if (e.key === 'Escape' && modals.length) modals[modals.length - 1].close(); });
const closeBtn = () => '<button class="x-btn" data-close title="Sulje">✕</button>';

// ====================== Pääasetelma ======================
const UI = { league: 'NHL', team: null, search: '', sortKey: 'points', asc: false, onlyFavs: false, mode: 'table', compare: [] };
const COLS = [
  { key: 'name', title: 'Pelaaja', w: null }, { key: 'number', title: 'Nro', w: 40 }, { key: 'nat', title: 'Kansalaisuus', w: 100 }, { key: 'slot', title: 'Pelipaikka', w: 120 },
  { key: 'games', title: 'Ottelut', w: 58 }, { key: 'goals', title: 'Maalit', w: 54 }, { key: 'assists', title: 'Syötöt', w: 54 }, { key: 'points', title: 'Pisteet', w: 56 },
  { key: 'ppg', title: 'Pist./ott.', w: 70 }, { key: 'shots', title: 'Laukaukset', w: 78 }, { key: 'pp', title: 'Ylivoima', w: 62 }, { key: 'plusMinus', title: '+/-', w: 46 }, { key: 'recent', title: 'Viim. 5', w: 156, nosort: true }, { key: 'rating', title: 'Tähdet', w: 84 },
];

function visiblePlayers() {
  const q = norm(UI.search);
  const list = Store.players.filter(p =>
    (!UI.league || p.league === UI.league) && (!UI.team || p.team === UI.team) && (!UI.onlyFavs || Store.rating(p.id) === 3) &&
    (!q || norm(p.name + ' ' + p.team + ' ' + (p.nat || '')).includes(q)));
  const dir = UI.asc ? 1 : -1;
  const byName = (x, y) => x.name.localeCompare(y.name, 'fi');
  const numCmp = f => (x, y) => { const a = f(x), b = f(y); if (a == null && b == null) return byName(x, y); if (a == null) return 1; if (b == null) return -1; return a === b ? byName(x, y) : (a < b ? -dir : dir); };
  const strCmp = f => (x, y) => { const a = f(x), b = f(y); return a === b ? byName(x, y) : a.localeCompare(b, 'fi') * dir; };
  const cmps = {
    name: (x, y) => byName(x, y) * dir, number: numCmp(p => p.number), nat: strCmp(p => natLabel(p.nat)), slot: strCmp(p => slotLabel(p)), team: strCmp(p => p.team),
    games: numCmp(p => p.games), goals: numCmp(p => p.goals), assists: numCmp(p => p.assists), points: numCmp(playerPoints), ppg: numCmp(playerPPG), shots: numCmp(p => p.shots),
    pp: numCmp(p => p.ppPoints), plusMinus: numCmp(p => p.plusMinus), rating: (x, y) => { const a = Store.rating(x.id), b = Store.rating(y.id); return a === b ? byName(x, y) : (a < b ? -dir : dir); },
  };
  return list.sort(cmps[UI.sortKey]);
}

function buildShell() {
  $('#app').innerHTML = `
    <div class="header">
      <div><div class="title">Jääkiekon Pistepörssi</div><div class="subtitle" id="subtitle"></div></div>
      <div class="spacer"></div>
      <div class="row" style="gap:10px"><span id="spin"></span><div class="status" id="status"></div><button class="btn" id="refresh">⟳ Päivitä</button></div>
    </div>
    <div class="toolbar" id="toolbar"></div>
    <div id="main" class="card tablewrap"></div>`;
  $('#refresh').onclick = () => Store.refreshLive(true);
  renderToolbar(); renderHeader(); renderMain();
}

function renderHeader() {
  $('#subtitle').textContent = `Kausi 2026/2027 · ${visiblePlayers().length} pelaajaa · ${Store.ratedCount} arvosteltu · ${Store.notesCount} muistiinpanoa`;
  $('#status').textContent = Store.liveStatus + (Store.liveGamesOn ? ' · LIVE' : '');
  $('#spin').innerHTML = Store.isRefreshing ? spinner() : '';
  $('#refresh').disabled = Store.isRefreshing;
}

function renderToolbar() {
  const teamNames = Store.teamNames(UI.league);
  if (UI.team && !teamNames.includes(UI.team)) UI.team = null;
  const lbtn = (id, text, flags) => `<button class="btn${UI.league === id ? ' active' : ''}" data-league="${id ?? ''}">${flags ? flags + ' ' : ''}${esc(text)}</button>`;
  $('#toolbar').innerHTML = `
    <div class="row">${lbtn(null, 'Kaikki')}${LEAGUES.map(l => lbtn(l.id, l.label, l.flags)).join('')}<div class="spacer"></div>
      <div class="seg"><button data-mode="table" class="${UI.mode === 'table' ? 'on' : ''}">▤ Taulukko</button><button data-mode="teams" class="${UI.mode === 'teams' ? 'on' : ''}">▦ Joukkueet</button></div></div>
    <div class="row">
      <div class="search"><span class="ic">⌕</span><input class="input" id="search" placeholder="Hae pelaajaa, joukkuetta tai kansallisuutta" value="${esc(UI.search)}"><button class="x ${UI.search ? '' : 'hidden'}" id="clearsearch">✕</button></div>
      <select class="select" id="teamsel" style="width:210px"><option value="">Kaikki joukkueet</option>${teamNames.map(n => `<option value="${esc(n)}"${UI.team === n ? ' selected' : ''}>${esc(n)}</option>`).join('')}</select>
      ${UI.team ? '<button class="btn" id="teamres">📊 Joukkueen tulokset</button>' : ''}<button class="btn${UI.onlyFavs ? ' active' : ''}" id="favs">${UI.onlyFavs ? '★' : '☆'} Suosikit</button>
      <div class="spacer"></div>
      <button class="btn${UI.compare.length >= 2 ? ' active' : ''}" id="cmpbtn"${UI.compare.length < 2 ? ' disabled' : ''}>⇄ Vertaa (${UI.compare.length})</button>
      <button class="btn" id="standbtn">☰ Sarjataulukko</button>
      <button class="btn" id="schedbtn">📅 Otteluohjelma</button>
      <button class="btn primary" id="addbtn">＋ Lisää pelaaja</button>
      <div style="position:relative"><button class="btn" id="menubtn">⋯</button><div class="menu hidden" id="menu">
        <button data-m="export">Vie JSON…</button><button data-m="import">Tuo JSON…</button><button data-m="stand">Sarjataulukko</button><button data-m="sched">Otteluohjelma</button><button data-m="settings">Asetukset…</button><hr><button data-m="reset">Nollaa näkyvien tähdet</button></div></div>
    </div>`;
  const tb = $('#toolbar');
  tb.querySelectorAll('[data-league]').forEach(b => b.onclick = () => { UI.league = b.dataset.league || null; renderToolbar(); renderHeader(); renderMain(); });
  tb.querySelectorAll('[data-mode]').forEach(b => b.onclick = () => { UI.mode = b.dataset.mode; renderToolbar(); renderMain(); });
  let st; $('#search').oninput = e => { UI.search = e.target.value; $('#clearsearch').classList.toggle('hidden', !UI.search); clearTimeout(st); st = setTimeout(() => { renderHeader(); renderMain(); }, 120); };
  $('#clearsearch').onclick = () => { UI.search = ''; renderToolbar(); renderHeader(); renderMain(); };
  $('#teamsel').onchange = e => { UI.team = e.target.value || null; renderToolbar(); renderHeader(); renderMain(); };
  if ($('#teamres')) $('#teamres').onclick = () => openTeamResults(UI.team);
  $('#favs').onclick = () => { UI.onlyFavs = !UI.onlyFavs; renderToolbar(); renderHeader(); renderMain(); };
  $('#cmpbtn').onclick = () => openCompare();
  $('#standbtn').onclick = () => openStandings(); $('#schedbtn').onclick = () => openSchedule(); $('#addbtn').onclick = () => openForm(null);
  const menu = $('#menu'); $('#menubtn').onclick = e => { e.stopPropagation(); menu.classList.toggle('hidden'); };
  menu.onclick = async e => {
    const b = e.target.closest('[data-m]'); if (!b) return; menu.classList.add('hidden');
    switch (b.dataset.m) {
      case 'export': { const ok = await native.saveFile('jaakiekko-pistepörssi-2026-2027.json', Store.exportText()); if (ok) Store.flash('Vienti valmis'); break; }
      case 'import': { const t = await native.openFile(); if (t) Store.importText(t); break; }
      case 'stand': openStandings(); break; case 'sched': openSchedule(); break; case 'settings': openSettings(); break;
      case 'reset': Store.resetRatings(visiblePlayers()); break;
    }
  };
}
document.addEventListener('click', e => { const m = $('#menu'); if (m && !e.target.closest('#menubtn')) m.classList.add('hidden'); });

function renderMain() {
  const main = $('#main'); if (!main) return;
  if (UI.mode === 'teams') { main.className = 'tablewrap'; main.innerHTML = '<div class="grid" id="grid"></div>'; renderTeams(); return; }
  main.className = 'card tablewrap';
  if (!$('#tbody')) {
    main.innerHTML = `<div class="thead" id="thead"></div><div class="tbody" id="tbody"></div>`;
    $('#thead').onclick = e => { const h = e.target.closest('[data-sort]'); if (!h) return; const k = h.dataset.sort; if (UI.sortKey === k) UI.asc = !UI.asc; else { UI.sortKey = k; UI.asc = ['name', 'team', 'slot', 'nat'].includes(k); } renderMain(); };
    $('#tbody').onclick = e => {
      const a = e.target.closest('[data-act]'); if (!a) return; const id = a.dataset.id;
      if (a.dataset.act === 'cmp') { const i = UI.compare.indexOf(id); if (i >= 0) UI.compare.splice(i, 1); else if (UI.compare.length < 3) UI.compare.push(id); else Store.flash('Vertailuun voi valita enintään 3 pelaajaa'); renderToolbar(); renderMain(); }
      else if (a.dataset.act === 'open') openDetail(id);
      else if (a.dataset.act === 'star') Store.setRating(id, +a.dataset.n);
    };
  }
  $('#thead').innerHTML = `<div style="width:22px"></div>` + COLS.map(c => c.nosort
    ? `<div class="h" title="Viimeisten pelien jakauma. Näytettävä luku seuraa lajittelua: maalit, syötöt, ylivoima tai laukaukset; muuten pisteet." style="width:${c.w}px;flex:none;cursor:default">${recentTitle()}</div>`
    : `<div class="h${UI.sortKey === c.key ? ' on' : ''}" data-sort="${c.key}" style="${c.w ? `width:${c.w}px;flex:none` : 'flex:1;text-align:left'}">${c.title}${UI.sortKey === c.key ? (UI.asc ? ' ▲' : ' ▼') : ''}</div>`).join('');
  const list = visiblePlayers(); const body = $('#tbody'); const top = body.scrollTop;
  if (!list.length) { body.innerHTML = '<div class="empty" style="height:100%"><div style="font-size:28px">⌕</div>Ei hakua vastaavia pelaajia</div>'; return; }
  body.innerHTML = list.map(rowHTML).join(''); body.scrollTop = top; loadRecentForVisible(list);
}

function rowHTML(p) {
  const sel = UI.compare.includes(p.id); const pts = playerPoints(p); const pm = p.plusMinus;
  return `<div class="trow${sel ? ' sel' : ''}">
    <div class="chk${sel ? ' on' : ''}" data-act="cmp" data-id="${esc(p.id)}" title="Valitse vertailuun">${sel ? '☑' : '☐'}</div>
    <div class="cname" data-act="open" data-id="${esc(p.id)}">${logoHTML(p.team, 44)}<div style="min-width:0"><div class="n">${esc(p.name)}${Store.isHot(p) ? '<span title="Vähintään yksi piste jokaisessa neljässä viimeisessä pelissä">🔥</span>' : ''}${Store.note(p.id) ? '<span class="cyan" style="font-size:11px">✎</span>' : ''}</div><div class="t">${esc(p.flag)} ${esc(p.team)}</div></div></div>
    <div class="c muted" style="width:40px">${p.number != null ? '#' + p.number : '–'}</div>
    <div class="c muted" style="width:100px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${esc(natLabel(p.nat))}</div>
    <div class="c muted" style="width:120px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${esc(slotLabel(p))}</div>
    <div class="c" style="width:58px">${num(p.games)}</div><div class="c" style="width:54px">${num(p.goals)}</div><div class="c" style="width:54px">${num(p.assists)}</div>
    <div class="c cyan" style="width:56px;font-weight:700">${num(pts)}</div><div class="c" style="width:70px">${ppgString(playerPPG(p))}</div>
    <div class="c" style="width:78px">${num(p.shots)}</div><div class="c" style="width:62px">${num(p.ppPoints)}</div>
    <div class="c ${pm > 0 ? 'green' : pm < 0 ? 'red' : ''}" style="width:46px">${signed(pm)}</div>
    <div class="c" style="width:156px;justify-content:center" data-rg="${esc(p.id)}">${recentCellHTML(p)}</div>
    <div class="c" style="width:84px">${starsHTML(Store.rating(p.id), { id: p.id })}</div></div>`;
}

function renderTeams() {
  const grid = $('#grid'); if (!grid) return;
  grid.innerHTML = Store.teamNames(UI.league).map(name => {
    const roster = Store.players.filter(p => p.team === name);
    let top = null; for (const p of roster) if (playerPoints(p) != null && (!top || playerPoints(p) > playerPoints(top))) top = p;
    const t = Store.teamByName[name];
    return `<div class="card team" data-team="${esc(name)}"><div class="row" style="gap:12px">${logoHTML(name, 52)}<div style="min-width:0"><div style="font-size:14px;font-weight:700">${esc(name)}</div><div class="muted" style="font-size:11px">${esc(t ? leagueLabel(t.league) : 'Oma joukkue')}</div></div></div><hr>
      <div class="row" style="font-size:11px"><span class="muted">${roster.length} pelaajaa</span><button class="btn" data-res="${esc(name)}" style="padding:3px 8px;font-size:11px">Tulokset</button><div class="spacer"></div>${top ? `<span class="cyan" style="font-weight:600">${esc(top.name.split(' ').pop())} ${playerPoints(top)} p</span>` : ''}</div></div>`;
  }).join('');
  grid.onclick = e => { const rb = e.target.closest('[data-res]'); if (rb) { openTeamResults(rb.dataset.res); return; } const c = e.target.closest('[data-team]'); if (!c) return; const n = c.dataset.team; UI.team = n; const t = Store.teamByName[n]; if (t) UI.league = t.league; UI.mode = 'table'; renderToolbar(); renderHeader(); renderMain(); };
}

// ====================== Päivitysvirta ======================
let rafPending = false;
Store.on(what => {
  if (what === 'toast') { const t = $('#toast'); t.textContent = Store.toast || ''; t.classList.toggle('hidden', !Store.toast); return; }
  if (what === 'status') { renderHeader(); return; }
  if (rafPending) return; rafPending = true;
  requestAnimationFrame(() => {
    rafPending = false; renderHeader();
    if (UI.mode === 'table') renderMain(); else renderTeams();
    for (const m of modals.slice()) if (m.refresh) m.refresh(what);
  });
});

(async function main() {
  await Store.init(); await Sound.load(); buildShell(); Store.emit('all');
  await Store.refreshLive();
  while (true) { await sleep(30000); try { await Store.autoRefreshTick(); } catch {} }
})();


// ---- Viimeisten pelien jakauma (sarake seuraa lajittelua) ----
const RG_MODES = { goals: ['goals', 'maalit'], assists: ['assists', 'syötöt'], pp: ['pp', 'ylivoima'], shots: ['shots', 'laukaukset'] };
function recentMode() { return RG_MODES[UI.sortKey] || ['points', 'pisteet']; }
function recentTitle() { return 'Viim. 5: ' + recentMode()[1]; }
function recentValue(g, mode) {
  if (mode === 'points') return (g.goals || 0) + (g.assists || 0);
  const v = g[mode]; return v == null ? null : v;
}
function recentCellHTML(p) {
  const c = Store.recentCache[p.id]; const mode = recentMode()[0];
  if (!c) return '<span class="muted" style="font-size:11px">…</span>';
  if (!c.v.games.length) return '<span class="muted">–</span>';
  const games = c.v.games.slice(0, 5).slice().reverse();
  return games.map(g => {
    const v = recentValue(g, mode); const hi = mode === 'shots' ? [1, 3, 5] : [1, 2, 3];
    const cls = v == null ? 'rg0' : v >= hi[2] ? 'rg3' : v >= hi[1] ? 'rg2' : v >= hi[0] ? 'rg1' : 'rg0';
    const d = (g.date || '').split('-'); const ds = d.length === 3 ? `${+d[2]}.${+d[1]}.` : '';
    const tip = `${ds} ${g.home === true ? 'vs' : g.home === false ? '@' : '–'} ${g.opponent} · M ${g.goals || 0}, S ${g.assists || 0}${g.pp != null ? ', YV ' + g.pp : ''}${g.shots != null ? ', L ' + g.shots : ''}`;
    return `<span class="rg ${cls}" title="${esc(tip)}">${v == null ? '–' : v}</span>`;
  }).join('');
}
const rgInflight = new Set();
async function loadRecentForVisible(list) {
  const todo = list.slice(0, 80).filter(p => !Store.recentCache[p.id] && !rgInflight.has(p.id) && (p.league === 'NHL' || p.league === 'SM-liiga' || p.league === 'Mestis'));
  if (!todo.length) return;
  const apply = p => { document.querySelectorAll('[data-rg]').forEach(el => { if (el.dataset.rg === p.id) el.innerHTML = recentCellHTML(p); }); };
  await pool(todo, 4, async p => { rgInflight.add(p.id); try { await Store.recentGames(p); } catch (e) { } rgInflight.delete(p.id); if (!Store.recentCache[p.id]) { document.querySelectorAll('[data-rg]').forEach(el => { if (el.dataset.rg === p.id) el.innerHTML = '<span class="muted">–</span>'; }); } else apply(p); });
}
