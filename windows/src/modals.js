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
    t.innerHTML = `<div class="row" style="gap:14px">${logoHTML(p.team, 56)}<div><div style="font-size:22px;font-weight:800">${esc(p.name)}</div><div class="muted" style="font-size:13px;margin-top:4px">${esc(p.flag)} <a href="#" data-teamres="${esc(p.team)}" style="color:inherit;text-decoration:underline dotted">${esc(p.team)}</a> · ${esc(leagueLabel(p.league))}</div></div><div class="spacer"></div>${closeBtn()}</div>
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
        r.games.map(x => { const pts = x.goals + x.assists; return `<tr style="${pts > 0 ? 'background:rgba(70,201,245,.07)' : ''}"><td class="l muted">${shortDate(x.date)}</td><td class="l muted">${x.home === true ? 'Koti' : x.home === false ? 'Vieras' : '–'}</td><td class="l" style="font-weight:500">${esc(x.opponent)}</td>${sh ? `<td class="muted">${num(x.shots)}</td>` : ''}<td>${x.goals}</td><td>${x.assists}</td><td class="${pts > 0 ? 'cyan' : 'muted'}" style="font-weight:700">${pts}</td>${pp ? `<td class="${(x.pp || 0) > 0 ? 'amber' : 'muted'}">${num(x.pp)}</td>` : ''}</tr>`; }).join('') + '</tbody></table></div>';
    }
    if (r.note) h += `<div class="muted" style="font-size:12px;margin-top:6px">${esc(r.note)}</div>`;
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
    const isG = UI.compare.length && UI.compare[0].startsWith('g-');
    const gs = isG ? UI.compare.map(id => (Store.state.goalies || []).find(g => g.id === id)).filter(Boolean) : [];
    const ps = isG ? gs : UI.compare.map(id => Store.player(id)).filter(Boolean);
    const fmt = (v, d) => v == null ? '–' : v.toFixed(d).replace('.', ',');
    const metrics = isG ? [['Ottelut', g => g.games, g => num(g.games)], ['Voitot', g => g.wins, g => num(g.wins)], ['Torjunta-%', goaliePct, g => fmt(goaliePct(g), 1)],
      ['Päästetyt / ottelu', g => { const v = goalieGAA(g); return v == null ? null : -v; }, g => fmt(goalieGAA(g), 2)], ['Nollapelit', g => g.shutouts, g => num(g.shutouts)],
      ['Torjunnat', g => g.saves, g => num(g.saves)], ['Laukaukset', g => g.shotsAgainst, g => num(g.shotsAgainst)]] : [['Ottelut', p => p.games, p => num(p.games)], ['Maalit', p => p.goals, p => num(p.goals)], ['Syötöt', p => p.assists, p => num(p.assists)], ['Pisteet', playerPoints, p => num(playerPoints(p))],
      ['Pisteet / ottelu', playerPPG, p => ppgString(playerPPG(p))], ['Rangaistusminuutit', p => p.pim == null ? null : -p.pim, p => num(p.pim)], ['+/-', p => p.plusMinus, p => signed(p.plusMinus)]];
    const cols = `150px repeat(${ps.length},1fr)`;
    m.body.innerHTML = `<div class="mhead"><h2>${isG ? 'Maalivahtivertailu' : 'Pelaajavertailu'}</h2><div class="spacer"></div><button class="btn" id="cclear">Tyhjennä valinnat</button><button class="btn primary" data-close>Sulje</button></div>
      <div class="cmpgrid" style="grid-template-columns:${cols};text-align:center;margin-bottom:12px"><div></div>${ps.map(p => `<div style="display:flex;flex-direction:column;align-items:center;gap:6px">${logoHTML(p.team, 44)}<div style="font-weight:700;font-size:14px">${esc(p.name)}</div><div class="muted" style="font-size:12px">${esc(p.team)}</div>${starsHTML(Store.rating(p.id), { size: 12, ro: true })}</div>`).join('')}</div>
      <div class="card">${metrics.map(([t, f, tx]) => { const vals = ps.map(f).filter(x => x != null); const best = vals.length ? Math.max(...vals) : null; return `<div class="cmpgrid" style="grid-template-columns:${cols};padding:10px 14px;border-bottom:1px solid var(--hair)"><div class="muted" style="font-size:13px">${t}</div>${ps.map(p => { const x = f(p); const isBest = x != null && x === best && vals.filter(y => y === best).length < ps.length; return `<div class="mono ${isBest ? 'best' : ''}" style="text-align:center;font-size:15px">${tx(p)}</div>`; }).join('')}</div>`; }).join('')}</div>`;
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
      <div class="row"><span class="muted" style="flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">Ääni: ${esc(Sound.name || 'notifica_diretta.mp3 (oletus)')}</span><button class="btn" id="s_pick">Valitse äänitiedosto…</button>${Sound.name ? '<button class="btn" id="s_clr">Palauta oletus</button>' : ''}<button class="btn" id="s_test">Testaa</button></div>
      ${soundErr ? `<div class="red" style="font-size:12px">${esc(soundErr)}</div>` : ''}
      <div class="muted" style="font-size:12px">Ilmoitukset tulevat käynnissä olevista peleistä NHL:ssä, AHL:ssä ja Liigassa noin minuutin viiveellä. Jos ilmoitukset eivät näy, salli ne Windowsin Asetukset > Järjestelmä > Ilmoitukset.</div>
      ${label('Fontti')}
      <div class="row" style="gap:8px;flex-wrap:wrap">${FONTS.map(f => `<button class="btn${(S.font || 'Inter') === f[0] ? ' active' : ''}" data-font="${esc(f[0])}" style="font-family:${f[2]},sans-serif">${esc(f[1])}</button>`).join('')}</div>
      ${label('Sovelluksen kuvake')}
      <div class="row" style="gap:14px">${['A:Tumma', 'B:Vaalea', 'C:Sininen', 'D:Neon'].map(s => { const [k, t] = s.split(':'); return `<button class="icopt${(S.appIcon || 'A') === k ? ' on' : ''}" data-icon="${k}"><img src="../icons/Icon${k}.png" alt="">${t}</button>`; }).join('')}</div>
      ${label('Elite Prospects API -avain (SHL ja HockeyAllsvenskan)')}
      <input class="input" type="password" id="s_key" placeholder="${Store.hasEPKey ? 'Avain tallennettu – liitä uusi korvataksesi' : 'Liitä avain tähän'}">
      <div class="muted" style="font-size:12px">Avain tallennetaan vain tämän sovelluksen omaan tallennustilaan tälle koneelle. Ilmainen taso sallii 1 000 kutsua kuukaudessa, joten SHL/HA haetaan korkeintaan kahden tunnin välein tai Päivitä-napista.</div>
      ${Store.hasEPKey ? `<div style="font-size:12px" class="${Store.epOK ? 'green' : 'amber'}">Tila: ${esc(Store.status.ep)}</div>` : ''}
      ${label('Odds API -avain (vedonlyöntikertoimet)')}
      <div class="row"><input class="input" type="password" id="s_okey" style="flex:1" placeholder="${Store.state.oddsKey ? 'Avain tallennettu – liitä uusi korvataksesi' : 'Liitä avain tähän'}"><button class="btn" id="s_osave">Tallenna</button>${Store.state.oddsKey ? '<button class="btn" id="s_odel">Poista</button>' : ''}</div>
      <div class="muted" style="font-size:12px">Kertoimia haetaan vain, kun avaat ottelun Vihjeet-välilehden. Pelaajakohtaiset kertoimet (NHL) maksavat noin 4 kyselyä per ottelu, ja vastaukset säilytetään 30 minuuttia.</div>
      <div class="row">${Store.hasEPKey ? '<button class="btn" id="s_delkey">Poista avain</button>' : ''}<div class="spacer"></div><button class="btn" data-close>Sulje</button><button class="btn primary" id="s_save">Tallenna ja hae</button></div></div>`;
    const b = m.body;
    $('#s_notify', b).onchange = async e => { await Store.setSetting('notifyEnabled', e.target.checked); if (e.target.checked && 'Notification' in window) Notification.requestPermission(); };
    b.querySelectorAll('[data-stars]').forEach(x => x.onclick = async () => { await Store.setSetting('notifyMinStars', +x.dataset.stars); render(); });
    $('#s_sound', b).onchange = e => Store.setSetting('notifySound', e.target.checked);
    $('#s_pick', b).onclick = async () => { const r = await Sound.setFromFile(); soundErr = r === false ? 'Äänitiedoston avaaminen epäonnistui. Kokeile toista tiedostoa.' : ''; render(); };
    if ($('#s_clr', b)) $('#s_clr', b).onclick = async () => { await Sound.clear(); render(); };
    $('#s_test', b).onclick = () => Sound.play();
    b.querySelectorAll('[data-font]').forEach(x => x.onclick = async () => { await Store.setSetting('font', x.dataset.font); applyFont(x.dataset.font); render(); });
    b.querySelectorAll('[data-icon]').forEach(x => x.onclick = async () => { await native.setIcon(x.dataset.icon); Store.settings.appIcon = x.dataset.icon; render(); });
    if ($('#s_osave', b)) $('#s_osave', b).onclick = () => { const k = $('#s_okey', b).value.trim(); if (k) { Store.state.oddsKey = k; Store.persist(); Store.flash('Odds API -avain tallennettu'); render(); } };
    if ($('#s_odel', b)) $('#s_odel', b).onclick = () => { delete Store.state.oddsKey; Store.persist(); render(); };
    if ($('#s_delkey', b)) $('#s_delkey', b).onclick = async () => { await Store.setEPKey(''); render(); };
    $('#s_save', b).onclick = async () => { const k = $('#s_key', b).value; if (k.trim()) await Store.setEPKey(k); m.close(); if (Store.hasEPKey) Store.refreshLive(true); };
  };
  render(); m.refresh = () => { if (!document.activeElement || document.activeElement.id !== 's_key') render(); };
}

// ====================== Sarjataulukko ======================
function openStandings() {
  const m = openModal({ width: 1120, pad: 20 });
  let league = 'NHL', byDiv = true, rows = [], loading = true, failed = false, token = 0;
  let view = 'table', side = 'all', nWin = 5, line = 4.5, games = null, gamesFailed = false, gamesLoading = false;
  const L4 = [['NHL', 'NHL'], ['AHL', 'AHL'], ['SM-liiga', 'Liiga'], ['Mestis', 'Mestis'], ['SHL', 'SHL'], ['HockeyAllsvenskan', 'HockeyAllsvenskan'], ['National League', 'NL']];
  const tableForm = team => {
    if (!games || gamesLoading) return '<span class="muted">…</span>';
    const s = computeTeamForm(games, [team], league, 'all', 5, 4.5)[0]; if (!s) return '';
    return formBadges(s, s.formN);
  };
  const section = (title, rs) => `<div class="card sm sect" style="margin-bottom:14px">${title ? label(title) : ''}<table class="tbl fx"><thead><tr><th class="l" style="width:34px">#</th><th class="l">Joukkue</th><th>O</th><th>V</th><th>H</th><th>JH</th><th>P</th><th>Maalit</th><th>Ero</th><th class="l">Kunto</th></tr></thead><tbody>` +
    rs.map((r, i) => { const d = r.gf - r.ga; return `<tr data-team="${esc(r.team)}"><td class="l muted">${i + 1}</td><td class="l"><span class="row" style="gap:8px">${logoHTML(r.team, 30)}<b style="font-size:13px">${esc(r.team)}</b></span></td><td>${r.gp}</td><td>${r.w}</td><td>${r.l}</td><td>${r.otl}</td><td class="cyan" style="font-weight:700;font-size:13px">${r.pts}</td><td class="muted">${r.gf}–${r.ga}</td><td class="${d > 0 ? 'green' : d < 0 ? 'red' : 'muted'}">${d > 0 ? '+' + d : d}</td><td class="l" style="white-space:nowrap">${tableForm(r.team)}</td></tr>`; }).join('') + '</tbody></table></div>';
  const p2 = n => String(n).padStart(2, '0'); const dm = d => `${p2(d.getDate())}.${p2(d.getMonth() + 1)}.${d.getFullYear()}`;
  const resTip = x => `${x.home ? 'Koti' : 'Vieras'} · ${x.opp} ${x.gf}–${x.ga}${x.g.extra ? ' ' + x.g.extra : ''} · ${dm(x.g.date)}`;
  const nextTip = s => s.next ? `Seuraava ottelu:\n${s.next.home} · ${s.next.away}\n${dm(s.next.date)}` : 'Ei tulevia otteluita';
  const nextH = s => s.next ? esc(s.next.home + '|' + s.next.away) : '';
  const formBadges = (s, list) => `<span class="fb q" data-h="${nextH(s)}" title="${esc(nextTip(s))}">?</span>` + list.map(f => `<span class="fb ${f.win ? 'w' : 'l'}${f.x.g.extra ? ' ot' : ''}" data-h="${esc(f.x.g.home + '|' + f.x.g.away)}" title="${esc(resTip(f.x))}">${f.win ? 'V' : 'H'}</span>`).join('');
  const ouBadges = (s, list) => `<span class="fb q" data-h="${nextH(s)}" title="${esc(nextTip(s))}">?</span>` + list.map(f => `<span class="fb ${f.over ? 'w' : 'l'}" data-h="${esc(f.x.g.home + '|' + f.x.g.away)}" title="${esc(resTip(f.x) + ' · maaleja ' + (f.x.gf + f.x.ga))}">${f.over ? '+' : '−'}</span>`).join('');
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
      return `<div class="card sm sect" style="margin-bottom:14px">${title ? label(title) : ''}<table class="tbl fx"><thead><tr><th class="l" style="width:34px">#</th><th class="l">Joukkue</th>${head}</tr></thead><tbody>` +
        ss.map((s, i) => `<tr data-team="${esc(s.team)}"><td class="l muted">${i + 1}</td><td class="l"><span class="row" style="gap:8px">${logoHTML(s.team, 26)}<b style="font-size:13px">${esc(s.team)}</b></span></td>` + (isForm
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
    const note = view === 'table' ? (loading || failed ? '' : `O = ottelut, V = voitot, H = tappiot, JH = jatkoaika-/rankkaritappiot, P = pisteet. Kunto = viimeiset 5 ottelua, ? = seuraava ottelu (vie hiiri päälle, niin joukkueet korostuvat).${league === 'SHL' || league === 'HockeyAllsvenskan' ? '<br>Taulukko on laskettu ottelutuloksista (voitto 3 p, jatkoaikavoitto 2 p, jatkoaikatappio 1 p). Lähde: swehockey.se.' : ''}${league === 'SM-liiga' ? '<br>Liigan taulukko on laskettu ottelutuloksista (voitto 3 p, jatkoaikavoitto 2 p, jatkoaikatappio 1 p).' : ''}`)
      : view === 'form' ? `OTT = ottelut, JA-V/JA-H = jatkoaika- tai rankkarivoitot/-tappiot, M = maalit, PIS = pisteet valitulta ajalta. Merkit uusimmasta vanhimpaan; ? = seuraava ottelu (vie hiiri päälle). Oranssi kulma = ratkesi jatkoajalla/rankkareilla.${league === 'Mestis' ? ' Mestiksestä ei saa jatkoaikatietoa.' : ''}`
      : `O = yli ${line} maalia (ottelun kaikki maalit), U = alle, M = maalit tehty:päästetty, M/O = maaleja per ottelu. Koko kausi, merkit = viimeiset 5 ottelua.`;
    m.body.innerHTML = `<div class="mhead"><h2>Sarjataulukko</h2><div class="spacer"></div>${closeBtn()}</div>
      <div class="row" style="margin-bottom:14px">${L4.map(([id, t]) => `<button class="btn${league === id ? ' active' : ''}" data-lg="${id}">${t}</button>`).join('')}<div class="spacer"></div>${(league === 'NHL' || league === 'AHL') ? `<button class="btn${byDiv ? ' active' : ''}" data-div="1">Divisioonat</button><button class="btn${!byDiv ? ' active' : ''}" data-div="0">Koko sarja</button>` : ''}</div>
      <div class="row" style="margin-bottom:12px"><button class="btn${view === 'table' ? ' active' : ''}" data-view="table">Sarjataulukko</button><button class="btn${view === 'form' ? ' active' : ''}" data-view="form">Kunto</button><button class="btn${view === 'ou' ? ' active' : ''}" data-view="ou">Yli/Alle</button></div>${subs}
      <div style="max-height:calc(94vh - 250px);overflow:auto">${body}<div class="muted" style="font-size:12px">${note}</div></div>`;
    m.body.querySelectorAll('[data-lg]').forEach(b => b.onclick = () => { league = b.dataset.lg; load(); });
    m.body.querySelectorAll('.fb[data-h]').forEach(b => {
      const set = on => { const [h, a] = (b.dataset.h || '').split('|'); if (!h) return; m.body.querySelectorAll('tr[data-team]').forEach(tr => tr.classList.toggle('hl', on && (tr.dataset.team === h || tr.dataset.team === a))); };
      b.onmouseenter = () => set(true); b.onmouseleave = () => set(false);
    });
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
    loadGames();
    let r;
    if (league === 'NHL') r = await fetchNHLStandings(Store.teams); else if (league === 'Mestis') r = await fetchMestisStandings(Store.teams);
    else if (league === 'AHL') r = await fetchAHLStandings(Store.teams, await fetchAHLSeasonId()); else if (league === 'SHL' || league === 'HockeyAllsvenskan') r = await fetchSweStandings(league, Store.teams); else if (league === 'National League') r = await fetchNLStandings(Store.teams); else r = await fetchLiigaStandings(Store.teams);
    if (t !== token || !m.alive) return; if (r) rows = r; else failed = true; loading = false; render();
  };
  load();
}

// ====================== Otteluohjelma ======================
function openSchedule() {
  const m = openModal({ width: 640, pad: 20 });
  const L4 = [['NHL', 'NHL'], ['AHL', 'AHL'], ['SM-liiga', 'Liiga'], ['Mestis', 'Mestis'], ['SHL', 'SHL'], ['HockeyAllsvenskan', 'HockeyAllsvenskan'], ['National League', 'NL']];
  let league = L4.some(x => x[0] === UI.league) ? UI.league : 'NHL', games = [], loading = true, failed = false, token = 0;
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
        const click = g.gameId != null || g.liiga || !g.final;
        return `<div class="gamerow${click ? ' click' : ''}"${click ? ` data-g="${esc(g.id)}"` : ''}><span class="mono" style="width:74px;font-size:13px;font-weight:${g.final ? 500 : 700};color:${g.live ? 'var(--green)' : g.final ? '#64748B' : 'var(--amber)'}">${g.final ? 'Päättynyt' : g.live ? 'Käynnissä' : fmtTime(g.date)}</span>
          <span class="tn" style="text-align:right">${esc(g.home)}</span>${logoHTML(g.home, 30)}<span class="sc muted">${(g.final || g.live) && g.awayScore != null && g.homeScore != null ? scorePill(g.homeScore, g.awayScore, 'md') : '–'}</span>${logoHTML(g.away, 30)}<span class="tn">${esc(g.away)}</span></div>`; }).join('')}</div>`).join('');
    }
    m.body.innerHTML = `<div class="mhead"><h2>Otteluohjelma</h2><div class="spacer"></div>${closeBtn()}</div>
      <div class="row" style="margin-bottom:14px">${L4.map(([id, t]) => `<button class="btn${league === id ? ' active' : ''}" data-lg="${id}">${t}</button>`).join('')}</div>
      <div id="sbody" style="max-height:calc(94vh - 160px);overflow:auto">${body}</div>`;
    m.body.querySelectorAll('[data-lg]').forEach(b => b.onclick = () => { league = b.dataset.lg; load(); });
    m.body.querySelectorAll('[data-g]').forEach(r => r.onclick = () => { const g = games.find(x => x.id === r.dataset.g); if (g) openGame(g); });
  };
  const fetchGames = () => league === 'NHL' ? fetchNHLSchedule(Store.teams) : league === 'Mestis' ? fetchMestisSchedule(Store.teams) : league === 'AHL' ? fetchAHLSchedule(Store.teams) : (league === 'SHL' || league === 'HockeyAllsvenskan') ? fetchSweSchedule(league, Store.teams) : league === 'National League' ? fetchNLSchedule(Store.teams) : fetchLiigaSchedule(Store.teams);
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
  const m = openModal({ width: 720, pad: 20 });
  let game = g0, box = null, loading = true, failed = false, tab = 0, NX = null;
  const isL = game.id.startsWith('liiga-');
  const isN = game.gameId != null;
  const nhlStarted = () => isN && (game.final || game.live);
  const LU = { loaded: false, loading: false, failed: false, data: null, line: 1, sel: null };
  const shirt = (p, color, x, y) => `<div ${p ? `data-pl="${p.team}:${p.id}"` : ''} style="position:absolute;left:${x}px;top:${y}px;width:100px;margin:-30px 0 0 -50px;text-align:center;${p ? 'cursor:pointer' : ''}">
    <div style="position:relative;width:46px;height:40px;margin:0 auto"><svg viewBox="0 0 24 22" width="46" height="40" style="opacity:${p ? .92 : .25}${p && (p.goals.length || p.assists.length) ? `;filter:drop-shadow(0 0 7px ${p.goals.length ? '#fbbf24' : '#34d399'})` : ''}"><path fill="${color}"${p && (p.goals.length || p.assists.length) ? ` stroke="${p.goals.length ? '#fbbf24' : '#34d399'}" stroke-width="1.2"` : ''} d="M8 1 L1 5 L3 10 L6 9 L6 21 L18 21 L18 9 L21 10 L23 5 L16 1 C15 3 9 3 8 1 Z"/></svg>
      <div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;padding-top:6px;font-weight:800;font-size:13px;color:rgba(0,0,0,.85)">${p && p.jersey != null ? p.jersey : '–'}</div>
            ${p && (p.captain || p.alt) ? `<div style="position:absolute;right:-4px;top:-2px;width:16px;height:16px;border-radius:50%;background:#fbbf24;color:#000;font-size:10px;font-weight:800;line-height:16px">${p.captain ? 'C' : 'A'}</div>` : ''}</div>
    <div style="display:inline-block;margin-top:2px;max-width:96px;overflow:hidden;white-space:nowrap;text-overflow:ellipsis;font-size:11px;font-weight:600;padding:1px 6px;border-radius:9px;background:rgba(0,0,0,.35)">${p ? esc((p.jersey != null ? p.jersey + ' ' : '') + p.name) : '–'}</div>
    <div style="height:18px;margin-top:3px">${p && (p.goals.length || p.assists.length) ? `<span style="display:inline-block;padding:1px 9px;border-radius:9px;font-size:11px;font-weight:800;color:#000;background:${p.goals.length && p.assists.length ? 'linear-gradient(90deg,#fbbf24 50%,#34d399 50%)' : p.goals.length ? '#fbbf24' : '#34d399'}">${p.goals.length} + ${p.assists.length}</span>` : ''}</div></div>`;
  const lineupHTML = () => {
    const tabs = `<div class="row" style="justify-content:center;margin-bottom:10px"><div class="seg">${[1, 2, 3, 4].map(n => `<button data-line="${n}" class="${LU.line === n ? 'on' : ''}">Ketju ${n}</button>`).join('')}</div></div>`;
    if (LU.loading || !LU.loaded) return tabs + '<div class="empty" style="height:240px"><span class="spinner"></span></div>';
    if (LU.failed) return '<div class="empty" style="height:240px">Kokoonpanon haku epäonnistui.</div>';
    const D = LU.data; const pub = [...D.home, ...D.away].some(p => p.line != null);
    if (!pub) return '<div class="empty" style="height:240px;text-align:center;padding:0 30px"><div style="color:var(--text)">Kokoonpanoa ei ole vielä julkaistu.</div><div style="font-size:13px">Joukkueet ilmoittavat kokoonpanonsa ennen ottelua. Näkymä päivittyy, kun avaat ikkunan uudelleen.</div></div>';
    const W = 640, H = 300, n = LU.line, dl = Math.min(n, 3);
    const slot = (l, role, ln) => l.find(p => p.role === role && p.line === ln) || null;
    const gk = l => l.filter(p => p.role === 'MV' && p.line != null).sort((a, b) => a.line - b.line)[0] || null;
    const A = D.away, Hm = D.home, ci = '#6366f1', cc = '#46c9f5';
    const st = 'rgba(255,255,255,.16)';
    const rink = `<div style="position:relative;box-sizing:border-box;width:${W}px;height:${H}px;margin:0 auto;border:2px solid ${st};border-radius:70px;background:rgba(255,255,255,.03)">
      <div style="position:absolute;left:${W / 2 - 1}px;top:0;width:2px;height:100%;background:${st}"></div><div style="position:absolute;left:${W * .32}px;top:0;width:2px;height:100%;background:${st}"></div><div style="position:absolute;left:${W * .68}px;top:0;width:2px;height:100%;background:${st}"></div>
      <div style="position:absolute;left:${W / 2 - 35}px;top:${H / 2 - 35}px;width:66px;height:66px;border:2px solid ${st};border-radius:50%"></div>
      ${[[.2, .3], [.2, .7], [.8, .3], [.8, .7]].map(([fx, fy]) => `<div style="position:absolute;left:${W * fx - 30}px;top:${H * fy - 30}px;width:56px;height:56px;border:2px solid ${st};border-radius:50%"></div>`).join('')}
      ${shirt(gk(A), ci, 62, H / 2)}${shirt(slot(A, 'VP', dl), ci, 160, 95)}${shirt(slot(A, 'OP', dl), ci, 160, 205)}${shirt(slot(A, 'VL', n), ci, 265, 55)}${shirt(slot(A, 'KH', n), ci, 265, H / 2)}${shirt(slot(A, 'OL', n), ci, 265, 245)}
      ${shirt(gk(Hm), cc, W - 62, H / 2)}${shirt(slot(Hm, 'VP', dl), cc, W - 160, 205)}${shirt(slot(Hm, 'OP', dl), cc, W - 160, 95)}${shirt(slot(Hm, 'VL', n), cc, W - 265, 245)}${shirt(slot(Hm, 'KH', n), cc, W - 265, H / 2)}${shirt(slot(Hm, 'OL', n), cc, W - 265, 55)}</div>`;
    const ex = l => { const e = l.filter(p => /\. [HP]$/.test(p.role) && p.line != null).map(p => p.name); const b = l.filter(p => p.role === 'MV' && (p.line || 0) >= 2).map(p => 'MV ' + p.name); return b.concat(e).join(', ') || '–'; };
    const per = p => p >= 1 && p <= 3 ? p + '. erä' : p === 4 ? 'Jatkoaika' : p > 4 ? 'Rankkarit' : '';
    const card = () => {
      const p = [...A, ...Hm].find(x => x.team + ':' + x.id === LU.sel); if (!p) return null;
      const facts = [p.height > 0 ? p.height + ' cm' : '', p.weight > 0 ? p.weight + ' kg' : '', p.hand === 'LEFT' ? 'Vasenkätinen' : p.hand === 'RIGHT' ? 'Oikeakätinen' : ''].filter(Boolean).join(' · ');
      let born = ''; if (p.born && p.born.length >= 10) { const [y, mo, d] = p.born.slice(0, 10).split('-'); born = `${+d}.${+mo}.${y}`; }
      if (p.birthplace) born += (born ? ', ' : '') + p.birthplace;
      return `<div class="card" style="margin-top:10px;padding:12px"><div class="row" style="justify-content:space-between"><div><b>${p.jersey != null ? p.jersey + ' ' : ''}${esc(p.first)} ${esc(p.name)}</b> <span class="muted" style="font-size:12px">${esc(p.team === 'home' ? game.home : game.away)}</span></div><button class="btn ghost" data-plclose>Sulje</button></div>
        ${facts ? `<div class="muted" style="font-size:12px;margin-top:4px">${facts}</div>` : ''}${born ? `<div class="muted" style="font-size:12px">Syntynyt ${esc(born)}</div>` : ''}
        ${!p.goals.length && !p.assists.length ? '<div class="muted" style="font-size:12px;margin-top:6px">Ei maaleja tai syöttöjä tässä ottelussa.</div>' : ''}
        ${p.goals.map(g => `<div style="font-size:12px;font-weight:600;margin-top:4px">Maali ${g.time} (${per(g.period)}, ${g.score})</div>`).join('')}${p.assists.map(g => `<div style="font-size:12px;margin-top:4px;color:#10b981">Syöttö ${g.time} (${per(g.period)}, ${g.score})</div>`).join('')}</div>`;
    };
    return tabs + rink + `<div class="row" style="justify-content:space-between;margin-top:8px;font-size:12px;font-weight:600"><span style="color:${ci}">● ${esc(game.away)}</span><span style="color:${cc}">● ${esc(game.home)}</span></div>
      ${card() || `<div class="muted" style="font-size:11px;margin-top:10px"><div style="font-weight:700">Varamaalivahti ja lisäpelaajat</div><div>${esc(game.away)}: ${esc(ex(A))}</div><div>${esc(game.home)}: ${esc(ex(Hm))}</div>${D.note ? `<div style="margin-top:6px">${esc(D.note)}</div>` : ''}</div>`}`;
  };
  const bindLineup = () => {
    m.body.querySelectorAll('[data-line]').forEach(b => b.onclick = () => { LU.line = +b.dataset.line; render(); });
    m.body.querySelectorAll('[data-pl]').forEach(b => b.onclick = () => { LU.sel = LU.sel === b.dataset.pl ? null : b.dataset.pl; render(); });
    m.body.querySelectorAll('[data-plclose]').forEach(b => b.onclick = () => { LU.sel = null; render(); });
  };
  const startLineup = async () => {
    if (LU.loaded || LU.loading) return; LU.loading = true; render();
    if (isN) { const dat = await fetchNHLLineup(game.gameId); if (!m.alive) return; if (dat) LU.data = dat; else LU.failed = true; LU.loading = false; LU.loaded = true; render(); return; }
    const id = game.id.replace('liiga-', ''); const j = await getJSON(`https://liiga.fi/api/v2/games/2027/${id}`, 20000); if (!m.alive) return;
    const ev = [...((j && j.game && j.game.homeTeam && j.game.homeTeam.goalEvents) || []), ...((j && j.game && j.game.awayTeam && j.game.awayTeam.goalEvents) || [])];
    const clk = t => `${Math.floor(t / 60)}:${String(t % 60).padStart(2, '0')}`;
    const conv = (l, team) => (l || []).map((p, i) => {
      const pid = p.id ?? i, goals = [], assists = [];
      if (p.id != null) ev.forEach(e => { const n = { time: clk(e.gameTime || 0), period: e.period || 0, score: `${e.homeTeamScore ?? 0}–${e.awayTeamScore ?? 0}` }; if (e.scorerPlayerId === p.id) goals.push(n); if ((e.assistantPlayerIds || []).includes(p.id)) assists.push(n); });
      return { id: pid, team, name: p.lastName || '?', first: p.firstName || '', jersey: p.jersey ?? null, role: p.roleCode || '', line: p.line ?? null, captain: !!p.captain, alt: !!p.alternateCaptain, born: p.dateOfBirth || null, birthplace: p.placeOfBirth || '', height: p.height || 0, weight: p.weight || 0, hand: p.handedness || '', goals, assists };
    });
    if (j && (j.homeTeamPlayers || j.awayTeamPlayers)) LU.data = { home: conv(j.homeTeamPlayers, 'home'), away: conv(j.awayTeamPlayers, 'away') }; else LU.failed = true;
    LU.loading = false; LU.loaded = true; if (m.alive) render();
  };
  // ----- Ottelun esittely (alkamaton ottelu) -----
  const PV = { loaded: false, loading: false, failed: false, games: [], table: [], special: {}, odds: null, ev: null };
  const pvLeague = () => (Store.teamByName[game.home] || {}).league;
  const pvLast = (team, n) => PV.games.filter(g => g.final && (g.home === team || g.away === team)).sort((a, b) => b.date - a.date).slice(0, n).map(g => { const h = g.home === team; return { g, home: h, gf: h ? g.hs : g.as, ga: h ? g.as : g.hs, opp: h ? g.away : g.home }; });
  const pvDay = d => `${d.getDate()}.${d.getMonth() + 1}.`;
  const pvCol = r => r.gf > r.ga ? '#34d399' : r.g.extra ? '#fbbf24' : '#f87171';
  const pvForm = team => {
    const rows = pvLast(team, 5); const i = PV.table.findIndex(r => r.team === team);
    const st = i >= 0 ? ` <span class="muted" style="font-size:11px;font-weight:400">${i + 1}. sija · ${PV.table[i].pts} p</span>` : '';
    if (!rows.length) return `<div style="flex:1"><b style="font-size:15px">${esc(team)}</b>${st}<div class="muted" style="font-size:12px;margin-top:6px">Ei pelattuja otteluita.</div></div>`;
    const w = rows.filter(r => r.gf > r.ga).length, gf = rows.reduce((s, r) => s + r.gf, 0), ga = rows.reduce((s, r) => s + r.ga, 0);
    return `<div style="flex:1;min-width:0"><b style="font-size:15px">${esc(team)}</b>${st}
      <div style="display:flex;gap:4px;margin:8px 0 6px">${rows.map(r => `<span style="width:22px;height:22px;border-radius:50%;background:${pvCol(r)};color:#000;font-size:11px;font-weight:800;line-height:22px;text-align:center">${r.gf > r.ga ? 'V' : r.g.extra ? 'T' : 'H'}</span>`).join('')}</div>
      <div class="muted" style="font-size:12px;margin-bottom:6px">${w} V · ${rows.length - w} H · maalit ${gf}–${ga}</div>
      ${rows.slice(0, 3).map(r => `<div style="display:flex;justify-content:space-between;font-size:12px;padding:2px 0"><span class="muted">${pvDay(r.g.date)} ${esc(r.opp)} (${r.home ? 'k' : 'v'})</span><b style="color:${pvCol(r)}">${r.gf}–${r.ga}${r.g.extra ? ' ' + r.g.extra : ''}</b></div>`).join('')}</div>`;
  };
  const pvTop = team => {
    const lg = pvLeague();
    const ps = Store.players.filter(p => p.team === team && p.league === lg).sort((a, b) => ((b.goals || 0) + (b.assists || 0)) - ((a.goals || 0) + (a.assists || 0)) || (b.goals || 0) - (a.goals || 0)).slice(0, 3);
    return `<div style="flex:1;min-width:0">${ps.length ? ps.map((p, i) => `<div style="display:flex;gap:6px;align-items:center;font-size:13px;padding:3px 0"><span class="muted" style="width:12px;font-size:11px">${i + 1}</span><b style="overflow:hidden;white-space:nowrap;text-overflow:ellipsis">${esc(p.name)}</b>${Store.isHot(p) ? '<span>' + FLAME + '</span>' : ''}${Store.rating(p.id) === 3 ? '<span class="amber">★</span>' : ''}<span style="margin-left:auto;white-space:nowrap"><b>${(p.goals || 0) + (p.assists || 0)}</b> p <span class="muted" style="font-size:11px">(${p.goals || 0}+${p.assists || 0})</span></span></div>`).join('') : '<div class="muted" style="font-size:12px">Ei pelaajatietoja.</div>'}</div>`;
  };
  const pvPct = v => v == null ? '–' : Math.round(v) + ' %';
  const pvBar = (title, a, h) => { const av = Math.max(a || 0, .1), hv = Math.max(h || 0, .1); return `<div style="margin-bottom:8px"><div style="display:flex;justify-content:space-between;font-size:12px;font-weight:600"><span>${title} ${esc(game.away)} ${pvPct(a)}</span><span>${esc(game.home)} ${pvPct(h)}</span></div><div style="display:flex;height:6px;border-radius:3px;overflow:hidden;margin-top:4px"><div style="width:${av / (av + hv) * 100}%;background:#6366f1"></div><div style="flex:1;background:#46c9f5"></div></div></div>`; };
  const pvGoalie = team => { const gs = (Store.state.goalies || []).filter(g => g.team === team).sort((a, b) => b.games - a.games); const g = gs[0];
    return `<div style="display:flex;justify-content:space-between;font-size:12px;padding:2px 0">${g ? `<b style="overflow:hidden;white-space:nowrap;text-overflow:ellipsis">${esc(g.name)}</b><span class="muted mono" style="white-space:nowrap">${goaliePct(g) != null ? goaliePct(g).toFixed(1) + ' %' : '–'} · ${goalieGAA(g) != null ? goalieGAA(g).toFixed(2) : '–'}</span>` : `<span class="muted">${esc(team)}: ei tietoa</span>`}</div>`; };
  const pvBest = name => { const o = PV.odds && PV.odds[name]; return o && o.length ? o.reduce((a, b) => b.price > a.price ? b : a) : null; };
  const pvOdds = (label, name, cls) => { const o = pvBest(name); return `<div style="display:flex;justify-content:space-between;font-size:12px;padding:2px 0"><span>${esc(label)}</span>${o ? `<span><b class="${cls} mono" style="font-size:13px">${o.price.toFixed(2)}</b> <span class="muted" style="font-size:10px">${esc(o.book)}</span></span>` : '<span class="muted">–</span>'}</div>`; };
  const previewHTML = () => {
    if (PV.loading || !PV.loaded) return '<div class="empty" style="height:260px"><span class="spinner"></span></div>';
    if (PV.failed && !PV.games.length) return '<div class="empty" style="height:260px">Tietojen haku epäonnistui. Tarkista verkkoyhteys ja avaa ikkuna uudelleen.</div>';
    const cd = (t, c) => `<div class="card sm" style="padding:14px;margin-bottom:12px"><div class="muted" style="font-size:11px;font-weight:700;letter-spacing:.06em;text-transform:uppercase;margin-bottom:8px">${t}</div>${c}</div>`;
    const h2 = PV.games.filter(g => g.final && ((g.home === game.home && g.away === game.away) || (g.home === game.away && g.away === game.home))).sort((a, b) => b.date - a.date);
    const hw = h2.filter(g => (g.home === game.home && g.hs > g.as) || (g.away === game.home && g.as > g.hs)).length;
    let out = cd('Kunto · viimeiset 5 ottelua', `<div style="display:flex;gap:16px">${pvForm(game.away)}${pvForm(game.home)}</div><div class="muted" style="font-size:10px;margin-top:6px">V = voitto, H = tappio, T = tappio jatkoajalla tai rankkareilla. (k) = kotipeli, (v) = vieraspeli.</div>`);
    out += cd('Kovimmat pelaajat', `<div style="display:flex;gap:16px">${pvTop(game.away)}${pvTop(game.home)}</div><div class="muted" style="font-size:10px;margin-top:6px">${FLAME} = piste jokaisessa neljässä viime pelissä · ★ = suosikkisi</div>`);
    out += cd('Keskinäiset ottelut (kausi)', h2.length ? h2.slice(0, 4).map(g => `<div style="display:flex;justify-content:space-between;font-size:12px;padding:2px 0"><span class="muted">${pvDay(g.date)} ${esc(g.home)} – ${esc(g.away)}</span><b>${g.hs}–${g.as}${g.extra ? ' ' + g.extra : ''}</b></div>`).join('') + `<div class="muted" style="font-size:12px;margin-top:6px">${esc(game.home)} ${hw} voittoa · ${esc(game.away)} ${h2.length - hw} voittoa</div>` : '<div class="muted" style="font-size:12px">Joukkueet eivät ole vielä kohdanneet tällä kaudella.</div>');
    const sa = PV.special[game.away], sh = PV.special[game.home];
    if (sa || sh) out += cd('Erikoistilanteet', pvBar('Ylivoima', sa && sa.pp, sh && sh.pp) + pvBar('Alivoima', sa && sa.pk, sh && sh.pk));
    const hasG = (Store.state.goalies || []).some(g => g.team === game.home || g.team === game.away);
    if (PV.odds || hasG) {
      const oddsCol = PV.odds && PV.ev ? `${pvOdds(game.away, PV.ev.away_team, 'ind')}${pvBest('Draw') ? pvOdds('Tasapeli', 'Draw', '') : ''}${pvOdds(game.home, PV.ev.home_team, 'cyan')}` : `<div class="muted" style="font-size:12px">${Store.state.oddsKey ? 'Ei kertoimia tälle ottelulle.' : 'Lisää Odds API -avain asetuksissa.'}</div>`;
      out += cd('Kertoimet ja maalivahdit', `<div style="display:flex;gap:16px"><div style="flex:1;min-width:0"><div class="muted" style="font-size:12px;font-weight:600;margin-bottom:4px">Voittajakertoimet</div>${oddsCol}</div><div style="flex:1;min-width:0"><div class="muted" style="font-size:12px;font-weight:600;margin-bottom:4px">Maalivahdit (eniten pelannut)</div>${pvGoalie(game.away)}${pvGoalie(game.home)}</div></div>`);
    }
    return out;
  };
  const startPreview = async () => {
    if (PV.loaded || PV.loading) return; PV.loading = true; render();
    const lg = pvLeague(); if (!lg) { PV.loading = false; PV.loaded = true; PV.failed = true; if (m.alive) render(); return; }
    const tbl = lg === 'NHL' ? fetchNHLStandings(Store.teams) : lg === 'Mestis' ? fetchMestisStandings(Store.teams) : lg === 'AHL' ? fetchAHLSeasonId().then(s => fetchAHLStandings(Store.teams, s)) : (lg === 'SHL' || lg === 'HockeyAllsvenskan') ? fetchSweStandings(lg, Store.teams) : lg === 'National League' ? fetchNLStandings(Store.teams) : fetchLiigaStandings(Store.teams);
    const [gl, tb] = await Promise.all([fetchLeagueGames(lg, Store.teams), tbl.catch(() => null)]); if (!m.alive) return;
    PV.failed = !gl; PV.games = gl || []; PV.table = sortStandings(tb || []);
    if (lg === 'SM-liiga') {
      const all = await fetchLiigaGames(); if (!m.alive) return;
      if (all) {
        const key = Object.fromEntries(Store.teams.filter(t => t.league === 'SM-liiga').map(t => [liigaKey(t.name), t.name])); const ppG = {}, ppI = {}, pkG = {}, pkI = {};
        const add = (o, k, v) => { o[k] = (o[k] || 0) + v; };
        for (const g of all) { if (!flexBool(g.ended) || !g.homeTeam || !g.awayTeam) continue; const h = key[liigaKey(g.homeTeam.teamName || '')], a = key[liigaKey(g.awayTeam.teamName || '')]; if (!h || !a) continue;
          const hi = +g.homeTeam.powerplayInstances || 0, hg = +g.homeTeam.powerplayGoals || 0, ai = +g.awayTeam.powerplayInstances || 0, ag = +g.awayTeam.powerplayGoals || 0;
          add(ppI, h, hi); add(ppG, h, hg); add(pkI, h, ai); add(pkG, h, ag); add(ppI, a, ai); add(ppG, a, ag); add(pkI, a, hi); add(pkG, a, hg); }
        for (const t of new Set([...Object.keys(ppI), ...Object.keys(pkI)])) PV.special[t] = { pp: ppI[t] > 0 ? (ppG[t] || 0) / ppI[t] * 100 : null, pk: pkI[t] > 0 ? (1 - (pkG[t] || 0) / pkI[t]) * 100 : null };
      }
    }
    PV.loading = false; PV.loaded = true; render();
    if (Store.state.oddsKey) { const ev = await Odds.findEvent(game, lg); if (ev && m.alive) { const o = await Odds.h2h(lg, ev.id); if (o && m.alive) { PV.odds = o; PV.ev = ev; render(); } } }
  };
  const T = { size: 2, favOnly: true, kinds: { Piste: true, 'Syöttö': true, Maali: true, Ylivoimapiste: true, '2+ pistettä': true, '2+ syöttöä': true, '2+ maalia': true }, started: false, loading: true, tips: [], sel: [], manual: {}, h2h: '', note: '' };
  const periodTitle = p => p >= 1 && p <= 3 ? `${p}. erä` : p === 4 ? 'Jatkoaika' : p > 4 ? 'Rankkarit' : 'Maalit';
  const clock = s => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
  const status = () => game.final ? ('Päättynyt' + (NX && NX.outcome ? ' · ' + NX.outcome : '')) : game.live ? 'Käynnissä' : `${fmtDay(new Date(game.date))} klo ${fmtTime(game.date)}`;
  const headTeam = (name, score) => `<div class="row" style="flex:1;justify-content:center;gap:10px">${logoHTML(name, 40)}<b style="font-size:15px">${esc(name)}</b>${score != null ? `<b class="cyan mono" style="font-size:22px">${score}</b>` : ''}</div>`;
  const group = (title, ps, goalie) => !ps || !ps.length ? '' : `<div class="muted" style="display:flex;gap:6px;font-size:11px;font-weight:600;padding:5px 12px"><span style="width:28px;text-align:right">#</span><span style="flex:1;padding-left:4px">${title}</span>${goalie ? '<span style="width:70px;text-align:right">Torjunnat</span>' : '<span style="width:28px;text-align:right">M</span><span style="width:28px;text-align:right">S</span><span style="width:28px;text-align:right">P</span><span style="width:34px;text-align:right">+/-</span><span style="width:28px;text-align:right">L</span>'}<span style="width:48px;text-align:right">Aika</span></div>` +
    ps.map((p, i) => `<div class="mono" style="display:flex;gap:6px;font-size:13px;padding:4px 12px;${i % 2 ? 'background:rgba(255,255,255,.025)' : ''}"><span class="muted" style="width:28px;text-align:right">${p.sweaterNumber ?? '–'}</span><span style="flex:1;padding-left:4px;font-size:13px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${esc((p.name && p.name.default) || '?')} ${p.position ? `<span class="muted" style="font-size:11px;font-weight:400">${esc(p.position)}</span>` : ''}</span>` +
      (goalie ? `<span style="width:70px;text-align:right">${esc(p.saveShotsAgainst || '–')}</span>` : `<span style="width:28px;text-align:right">${num(p.goals)}</span><span style="width:28px;text-align:right">${num(p.assists)}</span><span class="${(p.points || 0) > 0 ? 'cyan' : 'muted'}" style="width:28px;text-align:right">${num(p.points)}</span><span style="width:34px;text-align:right">${signed(p.plusMinus)}</span><span style="width:28px;text-align:right">${num(p.sog)}</span>`) + `<span class="muted" style="width:48px;text-align:right">${esc(p.toi || '–')}</span></div>`).join('');
  const teamCard = (team, s) => `<div class="card sm sect" style="margin-bottom:14px">${label(team)}${group('Hyökkääjät', s.forwards, false)}${group('Puolustajat', s.defense, false)}${group('Maalivahdit', s.goalies, true)}</div>`;

  const tgCls = t => ({ YV: 'amber', AV: 'red', TM: 'green', VM: 'cyan' }[t] || 'cyan');
  const tagPill = t => `<span class="tg ${tgCls(t)} ${tgCls(t)}-t" style="color:var(--${tgCls(t)})">${t}</span>`;
  const goalsHTML = d => `<div class="card sm sect" style="margin-bottom:14px">${label('Maalit')}${d.goals.length ? '' : '<div class="muted" style="padding:8px 12px">Ei maaleja.</div>'}${d.goals.map((x, i) => {
    const tags = x.tags && x.tags.length ? x.tags : (x.powerPlay ? ['YV'] : []);
    return `${i === 0 || d.goals[i - 1].period !== x.period ? `<div style="font-size:12px;font-weight:700;padding:10px 12px 2px">${periodTitle(x.period)}</div>` : ''}<div class="tlrow"><span class="tdot${x.home ? ' f' : ''}"></span><span class="muted mono" style="width:44px;font-size:13px">${clock(x.seconds - (x.period - 1) * 1200)}</span>${logoHTML(x.home ? game.home : game.away, 34)}<div style="flex:1;min-width:0"><div style="font-weight:600;font-size:13px">${esc(x.scorer)}${tags.map(tagPill).join('')}</div>${x.assists.length ? `<div class="muted" style="font-size:12px">${esc(x.assists.join(', '))}</div>` : ''}</div>${x.video ? `<button class="vb" data-vid="${esc(x.video)}" title="Katso maalin video">▶</button>` : '<span style="width:24px;flex:none"></span>'}${x.homeScore != null && x.awayScore != null ? `<span class="sp tc"><span class="${x.home ? 'h' : ''}">${x.homeScore}</span><span class="${x.home ? '' : 'a'}">${x.awayScore}</span></span>` : ''}</div>`; }).join('')}</div>`;
  const periodCardHTML = ex => {
    if (!ex || !ex.periods.length) return '';
    const P = ex.periods, sum = f => P.filter(p => p.label !== 'RL').reduce((s, p) => s + (f(p) || 0), 0);
    const cell = (v, b) => `<span class="mono" style="width:40px;text-align:right;${b ? 'color:var(--amber);font-weight:800' : ''}">${v == null ? '–' : v}</span>`;
    const row = (team, home, goals) => `<div class="row" style="padding:3px 12px;gap:0">${logoHTML(team, 30)}<b style="margin-left:8px;font-size:13px;flex:1">${esc(team)}</b>${P.map(p => cell(goals ? (home ? p.hg : p.ag) : (home ? p.hsh : p.ash))).join('')}${cell(goals ? (ex.totalGoals ? (home ? ex.totalGoals[0] : ex.totalGoals[1]) : sum(p => home ? p.hg : p.ag)) : sum(p => home ? p.hsh : p.ash), true)}</div>`;
    const hasSh = P.some(p => p.hsh != null || p.ash != null);
    return `<div class="card sm sect" style="margin-bottom:14px">${label('Erätilanne')}<div class="row muted" style="padding:2px 12px;font-size:10px;font-weight:600;gap:0"><span style="flex:1"></span>${P.map(p => `<span style="width:40px;text-align:right">${p.label}</span>`).join('')}<span style="width:40px;text-align:right">Yht</span></div>${row(game.home, true, true)}${row(game.away, false, true)}${hasSh ? `<div class="muted" style="font-size:10px;font-weight:600;padding:6px 12px 0">Laukaukset</div>${row(game.home, true, false)}${row(game.away, false, false)}` : ''}</div>`;
  };
  const statsCardHTML = ex => !ex || !ex.stats.length ? '' : `<div class="card sm" style="margin-bottom:14px;padding:14px 16px 18px">${label('Tilastovertailu')}${ex.stats.map(l => { const tot = l.hv + l.av, hp = tot > 0 ? l.hv / tot * 100 : 50; const on = 'var(--amber)', off = 'rgba(255,255,255,.14)';
    return `<div style="margin-top:14px"><div style="display:flex;justify-content:space-between;align-items:baseline;font-size:13px;font-weight:700"><span class="mono" style="color:${l.hv > l.av ? on : 'var(--text)'}">${esc(l.home)}</span><span class="muted" style="font-size:12px;font-weight:400">${l.label}</span><span class="mono" style="color:${l.av > l.hv ? on : 'var(--text)'}">${esc(l.away)}</span></div><div style="display:flex;gap:4px;height:6px;margin-top:6px"><i style="flex:${hp};border-radius:9px;background:${l.hv >= l.av ? on : off}"></i><i style="flex:${100 - hp};border-radius:9px;background:${l.av >= l.hv ? on : off}"></i></div></div>`; }).join('')}</div>`;
  const penaltiesHTML = ex => !ex || !ex.penalties.length ? '' : `<div class="card sm sect" style="margin-bottom:14px">${label('Jäähyt')}${ex.penalties.map((p, i) => `${i === 0 || ex.penalties[i - 1].period !== p.period ? `<div class="muted" style="font-size:11px;font-weight:600;padding:8px 12px 2px">${periodTitle(p.period)}</div>` : ''}<div class="gamerow" style="background:none;gap:10px"><span class="muted mono" style="width:44px;font-size:13px">${clock(p.seconds)}</span>${logoHTML(p.home ? game.home : game.away, 34)}<div style="flex:1"><div style="font-weight:600">${esc(p.player)}</div><div class="muted" style="font-size:12px">${esc(p.reason)}</div></div><b class="mono ${p.minutes >= 5 ? 'red' : 'amber'}" style="font-size:12px">${p.minutes} min</b></div>`).join('')}</div>`;
  const shootoutHTML = ex => !ex || !ex.shootout.length ? '' : `<div class="card sm sect" style="margin-bottom:14px">${label('Rankkarit')}${ex.shootout.map((s, i) => `<div class="gamerow" style="background:none;gap:10px"><span class="muted mono" style="width:28px;font-size:12px">${i + 1}.</span>${logoHTML(s.home ? game.home : game.away, 34)}<b style="flex:1;font-size:13px">${esc(s.name)}</b><span style="font-size:12px;font-weight:600;color:${s.scored ? 'var(--green)' : 'var(--muted)'}">${s.scored ? 'maali' : 'torjuttu'}</span></div>`).join('')}</div>`;
  const goalieLines = () => {
    const out = [], s = box && box.playerByGameStats; if (!s) return out;
    for (const [home, ts] of [[true, s.homeTeam], [false, s.awayTeam]]) for (const g of (ts && ts.goalies) || []) {
      if ((g.toi || '00:00') === '00:00' || !g.saveShotsAgainst) continue;
      const pt = String(g.saveShotsAgainst).split('/').map(Number); const pct = pt.length === 2 && pt[1] > 0 ? ' · ' + (pt[0] / pt[1] * 100).toFixed(1).replace('.', ',') + ' %' : '';
      out.push({ home, name: (g.name && g.name.default) || '?', line: g.saveShotsAgainst + pct });
    }
    return out;
  };
  const starsCardHTML = ex => {
    const st = (ex && ex.stars) || [], gl = goalieLines(); if (!st.length && !gl.length) return '';
    const tm = h => h ? game.home : game.away;
    return `<div class="card sm sect" style="margin-bottom:14px">${st.length ? label('Ottelun tähdet') + st.map(s => `<div class="gamerow" style="background:none;gap:10px"><span class="amber" style="width:44px;font-size:11px">${'★'.repeat(Math.max(1, 4 - s.star))}</span>${s.home != null ? logoHTML(tm(s.home), 34) : ''}<b style="flex:1;font-size:13px">${esc(s.name)}</b><span class="muted mono" style="font-size:12px">${esc(s.detail)}</span></div>`).join('') : ''}${gl.length ? label('Maalivahdit') + gl.map(g => `<div class="gamerow" style="background:none;gap:10px">${logoHTML(tm(g.home), 34)}<b style="flex:1;font-size:13px">${esc(g.name)}</b><span class="muted mono" style="font-size:12px">${esc(g.line)}</span></div>`).join('') : ''}</div>`;
  };
  const playersHTML = () => {
    const s = box && box.playerByGameStats;
    if (loading) return '<div class="empty" style="height:260px"><span class="spinner"></span></div>';
    if (s && s.awayTeam && s.homeTeam && !(isEmptyTeam(s.awayTeam) && isEmptyTeam(s.homeTeam))) return teamCard(game.home, s.homeTeam) + teamCard(game.away, s.awayTeam);
    return '<div class="empty" style="height:260px;text-align:center;padding:0 30px">Pelaajalistaa ei ole vielä saatavilla.</div>';
  };
  const openVideo = url => { const vm = openModal({ width: 820, pad: 14 }); vm.body.innerHTML = `<div class="mhead"><h2>Maalin video</h2><div class="spacer"></div>${closeBtn()}</div><iframe src="${esc(url)}" allow="autoplay; fullscreen; encrypted-media" allowfullscreen style="width:100%;height:440px;border:0;border-radius:10px;background:#000"></iframe>`; };
  const render = () => {
    let body = '';
    const d = game.liiga;
    if (tab === 3 && (isL || nhlStarted())) body = lineupHTML();
    else if (tab === 4 && nhlStarted()) body = playersHTML();
    else if (tab >= 1 && tab <= 2 && !game.final) body = tipsHTML();
    else if (tab === 0 && !game.final && !game.live) body = previewHTML();
    else if (loading) body = '<div class="empty" style="height:260px"><span class="spinner"></span></div>';
    else if (failed) body = '<div class="empty" style="height:260px">Ottelun tietojen haku epäonnistui.</div>';
    else if (d) {
      body = `<div class="muted" style="font-size:13px;display:flex;flex-direction:column;gap:4px;margin-bottom:14px">${d.rink ? `<span>${esc(d.rink)}</span>` : ''}${d.spectators != null ? `<span>Katsojia: ${d.spectators}</span>` : ''}${d.awayPP && d.homePP ? `<span>Ylivoimamaalit / ylivoimat: ${esc(game.away)} ${d.awayPP} · ${esc(game.home)} ${d.homePP}</span>` : ''}${d.resultNote ? `<span class="amber" style="font-weight:600">${esc(d.resultNote)}</span>` : ''}</div>
        ${periodCardHTML(NX)}${goalsHTML(d)}${shootoutHTML(NX)}${statsCardHTML(NX)}${penaltiesHTML(NX)}${starsCardHTML(NX)}${isL ? '<div class="muted" style="font-size:12px">Liigan rajapinta ei kerro kokoonpanoja tai kentällisiä.</div>' : ''}`;
    } else if (box && box.playerByGameStats && box.playerByGameStats.awayTeam && box.playerByGameStats.homeTeam && !(isEmptyTeam(box.playerByGameStats.awayTeam) && isEmptyTeam(box.playerByGameStats.homeTeam))) {
      body = teamCard(game.away, box.playerByGameStats.awayTeam) + teamCard(game.home, box.playerByGameStats.homeTeam);
    } else body = '<div class="empty" style="height:260px;text-align:center;padding:0 30px"><div style="color:var(--text)">Kokoonpanoja ei ole vielä julkaistu.</div><div style="font-size:13px">NHL:n rajapinta antaa pelaajalistan vasta, kun ottelu on alkanut. Kentällisiä (ketjuja) se ei kerro lainkaan.</div></div>';
    m.body.innerHTML = `<div class="mhead"><h2>Ottelu</h2><div class="spacer"></div>${closeBtn()}</div>
      <div class="row" style="gap:12px;justify-content:center"><b style="flex:1;text-align:right;font-size:15px">${esc(game.home)}</b>${logoHTML(game.home, 40)}${scorePill(box && box.homeTeam && box.homeTeam.score != null ? box.homeTeam.score : game.homeScore, box && box.awayTeam && box.awayTeam.score != null ? box.awayTeam.score : game.awayScore, 'lg')}${logoHTML(game.away, 40)}<b style="flex:1;text-align:left;font-size:15px">${esc(game.away)}</b></div>
      <div class="muted" style="font-size:13px;text-align:center;margin:8px 0 10px">${status()}</div>
      ${(!game.final || isL || nhlStarted()) ? `<div class="row" style="justify-content:center;margin-bottom:12px"><div class="seg"><button data-tab="0" class="${tab === 0 ? 'on' : ''}">Ottelu</button>${game.final ? '' : `<button data-tab="1" class="${tab === 1 ? 'on' : ''}">Vihjeet</button>`}${(isL || nhlStarted()) ? `<button data-tab="3" class="${tab === 3 ? 'on' : ''}">Kokoonpano</button>` : ''}${nhlStarted() ? `<button data-tab="4" class="${tab === 4 ? 'on' : ''}">Pelaajat</button>` : ''}</div></div>` : ''}
      <div style="max-height:calc(94vh - 260px);overflow:auto">${body}</div>`;
    m.body.querySelectorAll('[data-tab]').forEach(b => b.onclick = () => { tab = +b.dataset.tab; render(); if (tab === 3) startLineup(); else if (tab === 1 || tab === 2) startTips(); });
    m.body.querySelectorAll('[data-vid]').forEach(b => b.onclick = () => openVideo(b.dataset.vid));
    if (tab >= 1 && tab <= 2 && !game.final) bindTips();
    if (tab === 3 && (isL || nhlStarted())) bindLineup();
  };
  const tipOdds = t => { const mv = (T.manual[t.id] || '').replace(',', '.').trim(); const v = parseFloat(mv); if (v > 1) return v; const b = t.offers.length ? Math.max(...t.offers.map(o => o.price)) : null; return b; };
  const f2 = v => v.toFixed(2).replace('.', ',');
  const slipHTML = () => {
    const sl = T.sel.map(id => T.tips.find(t => t.id === id)).filter(Boolean); const ps = sl.map(tipOdds); const ok = sl.length >= 2 && ps.every(x => x != null);
    const comb = ok ? ps.reduce((a, b) => a * b, 1) : null; const rate = sl.reduce((a, t) => a * t.hits / t.games, 1);
    return `<div style="display:flex;align-items:center;gap:12px"><div style="flex:1"><div style="font-weight:700;font-size:13px">Kuponki ${sl.length}/5</div><div class="muted" style="font-size:12px">${sl.length < 2 ? 'Valitse 2–5 kohdetta.' : 'Karkea osumatiheys ' + Math.round(rate * 100) + ' % (oletus: kohteet toisistaan riippumattomia)'}</div></div>
      ${comb ? `<div style="text-align:right"><div class="cyan mono" style="font-size:19px;font-weight:800">${f2(comb)}</div><div class="muted" style="font-size:10px">yhdistelmäkerroin</div></div>` : sl.length >= 2 ? '<span class="amber" style="font-size:12px">syötä puuttuvat kertoimet</span>' : ''}
      ${sl.length ? '<button class="btn" id="slipclr">Tyhjennä</button>' : ''}</div>`;
  };
  const sugs = () => {
    const sc = t => t.hits / t.games + (t.fav ? 0.15 : 0) + (t.hot ? 0.1 : 0);
    const pool = T.tips.filter(t => (!T.favOnly || t.fav) && T.kinds[t.kind]).sort((a, b) => sc(b) - sc(a)).slice(0, 9); const out = [];
    const rec = (start, cur) => { if (cur.length === T.size) { out.push([cur, cur.reduce((a, t) => a * t.hits / t.games, 1)]); return; } for (let i = start; i < pool.length; i++) { if (cur.some(c => c.player.id === pool[i].player.id)) continue; rec(i + 1, cur.concat(pool[i])); } };
    if (pool.length >= T.size) rec(0, []);
    return out.sort((a, b) => b[1] - a[1]).slice(0, 6).map(x => x[0]);
  };
  const sugHTML = () => {
    const list = sugs();
    const cards = list.length ? list.map((combo, i) => { const ps = combo.map(tipOdds); const odds = ps.every(x => x != null) ? ps.reduce((a, b) => a * b, 1) : null; const rate = combo.reduce((a, t) => a * t.hits / t.games, 1);
      return `<div class="card sm" style="padding:10px;margin-bottom:6px;display:flex;align-items:center;gap:12px"><div style="flex:1;font-size:12px">${combo.map(t => `<div>${esc(t.player.name)} · ${t.kind} (${t.hits}/${t.games})</div>`).join('')}</div>
        <div style="text-align:right"><div class="cyan mono" style="font-size:16px;font-weight:800">${odds ? f2(odds) : '–'}</div><div class="muted" style="font-size:10px">osumatiheys ~${Math.round(rate * 100)} %</div></div><button class="btn" data-sug="${i}">Muokkaa</button></div>`; }).join('')
      : `<div class="muted" style="font-size:11px;margin-bottom:6px">${T.favOnly ? 'Suosikkipelaajia ei ole tarpeeksi tälle kuponkikoolle. Poista "Vain suosikit" tai merkitse lisää suosikkeja (3 tähteä).' : 'Ei tarpeeksi kohteita tälle kuponkikoolle.'}</div>`;
    return `<div class="row" style="gap:10px;margin-bottom:10px"><b style="font-size:12px">Kohteita kupongilla</b><div class="seg">${[2, 3, 4, 5].map(n => `<button data-size="${n}" class="${T.size === n ? 'on' : ''}">${n}</button>`).join('')}</div></div>
      <div class="row" style="gap:16px;margin-bottom:10px;flex-wrap:wrap"><b style="font-size:12px">Kohdetyypit</b>${Object.keys(T.kinds).map(k => `<label class="switch" style="font-size:12px"><input type="checkbox" data-kind="${k}" ${T.kinds[k] ? 'checked' : ''}>${k}</label>`).join('')}<label class="switch" style="font-size:12px"><input type="checkbox" id="favonly" ${T.favOnly ? 'checked' : ''}>Vain suosikit</label></div>${cards}`;
  };
  const tipsHTML = () => {
    if (T.loading) return '<div class="empty" style="height:260px"><span class="spinner"></span></div>';
    const head = T.h2h ? `<div class="muted" style="font-size:12px;text-align:center;margin-bottom:8px">${esc(T.h2h)}</div>` : '';
    if (!T.tips.length) return head + `<div class="empty" style="height:200px;text-align:center;padding:0 30px">${esc(T.note || 'Ei vihjeitä: joukkueiden pelaajilta ei löytynyt tarpeeksi viimeisten pelien tietoja.')}</div>`;
    const rows = T.tips.map(t => { const on = T.sel.includes(t.id); const best = t.offers.length ? t.offers.reduce((a, b) => b.price > a.price ? b : a) : null;
      return `<div class="gamerow" data-tip="${esc(t.id)}" style="cursor:pointer;gap:10px;${on ? 'background:rgba(70,201,245,.10)' : ''}"><span class="${on ? 'cyan' : 'muted'}" style="font-size:16px">${on ? '☑' : '☐'}</span>
        <div style="flex:1;min-width:0"><div style="font-weight:600">${esc(t.player.name)}${t.fav ? ' <span class="amber">★</span>' : ''}${t.hot ? ' ' + FLAME : ''}</div><div class="muted" style="font-size:12px">${t.kind} · ${t.hits}/${t.games} viimeisessä pelissä · ${esc(t.player.team)}</div></div>
        ${best ? `<div style="text-align:right"><div class="cyan mono" style="font-weight:700">${f2(best.price)}</div><div class="muted" style="font-size:10px">${esc(best.book)}</div></div>` : `<input class="input" data-man="${esc(t.id)}" placeholder="kerroin" value="${esc(T.manual[t.id] || '')}" style="width:70px;text-align:right;padding:4px 8px">`}</div>`; }).join('');
    if (tab === 2) return head + sugHTML() + `<div class="muted" style="font-size:11px;text-align:center;margin-top:8px">Vihjeet perustuvat vain viimeisten pelien tilastoihin eivätkä ole todennäköisyyksiä. Pelaa vastuullisesti.</div>`;
    return head + `<div class="card sm sect" style="margin-bottom:10px">${rows}</div>${T.note ? `<div class="amber" style="font-size:12px;text-align:center;margin-bottom:8px">${esc(T.note)}</div>` : ''}<div class="card sm" style="padding:12px" id="slip">${slipHTML()}</div>
      <div class="muted" style="font-size:11px;text-align:center;margin-top:8px">Vihjeet perustuvat vain viimeisten pelien tilastoihin eivätkä ole todennäköisyyksiä. Pelaa vastuullisesti.</div>`;
  };
  const bindTips = () => {
    const slip = () => { const el = $('#slip', m.body); if (el) { el.innerHTML = slipHTML(); const c = $('#slipclr', m.body); if (c) c.onclick = () => { T.sel = []; render(); }; } };
    m.body.querySelectorAll('[data-tip]').forEach(r => r.onclick = e => { if (e.target.closest('input')) return; const id = r.dataset.tip; const i = T.sel.indexOf(id); if (i >= 0) T.sel.splice(i, 1); else if (T.sel.length < 5) T.sel.push(id); else Store.flash('Kuponkiin voi valita enintään 5 kohdetta'); render(); });
    m.body.querySelectorAll('[data-man]').forEach(inp => inp.oninput = () => { T.manual[inp.dataset.man] = inp.value; slip(); });
    const c = $('#slipclr', m.body); if (c) c.onclick = () => { T.sel = []; render(); };
    m.body.querySelectorAll('[data-size]').forEach(b => b.onclick = () => { T.size = +b.dataset.size; render(); });
    const fo = $('#favonly', m.body); if (fo) fo.onchange = () => { T.favOnly = fo.checked; render(); };
    m.body.querySelectorAll('[data-sug]').forEach(b => b.onclick = () => { T.sel = sugs()[+b.dataset.sug].map(t => t.id); tab = 1; render(); });
    m.body.querySelectorAll('[data-kind]').forEach(c => c.onchange = () => { T.kinds[c.dataset.kind] = c.checked; if (!Object.values(T.kinds).some(Boolean)) T.kinds[c.dataset.kind] = true; render(); });
  };
  const startTips = async () => {
    if (T.started) return; T.started = true; T.loading = true; render();
    const league = (Store.teamByName[game.home] || {}).league || 'NHL'; const names = [game.home, game.away];
    const pool = Store.players.filter(p => names.includes(p.team) && p.pos !== 'G' && (p.games || 0) > 0); let cands = [];
    for (const t of names) cands = cands.concat(pool.filter(p => p.team === t).sort((a, b) => { const fa = Store.rating(a.id) === 3 ? 1 : 0, fb = Store.rating(b.id) === 3 ? 1 : 0; return fa !== fb ? fb - fa : (playerPoints(b) || 0) - (playerPoints(a) || 0); }).slice(0, 12));
    const rec = {}; await Promise.all(cands.map(async p => { rec[p.id] = (await Store.recentGames(p)).games || []; })); if (!m.alive) return;
    const built = [];
    for (const p of cands) {
      const g = rec[p.id]; if (g.length < 3) continue; const fav = Store.rating(p.id) === 3, hot = Store.isHot(p);
      const add = (kind, market, hits, min) => { if (hits >= min || (fav && hits >= 2)) built.push({ id: p.id + '|' + kind, player: p, kind, market, hits, games: g.length, fav, hot, offers: [] }); };
      add('Piste', 'player_points@0.5', g.filter(x => (x.goals || 0) + (x.assists || 0) >= 1).length, 3);
      add('Syöttö', 'player_assists@0.5', g.filter(x => (x.assists || 0) >= 1).length, 3);
      add('Maali', 'player_goal_scorer_anytime', g.filter(x => (x.goals || 0) >= 1).length, 2);
      if (g.some(x => x.pp != null)) add('Ylivoimapiste', null, g.filter(x => (x.pp || 0) >= 1).length, 2);
      add('2+ pistettä', 'player_points@1.5', g.filter(x => (x.goals || 0) + (x.assists || 0) >= 2).length, 2);
      add('2+ syöttöä', 'player_assists@1.5', g.filter(x => (x.assists || 0) >= 2).length, 2);
      add('2+ maalia', 'player_goals@1.5', g.filter(x => (x.goals || 0) >= 2).length, 2);
    }
    const sc = t => t.hits / t.games + (t.fav ? 0.15 : 0) + (t.hot ? 0.1 : 0);
    built.sort((a, b) => sc(b) - sc(a) || a.player.name.localeCompare(b.player.name, 'fi')); T.tips = built.slice(0, 30);
    if (!Store.state.oddsKey) T.note = 'Lisää Odds API -avain Asetuksissa, niin ehdotuksiin haetaan kertoimet. Voit syöttää kertoimet myös käsin.';
    else {
      const ev = await Odds.findEvent(game, league);
      if (!ev) T.note = 'Ottelua ei löytynyt Odds API:sta (kertoimia ei ole vielä julkaistu). Syötä kertoimet käsin.';
      else {
        const h = await Odds.h2h(league, ev.id);
        if (h) T.h2h = 'Voittaja (parhaat): ' + [ev.away_team, ev.home_team].map(t => t + ': ' + ((h[t] || []).sort((a, b) => b.price - a.price).slice(0, 2).map(o => o.book + ' ' + f2(o.price)).join(', ') || '–')).join(' · ');
        if (Odds.hasProps(league)) {
          const pr = await Odds.props(league, ev.id);
          if (pr) { for (const t of T.tips) if (t.market && pr[t.market]) t.offers = pr[t.market][norm(t.player.name)] || []; if (!Object.keys(pr).length) T.note = 'Tälle ottelulle ei ole vielä pelaajakohtaisia kertoimia.'; }
          else T.note = 'Pelaajakohtaisten kertoimien haku epäonnistui.';
        } else T.note = 'Tälle sarjalle Odds API ei tarjoa pelaajakohtaisia kertoimia. Syötä kertoimet käsin.';
        if (Odds.remaining != null) T.note += (T.note ? ' ' : '') + 'Odds API -kyselyjä jäljellä: ' + Odds.remaining + '.';
      }
    }
    T.loading = false; if (m.alive) render();
  };
  const isEmptyTeam = t => !(t.forwards || []).length && !(t.defense || []).length && !(t.goalies || []).length;
  const load = async silent => {
    if (!silent) { loading = true; failed = false; }
    if (game.gameId == null) { failed = true; loading = false; render(); return; }
    const b = await fetchBoxscore(game.gameId); if (!m.alive) return;
    if (b) box = b; else if (!silent) failed = true;
    if (isN) { const bb = await fetchNHLBundle(game.gameId); if (!m.alive) return; if (bb) { game.liiga = bb.detail; NX = bb.extras; failed = false; } }
    loading = false; render();
  };
  render();
  if (!game.final && !game.live) startPreview();
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
  const head = `<div class="mhead">${logoHTML(teamName, 44)}<div><h2>${esc(teamName)}</h2><div class="muted" style="font-size:13px">5 viimeisintä ottelua</div></div><div class="spacer"></div>${closeBtn()}</div>`;
  m.body.innerHTML = head + '<div class="muted"><span class="spinner"></span> Haetaan…</div>';
  fetchTeamResults(teamName, Store.teams).then(r => {
    if (!m.alive) return;
    if (!r) { m.body.innerHTML = head + '<div class="muted">Tulosten haku epäonnistui. Tarkista verkkoyhteys ja avaa uudelleen.</div>'; return; }
    const form = r.games.slice().reverse().map(g => `<span class="${g.win ? 'green' : 'red'}" style="font-weight:800">${g.win ? 'V' : 'H'}</span>`).join(' ');
    const w = r.games.filter(g => g.win).length, gf = r.games.reduce((s, g) => s + g.gf, 0), ga = r.games.reduce((s, g) => s + g.ga, 0);
    let h = head;
    if (r.games.length) {
      h += `<div class="row" style="margin-bottom:12px"><span class="label">Muoto</span>${form}<div class="spacer"></div>${chip(`${w} V – ${r.games.length - w} H`)}${chip(`maalit ${gf}–${ga}`)}</div>
        <div class="card sm sect">${r.games.map(g => `<div class="gamerow${g.game ? ' click' : ''}"${g.game ? ` data-gi="${r.games.indexOf(g)}"` : ''}><span class="mono muted" style="width:52px;white-space:nowrap;font-size:13px">${g.date.getDate()}.${g.date.getMonth() + 1}.</span><span class="muted" style="width:56px;font-size:13px">${g.home ? 'Koti' : 'Vieras'}</span>${logoHTML(g.opponent, 26)}<span class="tn">${esc(g.opponent)}</span>
          <span class="mono" style="font-weight:700;width:70px;text-align:center">${g.gf} – ${g.ga}${g.extra ? ` <span class="muted" style="font-size:11px;font-weight:600">${g.extra}</span>` : ''}</span><span class="${g.win ? 'green' : 'red'}" style="width:20px;text-align:center;font-weight:800">${g.win ? 'V' : 'H'}</span></div>`).join('')}</div>`;
    } else h += '<div class="muted">Ei pelattuja otteluita tällä kaudella.</div>';
    if (r.note) h += `<div class="muted" style="font-size:12px;margin-top:8px">${esc(r.note)}</div>`;
    h += '<div class="muted" style="font-size:12px;margin-top:4px">Tulos näytetään joukkueen näkökulmasta (oma maalimäärä ensin). JA = jatkoaika, RL = rankkarit.</div>';
    m.body.innerHTML = h;
    m.body.querySelectorAll('[data-gi]').forEach(el => el.onclick = () => openGame(r.games[+el.dataset.gi].game));
  });
}
