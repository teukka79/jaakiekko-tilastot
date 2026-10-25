'use strict';
// ====================== Pelaajakortti ======================
function openDetail(id) {
  const m = openModal({ width: 560, pad: 24 });
  m.body.innerHTML = `<div id="dtop"></div><div id="drecent" style="margin-top:16px"></div>
    <div style="margin-top:16px">${label('Muistiinpanot')}<textarea id="dnote" style="margin-top:6px;min-height:90px"></textarea></div><div class="row" id="dbtns" style="margin-top:16px"></div>`;
  $('#dnote', m.body).value = Store.note(id);
  $('#dnote', m.body).oninput = e => Store.setNote(id, e.target.value);
  const top = () => {
    const p = Store.player(id); const t = $('#dtop', m.body);
    if (!p) { t.innerHTML = '<div class="muted">Pelaajaa ei löytynyt</div>'; return; }
    const chips = [positionLabel(p), p.nat, playerAge(p) != null ? `${playerAge(p)} v` : null, p.shoots ? (p.shoots === 'L' ? 'Vasenkätinen' : p.shoots === 'R' ? 'Oikeakätinen' : p.shoots) : null].filter(Boolean).map(chip).join(' ');
    const st = (l, v, hl) => `<div class="card sm stat${hl ? ' hl' : ''}"><b>${v}</b><span>${l}</span></div>`;
    t.innerHTML = `<div class="row" style="gap:14px">${logoHTML(p.team, 56)}<div><div style="font-size:22px;font-weight:800">${esc(p.name)}</div><div class="muted" style="font-size:12px;margin-top:4px">${esc(p.flag)} <a href="#" data-teamres="${esc(p.team)}" style="color:inherit;text-decoration:underline dotted">${esc(p.team)}</a> · ${esc(leagueLabel(p.league))}</div></div><div class="spacer"></div>${closeBtn()}</div>
      <div class="row" style="margin-top:16px">${starsHTML(Store.rating(id), { size: 22, id })}<div class="spacer"></div>${chips}</div>
      <div class="stats" style="margin-top:16px">${st('O', num(p.games))}${st('M', num(p.goals))}${st('S', num(p.assists))}${st('P', num(playerPoints(p)), true)}${st('P/O', ppgString(playerPPG(p)))}${st('L', num(p.shots))}${st('YV', num(p.ppPoints))}${st('RM', num(p.pim))}${st('+/-', signed(p.plusMinus))}</div>`;
    const btns = $('#dbtns', m.body);
    btns.innerHTML = `<button class="btn" id="dedit">✎ Muokkaa tietoja</button>${Store.state.edits[id] ? '<button class="btn" id="dreset">↺ Palauta alkuperäiset</button>' : ''}<div class="spacer"></div>${p.isCustom ? '<button class="btn danger" id="ddel">🗑 Poista</button>' : ''}`;
    $('#dedit', btns).onclick = () => openForm(p);
    if ($('#dreset', btns)) $('#dreset', btns).onclick = () => Store.resetEdit(id);
    if ($('#ddel', btns)) $('#ddel', btns).onclick = () => { if (confirm('Poistetaanko pelaaja?')) { Store.deleteCustom(id); m.close(); } };
  };
  m.body.addEventListener('click', e => { const s = e.target.closest('[data-act="star"]'); if (s) Store.setRating(s.dataset.id, +s.dataset.n); const t = e.target.closest('[data-teamres]'); if (t) { e.preventDefault(); openTeamResults(t.dataset.teamres); } });
  m.refresh = top; top();
  // Viimeiset 5 peliä
  const rec = $('#drecent', m.body); const p0 = Store.player(id);
  rec.innerHTML = `<div class="row">${label('Viimeiset 5 peliä')}<div class="spacer"></div><span id="rsum"></span></div><div id="rbody" style="margin-top:8px" class="muted"><span class="spinner"></span> Haetaan…</div>`;
  if (!p0) return;
  Store.recentGames(p0).then(r => {
    if (!m.alive) return; const b = $('#rbody', m.body); b.className = ''; let h = '';
    if (r.games.length) {
      const g = r.games.reduce((s, x) => s + x.goals, 0), a = r.games.reduce((s, x) => s + x.assists, 0);
      $('#rsum', m.body).innerHTML = chip(`${g + a} p (${g}+${a})`);
      const sh = r.games.some(x => x.shots != null), pp = r.games.some(x => x.pp != null);
      h += `<div class="card sm"><table class="tbl"><thead><tr><th class="l">Päivä</th><th class="l">Koti/Vieras</th><th class="l">Vastustaja</th>${sh ? '<th>Laukaus</th>' : ''}<th>Maali</th><th>Syöttö</th><th>Pisteet</th>${pp ? '<th>Ylivoima</th>' : ''}</tr></thead><tbody>` +
        r.games.map(x => { const pts = x.goals + x.assists; return `<tr style="${pts > 0 ? 'background:rgba(34,211,238,.07)' : ''}"><td class="l muted">${shortDate(x.date)}</td><td class="l muted">${x.home === true ? 'Koti' : x.home === false ? 'Vieras' : '–'}</td><td class="l" style="font-weight:500">${esc(x.opponent)}</td>${sh ? `<td class="muted">${num(x.shots)}</td>` : ''}<td>${x.goals}</td><td>${x.assists}</td><td class="${pts > 0 ? 'cyan' : 'muted'}" style="font-weight:700">${pts}</td>${pp ? `<td class="${(x.pp || 0) > 0 ? 'amber' : 'muted'}">${num(x.pp)}</td>` : ''}</tr>`; }).join('') + '</tbody></table></div>';
    }
    if (r.note) h += `<div class="muted" style="font-size:11px;margin-top:6px">${esc(r.note)}</div>`;
    b.innerHTML = h;
  });
}

// ====================== Lomake ======================
function openForm(player) {
  const isEdit = !!player, isCustom = player ? player.isCustom : true;
  const m = openModal({ width: 540, pad: 24 });
  const v = k => player && player[k] != null ? esc(player[k]) : '';
  const lg = player ? player.league : (UI.league || 'NHL');
  m.body.innerHTML = `<div class="form"><div style="font-size:20px;font-weight:800">${isEdit ? 'Muokkaa tietoja' : 'Lisää pelaaja'}</div>
    ${isCustom ? `<div class="field">${label('Nimi')}<input class="input" id="f_name" value="${v('name')}"></div>
    <div class="fgrid"><div class="field">${label('Sarja')}<select class="select" id="f_league" style="width:100%">${LEAGUES.map(l => `<option value="${l.id}"${l.id === lg ? ' selected' : ''}>${l.label}</option>`).join('')}</select></div>
    <div class="field">${label('Joukkue')}<input class="input" id="f_team" list="f_teams" value="${v('team')}"><datalist id="f_teams"></datalist></div></div>` : ''}
    <div class="fgrid"><div class="field">${label('Pelipaikka')}<div class="seg" id="f_pos">${[['F', 'Hyökkääjä'], ['D', 'Puolustaja'], ['G', 'Maalivahti']].map(([k, t]) => `<button type="button" data-v="${k}">${t}</button>`).join('')}</div></div>
    <div class="field">${label('Kätisyys')}<div class="seg" id="f_sh">${[['', '–'], ['L', 'V'], ['R', 'O']].map(([k, t]) => `<button type="button" data-v="${k}">${t}</button>`).join('')}</div></div></div>
    <div class="fgrid"><div class="field">${label('Kansallisuus')}<input class="input" id="f_nat" value="${v('nat')}"></div><div class="field">${label('Syntymävuosi')}<input class="input" id="f_born" value="${v('born')}"></div></div>
    <div class="fgrid">${[['games', 'O'], ['goals', 'M'], ['assists', 'S'], ['pim', 'RM'], ['plusMinus', '+/-']].map(([k, t]) => `<div class="field">${label(t)}<input class="input" id="f_${k}" value="${v(k)}"></div>`).join('')}</div>
    <div class="field">${label('Joukkueen logon URL (valinnainen)')}<input class="input" id="f_logo" value="${player ? esc(Store.state.logos[player.team] || '') : ''}"></div>
    <div class="row"><div class="spacer"></div><button class="btn" data-close>Peruuta</button><button class="btn primary" id="f_save">Tallenna</button></div></div>`;
  let pos = (player && player.pos) || 'F', sh = (player && player.shoots) || '';
  const segInit = (sel, get, set) => { const el = $(sel, m.body); const paint = () => el.querySelectorAll('button').forEach(b => b.classList.toggle('on', b.dataset.v === get())); el.onclick = e => { const b = e.target.closest('button'); if (b) { set(b.dataset.v); paint(); } }; paint(); };
  segInit('#f_pos', () => pos, x => pos = x); segInit('#f_sh', () => sh, x => sh = x);
  const fillTeams = () => { const l = $('#f_league', m.body); if (l) $('#f_teams', m.body).innerHTML = Store.teamNames(l.value).map(n => `<option value="${esc(n)}">`).join(''); };
  if (isCustom) { fillTeams(); $('#f_league', m.body).onchange = fillTeams; }
  const g = id => $('#' + id, m.body).value.trim(); const iv = id => toInt(g(id)); const sv = id => g(id) || null;
  const check = () => { $('#f_save', m.body).disabled = isCustom && (!g('f_name') || !g('f_team')); };
  m.body.addEventListener('input', check); check();
  $('#f_save', m.body).onclick = () => {
    const teamName = player ? player.team : g('f_team'); const logo = g('f_logo');
    if (logo || Store.state.logos[teamName]) Store.setLogo(teamName, logo);
    if (player && !player.isCustom) {
      Store.saveEdit(player.id, { games: iv('f_games'), goals: iv('f_goals'), assists: iv('f_assists'), pim: iv('f_pim'), plusMinus: iv('f_plusMinus'), pos, nat: sv('f_nat'), born: iv('f_born'), shoots: sh || null });
    } else {
      const league = g('f_league');
      const np = { id: player ? player.id : Store.newCustomID(), name: g('f_name'), team: teamName, league, flag: (Store.teamByName[teamName] && Store.teamByName[teamName].flag) || leagueFlag(league), pos, nat: sv('f_nat'), born: iv('f_born'), shoots: sh || null, games: iv('f_games'), goals: iv('f_goals'), assists: iv('f_assists'), pim: iv('f_pim'), plusMinus: iv('f_plusMinus'), isCustom: true };
      if (isEdit) Store.updateCustom(np); else Store.addPlayer(np);
    }
    m.close();
  };
}

// ====================== Vertailu ======================
function openCompare() {
  const m = openModal({ width: 720, pad: 24 });
  const render = () => {
    const ps = UI.compare.map(id => Store.player(id)).filter(Boolean);
    const metrics = [['Ottelut', p => p.games, p => num(p.games)], ['Maalit', p => p.goals, p => num(p.goals)], ['Syötöt', p => p.assists, p => num(p.assists)], ['Pisteet', playerPoints, p => num(playerPoints(p))],
      ['Pisteet / ottelu', playerPPG, p => ppgString(playerPPG(p))], ['Rangaistusminuutit', p => p.pim == null ? null : -p.pim, p => num(p.pim)], ['+/-', p => p.plusMinus, p => signed(p.plusMinus)]];
    const cols = `150px repeat(${ps.length},1fr)`;
    m.body.innerHTML = `<div class="mhead"><h2>Pelaajavertailu</h2><div class="spacer"></div><button class="btn" id="cclear">Tyhjennä valinnat</button><button class="btn primary" data-close>Sulje</button></div>
      <div class="cmpgrid" style="grid-template-columns:${cols};text-align:center;margin-bottom:12px"><div></div>${ps.map(p => `<div style="display:flex;flex-direction:column;align-items:center;gap:6px">${logoHTML(p.team, 44)}<div style="font-weight:700;font-size:14px">${esc(p.name)}</div><div class="muted" style="font-size:11px">${esc(p.team)}</div>${starsHTML(Store.rating(p.id), { size: 12, ro: true })}</div>`).join('')}</div>
      <div class="card">${metrics.map(([t, f, tx]) => { const vals = ps.map(f).filter(x => x != null); const best = vals.length ? Math.max(...vals) : null; return `<div class="cmpgrid" style="grid-template-columns:${cols};padding:10px 14px;border-bottom:1px solid var(--hair)"><div class="muted" style="font-size:12px">${t}</div>${ps.map(p => { const x = f(p); const isBest = x != null && x === best && vals.filter(y => y === best).length < ps.length; return `<div class="mono ${isBest ? 'best' : ''}" style="text-align:center;font-size:15px">${tx(p)}</div>`; }).join('')}</div>`; }).join('')}</div>`;
    $('#cclear', m.body).onclick = () => { UI.compare = []; renderToolbar(); renderMain(); m.close(); };
  };
  render();
}

// ====================== Asetukset ======================
function openSettings() {
  const m = openModal({ width: 560, pad: 24 });
  let soundErr = '';
  const render = () => {
    const S = Store.settings;
    m.body.innerHTML = `<div class="form"><div style="font-size:20px;font-weight:800">Asetukset</div>
      ${label('Ilmoitukset')}
      <label class="switch"><input type="checkbox" id="s_notify" ${S.notifyEnabled ? 'checked' : ''}>Ilmoita, kun pelaaja tekee maalin tai syöttää</label>
      <div class="row"><span class="muted">Pelaajat, joilla tähtiä vähintään</span>${[1, 2, 3].map(n => `<button class="btn${S.notifyMinStars === n ? ' active' : ''}" data-stars="${n}">${n}</button>`).join('')}</div>
      <label class="switch"><input type="checkbox" id="s_sound" ${S.notifySound ? 'checked' : ''}>Äänimerkki ilmoituksen yhteydessä</label>
      <div class="row"><span class="muted" style="flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">Ääni: ${esc(Sound.name || 'järjestelmän oletus')}</span><button class="btn" id="s_pick">Valitse äänitiedosto…</button>${Sound.name ? '<button class="btn" id="s_clr">Palauta oletus</button>' : ''}<button class="btn" id="s_test">Testaa</button></div>
      ${soundErr ? `<div class="red" style="font-size:11px">${esc(soundErr)}</div>` : ''}
      <div class="muted" style="font-size:11px">Ilmoitukset tulevat käynnissä olevista peleistä NHL:ssä, AHL:ssä ja Liigassa noin minuutin viiveellä. Jos ilmoitukset eivät näy, salli ne Windowsin Asetukset > Järjestelmä > Ilmoitukset.</div>
      ${label('Sovelluksen kuvake')}
      <div class="row" style="gap:14px">${['A:Tumma', 'B:Vaalea', 'C:Sininen', 'D:Neon'].map(s => { const [k, t] = s.split(':'); return `<button class="icopt${(S.appIcon || 'A') === k ? ' on' : ''}" data-icon="${k}"><img src="../icons/Icon${k}.png" alt="">${t}</button>`; }).join('')}</div>
      ${label('Elite Prospects API -avain (SHL ja HockeyAllsvenskan)')}
      <input class="input" type="password" id="s_key" placeholder="${Store.hasEPKey ? 'Avain tallennettu – liitä uusi korvataksesi' : 'Liitä avain tähän'}">
      <div class="muted" style="font-size:11px">Avain tallennetaan vain tämän sovelluksen omaan tallennustilaan tälle koneelle. Ilmainen taso sallii 1 000 kutsua kuukaudessa, joten SHL/HA haetaan korkeintaan kahden tunnin välein tai Päivitä-napista.</div>
      ${Store.hasEPKey ? `<div style="font-size:11px" class="${Store.epOK ? 'green' : 'amber'}">Tila: ${esc(Store.status.ep)}</div>` : ''}
      <div class="row">${Store.hasEPKey ? '<button class="btn" id="s_delkey">Poista avain</button>' : ''}<div class="spacer"></div><button class="btn" data-close>Sulje</button><button class="btn primary" id="s_save">Tallenna ja hae</button></div></div>`;
    const b = m.body;
    $('#s_notify', b).onchange = async e => { await Store.setSetting('notifyEnabled', e.target.checked); if (e.target.checked && 'Notification' in window) Notification.requestPermission(); };
    b.querySelectorAll('[data-stars]').forEach(x => x.onclick = async () => { await Store.setSetting('notifyMinStars', +x.dataset.stars); render(); });
    $('#s_sound', b).onchange = e => Store.setSetting('notifySound', e.target.checked);
    $('#s_pick', b).onclick = async () => { const r = await Sound.setFromFile(); soundErr = r === false ? 'Äänitiedoston avaaminen epäonnistui. Kokeile toista tiedostoa.' : ''; render(); };
    if ($('#s_clr', b)) $('#s_clr', b).onclick = async () => { await Sound.clear(); render(); };
    $('#s_test', b).onclick = () => Sound.play();
    b.querySelectorAll('[data-icon]').forEach(x => x.onclick = async () => { await native.setIcon(x.dataset.icon); Store.settings.appIcon = x.dataset.icon; render(); });
    if ($('#s_delkey', b)) $('#s_delkey', b).onclick = async () => { await Store.setEPKey(''); render(); };
    $('#s_save', b).onclick = async () => { const k = $('#s_key', b).value; if (k.trim()) await Store.setEPKey(k); m.close(); if (Store.hasEPKey) Store.refreshLive(true); };
  };
  render(); m.refresh = () => { if (!document.activeElement || document.activeElement.id !== 's_key') render(); };
}

// ====================== Sarjataulukko ======================
function openStandings() {
  const m = openModal({ width: 900, pad: 20 });
  let league = 'NHL', byDiv = true, rows = [], loading = true, failed = false, token = 0;
  let view = 'table', side = 'all', nWin = 5, line = 4.5, games = null, gamesFailed = false, gamesLoading = false;
  const L4 = [['NHL', 'NHL'], ['AHL', 'AHL'], ['SM-liiga', 'Liiga'], ['Mestis', 'Mestis']];
  const section = (title, rs) => `<div class="card sm sect" style="margin-bottom:14px">${title ? label(title) : ''}<table class="tbl"><thead><tr><th class="l" style="width:34px">#</th><th class="l">Joukkue</th><th>O</th><th>V</th><th>H</th><th>JH</th><th>P</th><th>Maalit</th><th>Ero</th></tr></thead><tbody>` +
    rs.map((r, i) => { const d = r.gf - r.ga; return `<tr><td class="l muted">${i + 1}</td><td class="l"><span class="row" style="gap:8px">${logoHTML(r.team, 30)}<b style="font-size:13px">${esc(r.team)}</b></span></td><td>${r.gp}</td><td>${r.w}</td><td>${r.l}</td><td>${r.otl}</td><td class="cyan" style="font-weight:700;font-size:13px">${r.pts}</td><td class="muted">${r.gf}–${r.ga}</td><td class="${d > 0 ? 'green' : d < 0 ? 'red' : 'muted'}">${d > 0 ? '+' + d : d}</td></tr>`; }).join('') + '</tbody></table></div>';
  const dm = d => `${d.getDate()}.${d.getMonth() + 1}.`;
  const resTip = x => `${x.home ? 'Koti' : 'Vieras'} · ${x.opp} ${x.gf}–${x.ga}${x.g.extra ? ' ' + x.g.extra : ''} · ${dm(x.g.date)}`;
  const nextTip = s => s.next ? `Seuraava ottelu:\n${s.next.home} · ${s.next.away}\n${s.next.date.getDate()}.${s.next.date.getMonth() + 1}.${s.next.date.getFullYear()}` : 'Ei tulevia otteluita';
  const formBadges = (s, list) => `<span class="fb q" title="${esc(nextTip(s))}">?</span>` + list.map(f => `<span class="fb ${f.win ? 'w' : 'l'}${f.x.g.extra ? ' ot' : ''}" title="${esc(resTip(f.x))}">${f.win ? 'V' : 'H'}</span>`).join('');
  const ouBadges = (s, list) => `<span class="fb q" title="${esc(nextTip(s))}">?</span>` + list.map(f => `<span class="fb ${f.over ? 'w' : 'l'}" title="${esc(resTip(f.x) + ' · maaleja ' + (f.x.gf + f.x.ga))}">${f.over ? '+' : '−'}</span>`).join('');
  const groupsOf = (stats) => {
    const grp = Object.fromEntries(rows.map(r => [r.team, r.group]));
    if ((league === 'NHL' || league === 'AHL') && byDiv && rows.length) {
      const keys = [...new Set(stats.map(s => grp[s.team] || ''))].sort();
      return keys.map(k => { const p = k.split('|'); return [p.length === 2 ? `${p[1]} (${p[0]})` : (k || null), stats.filter(s => (grp[s.team] || '') === k)]; });
    }
    return [[null, stats]];
  };
  const formView = () => {
    const names = Store.teams.filter(t => t.league === league).map(t => t.name);
    const stats = computeTeamForm(games, names, league, side, nWin, line);
    const isForm = view === 'form';
    const head = isForm ? '<th>OTT</th><th>V</th><th>JA-V</th><th>JA-H</th><th>H</th><th>M</th><th>PIS</th><th class="l">Kunto</th>' : '<th>OTT</th><th>O</th><th>U</th><th>M</th><th>M/O</th><th class="l">Viimeiset 5</th>';
    return groupsOf(stats).map(([title, ss]) => {
      ss = ss.slice().sort(isForm ? (a, b) => b.pts - a.pts || (b.gf - b.ga) - (a.gf - a.ga) || b.gf - a.gf : (a, b) => b.over - a.over || (b.tot / (b.allGp || 1)) - (a.tot / (a.allGp || 1)));
      return `<div class="card sm sect" style="margin-bottom:14px">${title ? label(title) : ''}<table class="tbl"><thead><tr><th class="l" style="width:34px">#</th><th class="l">Joukkue</th>${head}</tr></thead><tbody>` +
        ss.map((s, i) => `<tr><td class="l muted">${i + 1}</td><td class="l"><span class="row" style="gap:8px">${logoHTML(s.team, 26)}<b style="font-size:13px">${esc(s.team)}</b></span></td>` + (isForm
          ? `<td>${s.gp}</td><td>${s.w}</td><td>${s.otw}</td><td>${s.otl}</td><td>${s.l}</td><td class="muted">${s.gf}:${s.ga}</td><td class="cyan" style="font-weight:700">${s.pts}</td><td class="l" style="white-space:nowrap">${formBadges(s, s.formN)}</td>`
          : `<td>${s.allGp}</td><td>${s.over}</td><td>${s.under}</td><td class="muted">${s.allGf}:${s.allGa}</td><td class="cyan" style="font-weight:700">${s.allGp ? (s.tot / s.allGp).toFixed(1) : '–'}</td><td class="l" style="white-space:nowrap">${ouBadges(s, s.form)}</td>`) + '</tr>').join('') + '</tbody></table></div>';
    }).join('');
  };
  const render = () => {
    let body;
    const needGames = view !== 'table';
    if (loading && !needGames || (needGames && gamesLoading)) body = '<div class="empty" style="height:300px"><span class="spinner"></span></div>';
    else if (needGames) body = (gamesFailed || !games) ? '<div class="empty" style="height:300px">Otteluiden haku epäonnistui. Tarkista verkkoyhteys ja avaa uudelleen.</div>' : formView();
    else if (failed) body = '<div class="empty" style="height:300px">Sarjataulukon haku epäonnistui. Tarkista verkkoyhteys ja avaa uudelleen.</div>';
    else if ((league === 'NHL' || league === 'AHL') && byDiv) {
      const keys = [...new Set(rows.map(r => r.group))].sort();
      body = keys.map(k => { const p = k.split('|'); return section(p.length === 2 ? `${p[1]} (${p[0]})` : k, sortStandings(rows.filter(r => r.group === k))); }).join('');
    } else body = section(null, sortStandings(rows));
    const seg = (arr, cur, attr) => `<div class="seg">${arr.map(([v, t]) => `<button class="${String(cur) === String(v) ? 'on' : ''}" data-${attr}="${v}">${t}</button>`).join('')}</div>`;
    const subs = view === 'table' ? '' : `<div class="row" style="margin-bottom:12px;gap:12px;flex-wrap:wrap">${seg([['all', 'Yhteensä'], ['home', 'Kotona'], ['away', 'Vieraissa']], side, 'side')}${view === 'form' ? seg([[5, '5'], [10, '10']], nWin, 'n') : seg([0.5, 1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5].map(v => [v, v]), line, 'line')}</div>`;
    const note = view === 'table' ? (loading || failed ? '' : `O = ottelut, V = voitot, H = tappiot, JH = jatkoaika-/rankkaritappiot, P = pisteet.${league === 'SM-liiga' ? '<br>Liigan taulukko on laskettu ottelutuloksista (voitto 3 p, jatkoaikavoitto 2 p, jatkoaikatappio 1 p).' : ''}`)
      : view === 'form' ? `OTT = ottelut, JA-V/JA-H = jatkoaika- tai rankkarivoitot/-tappiot, M = maalit, PIS = pisteet valitulta ajalta. Merkit vanhimmasta uusimpaan; ? = seuraava ottelu (vie hiiri päälle). Oranssi kulma = ratkesi jatkoajalla/rankkareilla.${league === 'Mestis' ? ' Mestiksestä ei saa jatkoaikatietoa.' : ''}`
      : `O = yli ${line} maalia (ottelun kaikki maalit), U = alle, M = maalit tehty:päästetty, M/O = maaleja per ottelu. Koko kausi, merkit = viimeiset 5 ottelua.`;
    m.body.innerHTML = `<div class="mhead"><h2>Sarjataulukko</h2><div class="spacer"></div>${closeBtn()}</div>
      <div class="row" style="margin-bottom:14px">${L4.map(([id, t]) => `<button class="btn${league === id ? ' active' : ''}" data-lg="${id}">${t}</button>`).join('')}<div class="spacer"></div>${(league === 'NHL' || league === 'AHL') ? `<button class="btn${byDiv ? ' active' : ''}" data-div="1">Divisioonat</button><button class="btn${!byDiv ? ' active' : ''}" data-div="0">Koko sarja</button>` : ''}</div>
      <div class="row" style="margin-bottom:12px"><button class="btn${view === 'table' ? ' active' : ''}" data-view="table">Sarjataulukko</button><button class="btn${view === 'form' ? ' active' : ''}" data-view="form">Kunto</button><button class="btn${view === 'ou' ? ' active' : ''}" data-view="ou">Yli/Alle</button></div>${subs}
      <div style="max-height:calc(94vh - 250px);overflow:auto">${body}<div class="muted" style="font-size:11px">${note}</div></div>`;
    m.body.querySelectorAll('[data-lg]').forEach(b => b.onclick = () => { league = b.dataset.lg; load(); });
    m.body.querySelectorAll('[data-div]').forEach(b => b.onclick = () => { byDiv = b.dataset.div === '1'; render(); });
    m.body.querySelectorAll('[data-view]').forEach(b => b.onclick = () => { view = b.dataset.view; if (view !== 'table') loadGames(); render(); });
    m.body.querySelectorAll('[data-side]').forEach(b => b.onclick = () => { side = b.dataset.side; render(); });
    m.body.querySelectorAll('[data-n]').forEach(b => b.onclick = () => { nWin = +b.dataset.n; render(); });
    m.body.querySelectorAll('[data-line]').forEach(b => b.onclick = () => { line = +b.dataset.line; render(); });
  };
  const loadGames = async () => {
    if (games || gamesLoading) return;
    const t = token, lg = league; gamesLoading = true; gamesFailed = false; render();
    const g = await fetchLeagueGames(lg, Store.teams);
    if (!m.alive) return; if (t !== token || lg !== league) return;
    games = g; gamesFailed = !g; gamesLoading = false; render();
  };
  const load = async () => {
    const t = ++token; loading = true; failed = false; rows = []; games = null; gamesLoading = false; render();
    if (view !== 'table') loadGames();
    let r;
    if (league === 'NHL') r = await fetchNHLStandings(Store.teams); else if (league === 'Mestis') r = await fetchMestisStandings(Store.teams);
    else if (league === 'AHL') r = await fetchAHLStandings(Store.teams, await fetchAHLSeasonId()); else r = await fetchLiigaStandings(Store.teams);
    if (t !== token || !m.alive) return; if (r) rows = r; else failed = true; loading = false; render();
  };
  load();
}

// ====================== Otteluohjelma ======================
function openSchedule() {
  const m = openModal({ width: 640, pad: 20 });
  let league = 'NHL', games = [], loading = true, failed = false, token = 0;
  const L4 = [['NHL', 'NHL'], ['AHL', 'AHL'], ['SM-liiga', 'Liiga'], ['Mestis', 'Mestis']];
  const upcoming = () => {
    const now = Date.now(), to = now + 14 * 86400000;
    return games.filter(g => ((g.final && g.date >= now - 48 * 3600000) || g.date >= now - 3 * 3600000) && g.date <= to).sort((a, b) => a.date - b.date);
  };
  const render = () => {
    let body;
    if (loading) body = '<div class="empty" style="height:300px"><span class="spinner"></span></div>';
    else if (failed) body = '<div class="empty" style="height:300px">Otteluohjelman haku epäonnistui. Tarkista verkkoyhteys ja avaa uudelleen.</div>';
    else {
      const up = upcoming(); const days = new Map();
      for (const g of up) { const d = new Date(g.date); const k = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime(); if (!days.has(k)) days.set(k, []); days.get(k).push(g); }
      if (!days.size) body = '<div class="empty" style="height:300px">Ei tulevia otteluita seuraavan 14 päivän aikana.</div>';
      else body = [...days.entries()].sort((a, b) => a[0] - b[0]).map(([k, gs]) => `<div class="card sm sect" style="margin-bottom:14px">${label(fmtDay(new Date(k)))}${gs.map(g => {
        const click = g.gameId != null || g.liiga;
        return `<div class="gamerow${click ? ' click' : ''}"${click ? ` data-g="${esc(g.id)}"` : ''}><span class="mono" style="width:74px;font-size:12px;font-weight:600;color:${g.live ? 'var(--green)' : 'var(--muted)'}">${g.final ? 'Päättynyt' : g.live ? 'Käynnissä' : fmtTime(g.date)}</span>
          <span class="tn" style="text-align:right">${esc(g.away)}</span>${logoHTML(g.away, 30)}<span class="sc ${(g.final || g.live) && g.awayScore != null ? '' : 'muted'}">${(g.final || g.live) && g.awayScore != null && g.homeScore != null ? `${g.awayScore} – ${g.homeScore}` : '–'}</span>${logoHTML(g.home, 30)}<span class="tn">${esc(g.home)}</span></div>`; }).join('')}</div>`).join('');
    }
    m.body.innerHTML = `<div class="mhead"><h2>Otteluohjelma</h2><div class="spacer"></div>${closeBtn()}</div>
      <div class="row" style="margin-bottom:14px">${L4.map(([id, t]) => `<button class="btn${league === id ? ' active' : ''}" data-lg="${id}">${t}</button>`).join('')}<div class="spacer"></div><span class="muted" style="font-size:11px">Vieras – Koti · ajat omassa aikavyöhykkeessäsi</span></div>
      <div id="sbody" style="max-height:calc(94vh - 160px);overflow:auto">${body}</div>`;
    m.body.querySelectorAll('[data-lg]').forEach(b => b.onclick = () => { league = b.dataset.lg; load(); });
    m.body.querySelectorAll('[data-g]').forEach(r => r.onclick = () => { const g = games.find(x => x.id === r.dataset.g); if (g) openGame(g); });
  };
  const fetchGames = () => league === 'NHL' ? fetchNHLSchedule(Store.teams) : league === 'Mestis' ? fetchMestisSchedule(Store.teams) : league === 'AHL' ? fetchAHLSchedule(Store.teams) : fetchLiigaSchedule(Store.teams);
  const load = async (silent = false) => {
    const t = ++token;
    if (!silent) { loading = true; failed = false; games = []; render(); }
    const r = await fetchGames(); if (t !== token || !m.alive) return;
    if (r) games = r; else if (!silent) failed = true;
    if (!silent) loading = false;
    const sc = $('#sbody', m.body); const top = sc ? sc.scrollTop : 0; render(); const sc2 = $('#sbody', m.body); if (sc2) sc2.scrollTop = top;
  };
  (async () => {
    await load();
    while (m.alive) {
      await sleep(20000); if (!m.alive) break;
      const now = Date.now();
      if (games.some(g => g.live || (!g.final && g.date < now + 600000 && g.date > now - 4 * 3600000))) await load(true);
    }
  })();
}

// ====================== Ottelu ======================
function openGame(g0) {
  const m = openModal({ width: 660, pad: 20 });
  let game = g0, box = null, loading = true, failed = false;
  const periodTitle = p => p >= 1 && p <= 3 ? `${p}. erä` : p === 4 ? 'Jatkoaika' : p > 4 ? 'Rankkarit' : 'Maalit';
  const clock = s => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
  const status = () => game.final ? 'Päättynyt' : game.live ? 'Käynnissä' : `${fmtDay(new Date(game.date))} klo ${fmtTime(game.date)}`;
  const headTeam = (name, score) => `<div class="row" style="flex:1;justify-content:center;gap:10px">${logoHTML(name, 40)}<b style="font-size:15px">${esc(name)}</b>${score != null ? `<b class="cyan mono" style="font-size:22px">${score}</b>` : ''}</div>`;
  const group = (title, ps, goalie) => !ps || !ps.length ? '' : `<div class="muted" style="display:flex;gap:6px;font-size:10px;font-weight:600;padding:5px 12px"><span style="width:28px;text-align:right">#</span><span style="flex:1;padding-left:4px">${title}</span>${goalie ? '<span style="width:70px;text-align:right">Torjunnat</span>' : '<span style="width:28px;text-align:right">M</span><span style="width:28px;text-align:right">S</span><span style="width:28px;text-align:right">P</span><span style="width:34px;text-align:right">+/-</span><span style="width:28px;text-align:right">L</span>'}<span style="width:48px;text-align:right">Aika</span></div>` +
    ps.map((p, i) => `<div class="mono" style="display:flex;gap:6px;font-size:12px;padding:4px 12px;${i % 2 ? 'background:rgba(255,255,255,.025)' : ''}"><span class="muted" style="width:28px;text-align:right">${p.sweaterNumber ?? '–'}</span><span style="flex:1;padding-left:4px;font-size:13px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${esc((p.name && p.name.default) || '?')} ${p.position ? `<span class="muted" style="font-size:10px;font-weight:400">${esc(p.position)}</span>` : ''}</span>` +
      (goalie ? `<span style="width:70px;text-align:right">${esc(p.saveShotsAgainst || '–')}</span>` : `<span style="width:28px;text-align:right">${num(p.goals)}</span><span style="width:28px;text-align:right">${num(p.assists)}</span><span class="${(p.points || 0) > 0 ? 'cyan' : 'muted'}" style="width:28px;text-align:right">${num(p.points)}</span><span style="width:34px;text-align:right">${signed(p.plusMinus)}</span><span style="width:28px;text-align:right">${num(p.sog)}</span>`) + `<span class="muted" style="width:48px;text-align:right">${esc(p.toi || '–')}</span></div>`).join('');
  const teamCard = (team, s) => `<div class="card sm sect" style="margin-bottom:14px">${label(team)}${group('Hyökkääjät', s.forwards, false)}${group('Puolustajat', s.defense, false)}${group('Maalivahdit', s.goalies, true)}</div>`;
  const render = () => {
    let body = '';
    const d = game.liiga;
    if (loading) body = '<div class="empty" style="height:260px"><span class="spinner"></span></div>';
    else if (failed) body = '<div class="empty" style="height:260px">Ottelun tietojen haku epäonnistui.</div>';
    else if (d) {
      body = `<div class="muted" style="font-size:12px;display:flex;flex-direction:column;gap:4px;margin-bottom:14px">${d.rink ? `<span>${esc(d.rink)}</span>` : ''}${d.spectators != null ? `<span>Katsojia: ${d.spectators}</span>` : ''}${d.awayPP && d.homePP ? `<span>Ylivoimamaalit / ylivoimat: ${esc(game.away)} ${d.awayPP} · ${esc(game.home)} ${d.homePP}</span>` : ''}${d.resultNote ? `<span class="amber" style="font-weight:600">${esc(d.resultNote)}</span>` : ''}</div>
        <div class="card sm sect" style="margin-bottom:14px">${label('Maalit')}${d.goals.length ? '' : '<div class="muted" style="padding:8px 12px">Ei maaleja.</div>'}${d.goals.map((x, i) => `${i === 0 || d.goals[i - 1].period !== x.period ? `<div class="muted" style="font-size:10px;font-weight:600;padding:8px 12px 2px">${periodTitle(x.period)}</div>` : ''}<div class="gamerow" style="background:none"><span class="muted mono" style="width:44px;font-size:12px">${clock(x.seconds)}</span>${logoHTML(x.home ? game.home : game.away, 24)}<div style="flex:1"><div style="font-weight:600">${esc(x.scorer)}</div>${x.assists.length ? `<div class="muted" style="font-size:11px">${esc(x.assists.join(', '))}</div>` : ''}</div>${x.powerPlay ? '<b class="amber" style="font-size:10px">YV</b>' : ''}${x.homeScore != null && x.awayScore != null ? `<span class="sc" style="text-align:right">${x.awayScore} – ${x.homeScore}</span>` : ''}</div>`).join('')}</div>
        <div class="muted" style="font-size:11px">Liigan rajapinta ei kerro kokoonpanoja tai kentällisiä.</div>`;
    } else if (box && box.playerByGameStats && box.playerByGameStats.awayTeam && box.playerByGameStats.homeTeam && !(isEmptyTeam(box.playerByGameStats.awayTeam) && isEmptyTeam(box.playerByGameStats.homeTeam))) {
      body = teamCard(game.away, box.playerByGameStats.awayTeam) + teamCard(game.home, box.playerByGameStats.homeTeam);
    } else body = '<div class="empty" style="height:260px;text-align:center;padding:0 30px"><div style="color:var(--text)">Kokoonpanoja ei ole vielä julkaistu.</div><div style="font-size:12px">NHL:n rajapinta antaa pelaajalistan vasta, kun ottelu on alkanut. Kentällisiä (ketjuja) se ei kerro lainkaan.</div></div>';
    m.body.innerHTML = `<div class="mhead"><h2>Ottelu</h2><div class="spacer"></div>${closeBtn()}</div>
      <div class="row" style="gap:14px">${headTeam(game.away, box && box.awayTeam && box.awayTeam.score != null ? box.awayTeam.score : game.awayScore)}<span class="muted">–</span>${headTeam(game.home, box && box.homeTeam && box.homeTeam.score != null ? box.homeTeam.score : game.homeScore)}</div>
      <div class="muted" style="font-size:12px;text-align:center;margin:8px 0 14px">${status()}</div><div style="max-height:calc(94vh - 220px);overflow:auto">${body}</div>`;
  };
  const isEmptyTeam = t => !(t.forwards || []).length && !(t.defense || []).length && !(t.goalies || []).length;
  const load = async silent => {
    if (!silent) { loading = true; failed = false; }
    if (game.gameId == null) { failed = true; loading = false; render(); return; }
    const b = await fetchBoxscore(game.gameId); if (!m.alive) return;
    if (b) box = b; else if (!silent) failed = true; loading = false; render();
  };
  render();
  (async () => {
    if (!game.liiga) await load(false); else { loading = false; render(); }
    while (m.alive && (game.live || (!game.final && game.date.getTime() - Date.now() < 600000))) {
      await sleep(20000); if (!m.alive) break;
      if (game.liiga || game.id.startsWith('liiga')) { const list = await fetchLiigaSchedule(Store.teams); const n = list && list.find(x => x.id === game.id); if (n && m.alive) { game = n; render(); } }
      else if (game.gameId != null) await load(true);
    }
  })();
}

// ====================== Joukkueen tulokset ======================
function openTeamResults(teamName) {
  const m = openModal({ width: 560, pad: 22 });
  const head = `<div class="mhead">${logoHTML(teamName, 44)}<div><h2>${esc(teamName)}</h2><div class="muted" style="font-size:12px">5 viimeisintä ottelua</div></div><div class="spacer"></div>${closeBtn()}</div>`;
  m.body.innerHTML = head + '<div class="muted"><span class="spinner"></span> Haetaan…</div>';
  fetchTeamResults(teamName, Store.teams).then(r => {
    if (!m.alive) return;
    if (!r) { m.body.innerHTML = head + '<div class="muted">Tulosten haku epäonnistui. Tarkista verkkoyhteys ja avaa uudelleen.</div>'; return; }
    const form = r.games.slice().reverse().map(g => `<span class="${g.win ? 'green' : 'red'}" style="font-weight:800">${g.win ? 'V' : 'H'}</span>`).join(' ');
    const w = r.games.filter(g => g.win).length, gf = r.games.reduce((s, g) => s + g.gf, 0), ga = r.games.reduce((s, g) => s + g.ga, 0);
    let h = head;
    if (r.games.length) {
      h += `<div class="row" style="margin-bottom:12px"><span class="label">Muoto</span>${form}<div class="spacer"></div>${chip(`${w} V – ${r.games.length - w} H`)}${chip(`maalit ${gf}–${ga}`)}</div>
        <div class="card sm sect">${r.games.map(g => `<div class="gamerow${g.game ? ' click' : ''}"${g.game ? ` data-gi="${r.games.indexOf(g)}"` : ''}><span class="mono muted" style="width:52px;white-space:nowrap;font-size:12px">${g.date.getDate()}.${g.date.getMonth() + 1}.</span><span class="muted" style="width:56px;font-size:12px">${g.home ? 'Koti' : 'Vieras'}</span>${logoHTML(g.opponent, 26)}<span class="tn">${esc(g.opponent)}</span>
          <span class="mono" style="font-weight:700;width:70px;text-align:center">${g.gf} – ${g.ga}${g.extra ? ` <span class="muted" style="font-size:10px;font-weight:600">${g.extra}</span>` : ''}</span><span class="${g.win ? 'green' : 'red'}" style="width:20px;text-align:center;font-weight:800">${g.win ? 'V' : 'H'}</span></div>`).join('')}</div>`;
    } else h += '<div class="muted">Ei pelattuja otteluita tällä kaudella.</div>';
    if (r.note) h += `<div class="muted" style="font-size:11px;margin-top:8px">${esc(r.note)}</div>`;
    h += '<div class="muted" style="font-size:11px;margin-top:4px">Tulos näytetään joukkueen näkökulmasta (oma maalimäärä ensin). JA = jatkoaika, RL = rankkarit.</div>';
    m.body.innerHTML = h;
    m.body.querySelectorAll('[data-gi]').forEach(el => el.onclick = () => openGame(r.games[+el.dataset.gi].game));
  });
}
