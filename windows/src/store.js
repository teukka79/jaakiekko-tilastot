'use strict';
// ---------- Siemendata ----------
function parseSeed() {
  const teams = [];
  for (const line of SEED.teamsRaw.split('\n')) {
    const c = line.split('|'); if (c.length < 3 || !LEAGUES.some(l => l.id === c[0])) continue;
    let flag;
    switch (c[0]) {
      case 'NHL': case 'AHL': flag = (c.length > 3 && c[3] === 'CA') ? '🇨🇦' : '🇺🇸'; break;
      case 'SM-liiga': case 'Mestis': flag = '🇫🇮'; break;
      default: flag = '🇸🇪';
    }
    teams.push({ name: c[1], abbr: c[2], league: c[0], flag });
  }
  const byName = Object.fromEntries(teams.map(t => [t.name, t]));
  const players = [];
  SEED.rosterRaw.split('\n').forEach((line, i) => {
    const c = line.split('|'); if (c.length < 2) return;
    const team = byName[c[0]]; if (!team) return;
    const f = idx => (idx < c.length && c[idx] !== '') ? c[idx] : null;
    const id = f(7) || `t-${i}`;
    const p = { id, name: c[1], team: team.name, league: team.league, flag: team.flag, pos: f(2), nat: f(3), born: null, shoots: null,
      games: toInt(f(4)), goals: toInt(f(5)), assists: toInt(f(6)), pim: null, plusMinus: null, isCustom: false, shots: null, slot: null, ppPoints: null, number: null };
    const m = SEED.meta[id];
    if (m) { if (m.nat) p.nat = m.nat; p.born = m.born; p.shoots = m.shoots; }
    players.push(p);
  });
  return { teams, players };
}

const playerPoints = p => (p.goals == null && p.assists == null) ? null : (p.goals || 0) + (p.assists || 0);
const playerPPG = p => { const pts = playerPoints(p); return (p.games && p.games > 0 && pts != null) ? pts / p.games : null; };
const playerAge = p => p.born ? 2026 - p.born : null;
const positionLabel = p => ({ F: 'Hyökkääjä', D: 'Puolustaja', G: 'Maalivahti' })[p.pos] || null;
const slotLabel = p => ({ C: 'Keskushyökkääjä', L: 'Vasen laita', R: 'Oikea laita', D: 'Puolustaja' })[p.slot] || ({ F: 'Hyökkääjä', D: 'Puolustaja', G: 'Maalivahti' })[p.pos] || '–';

// ---------- Store ----------
const Store = {
  teams: [], teamByName: {}, teamByAbbr: {}, seedPlayers: [], players: [],
  state: { ratings: {}, notes: {}, edits: {}, logos: {}, customPlayers: [], live: null, liveLiiga: null, liveAHL: null, liveMestis: null, autoLogos: {}, liveEP: {} },
  status: { nhl: 'NHL: ei haettu', liiga: 'Liiga: ei haettu', ahl: 'AHL: ei haettu', mestis: 'Mestis: ei haettu', ep: 'SHL/HA: ei haettu' },
  hasEPKey: false, epKey: null, isRefreshing: false, liveGamesOn: false,
  toast: null, settings: {},
  lastEPFetch: 0, lastFullRefresh: 0, lastFastRefresh: 0, scoreBaseline: {}, notifyArmed: false, recentCache: {},
  listeners: new Set(),
  on(fn) { this.listeners.add(fn); },
  emit(what = 'all') { for (const f of this.listeners) f(what); },

  async init() {
    const seed = parseSeed();
    this.teams = seed.teams; this.seedPlayers = seed.players;
    this.teamByName = Object.fromEntries(seed.teams.map(t => [t.name, t]));
    this.teamByAbbr = Object.fromEntries(seed.teams.filter(t => t.league === 'NHL').map(t => [t.abbr, t]));
    try { const txt = await native.loadState(); if (txt) Object.assign(this.state, JSON.parse(txt)); } catch {}
    this.state.ratings ||= {}; this.state.notes ||= {}; this.state.edits ||= {}; this.state.logos ||= {}; this.state.customPlayers ||= []; this.state.autoLogos ||= {}; this.state.liveEP ||= {};
    this.settings = await native.getSettings() || {};
    this.settings.notifyEnabled = this.settings.notifyEnabled ?? true; this.settings.notifyMinStars = this.settings.notifyMinStars ?? 3; this.settings.notifySound = this.settings.notifySound ?? true;
    this.epKey = await native.getSecret(); this.hasEPKey = !!this.epKey;
    const ts = k => this.state[k] && this.state[k].timestamp;
    if (ts('live')) this.status.nhl = 'NHL tallennettu ' + timeString(ts('live'));
    if (ts('liveLiiga')) this.status.liiga = 'Liiga tallennettu ' + timeString(ts('liveLiiga'));
    if (ts('liveAHL')) this.status.ahl = 'AHL tallennettu ' + timeString(ts('liveAHL'));
    if (ts('liveMestis')) this.status.mestis = 'Mestis tallennettu ' + timeString(ts('liveMestis'));
    const epTs = Object.values(this.state.liveEP || {}).map(s => s.timestamp).sort().pop();
    if (epTs) { this.status.ep = 'SHL/HA tallennettu ' + timeString(epTs); this.lastEPFetch = new Date(epTs).getTime(); }
    this.rebuild();
    if (this.settings.notifyEnabled && 'Notification' in window) Notification.requestPermission();
  },

  get epOK() { return this.status.ep.includes('päivitetty') || this.status.ep.includes('tallennettu'); },
  get liveStatus() { const s = this.status; return [s.nhl, s.liiga, s.ahl, s.mestis].join(' · ') + (this.hasEPKey && this.epOK ? ' · ' + s.ep : ''); },

  persist() { try { native.saveState(JSON.stringify(this.state)); } catch {} },
  async setSetting(k, v) { this.settings[k] = v; await native.setSettings({ [k]: v }); },

  // ----- Yhdistäminen -----
  liveFor(p) {
    if (p.league !== 'NHL' || !this.state.live) return null;
    const list = this.state.live.byName[norm(p.name)]; if (!list) return null;
    const team = this.teamByName[p.team]; const abbr = team && team.abbr;
    const cand = list.filter(e => !p.pos ? true : (p.pos === 'D') === (e.pos === 'D'));
    const entry = cand.find(e => e.abbr === abbr) || (cand.length === 1 ? cand[0] : null);
    if (!entry) return null;
    return { entry, team: entry.abbr !== abbr ? (this.teamByAbbr[entry.abbr] || null) : null };
  },

  rebuild() {
    const st = this.state;
    const custom = st.customPlayers.map(sp => {
      if (!LEAGUES.some(l => l.id === sp.league)) return null;
      return { id: sp.id, name: sp.name, team: sp.team, league: sp.league, flag: sp.flag || leagueFlag(sp.league), pos: sp.pos ?? null, nat: sp.nat ?? null, born: sp.born ?? null, shoots: sp.shoots ?? null,
        games: sp.games ?? null, goals: sp.goals ?? null, assists: sp.assists ?? null, pim: sp.pim ?? null, plusMinus: sp.plusMinus ?? null, isCustom: true, shots: null, slot: null, ppPoints: null, number: null };
    }).filter(Boolean);
    const out = [];
    for (const base of this.seedPlayers.concat(custom)) {
      const p = { ...base };
      const nk = norm(p.name);
      if (p.league === 'SM-liiga' && st.liveLiiga && st.liveLiiga.teamGames && Object.keys(st.liveLiiga.teamGames).length) {
        const snap = st.liveLiiga; const e = (snap.byName[nk] || [])[0];
        p.goals = e ? e.goals : 0; p.ppPoints = e ? (e.ppPoints || 0) : 0; p.assists = e ? e.assists : 0;
        if (e && e.pos) { p.games = e.games; p.pim = e.pim ?? null; p.plusMinus = e.plusMinus ?? null; p.shots = e.shots ?? null; }
        else { p.games = snap.teamGames[p.team] || 0; p.pim = null; p.plusMinus = null; }
      }
      if (p.league === 'SHL' || p.league === 'HockeyAllsvenskan') {
        const e = st.liveEP && st.liveEP[p.league] && (st.liveEP[p.league].byName[nk] || [])[0];
        if (e) { p.games = e.games; p.goals = e.goals; p.assists = e.assists; p.pim = e.pim ?? null; p.plusMinus = e.plusMinus ?? null; }
      }
      const lv = this.liveFor(p);
      if (lv) {
        const e = lv.entry;
        p.games = e.games; p.goals = e.goals; p.assists = e.assists; p.pim = e.pim ?? null; p.plusMinus = e.plusMinus ?? null; p.shots = e.shots ?? null; p.slot = e.pos; p.ppPoints = e.ppPoints ?? null;
        if (lv.team) { p.team = lv.team.name; p.flag = lv.team.flag; }
      }
      if (p.league === 'NHL' && st.live && st.live.info && st.live.info[nk]) { const i = st.live.info[nk]; p.number = i.number ?? null; if (!p.nat) p.nat = i.nat ?? null; }
      else if (p.league === 'SM-liiga' && st.liveLiiga && st.liveLiiga.info && st.liveLiiga.info[nk]) { const i = st.liveLiiga.info[nk]; p.number = i.number ?? null; if (!p.nat) p.nat = i.nat ?? null; }
      const ed = st.edits[p.id];
      if (ed) {
        p.games = ed.games ?? null; p.goals = ed.goals ?? null; p.assists = ed.assists ?? null; p.pim = ed.pim ?? null; p.plusMinus = ed.plusMinus ?? null;
        if (ed.pos) p.pos = ed.pos; if (ed.nat) p.nat = ed.nat; if (ed.born) p.born = ed.born; if (ed.shoots) p.shoots = ed.shoots;
      }
      out.push(p);
    }
    const have = new Set(out.map(p => p.league + '|' + norm(p.name)));
    const mk = (id, name, team, league, over) => Object.assign({ id, name, team: team.name, league, flag: team.flag, pos: null, nat: null, born: null, shoots: null, games: null, goals: null, assists: null, pim: null, plusMinus: null, isCustom: false, shots: null, slot: null, ppPoints: null, number: null }, over);
    if (st.live) for (const [key, list] of Object.entries(st.live.byName)) for (const e of list) {
      const tag = 'NHL|' + key; const team = this.teamByAbbr[e.abbr];
      if (have.has(tag) || !e.name || !team) continue; have.add(tag);
      const i = st.live.info && st.live.info[key];
      out.push(mk('nhl-' + (e.playerId ?? key), e.name, team, 'NHL', { pos: e.pos === 'D' ? 'D' : 'F', games: e.games, goals: e.goals, assists: e.assists, pim: e.pim ?? null, plusMinus: e.plusMinus ?? null, shots: e.shots ?? null, slot: e.pos, ppPoints: e.ppPoints ?? null, number: i ? i.number ?? null : null, nat: i ? i.nat ?? null : null }));
    }
    if (st.liveLiiga) for (const [key, list] of Object.entries(st.liveLiiga.byName)) for (const e of list) {
      if (!(e.goals + e.assists > 0 || e.pos)) continue;
      const tag = 'SM-liiga|' + key; const team = this.teamByName[e.abbr];
      if (have.has(tag) || !e.name || !team) continue; have.add(tag);
      const official = !!e.pos; const i = st.liveLiiga.info && st.liveLiiga.info[key];
      out.push(mk('liiga-' + key, e.name, team, 'SM-liiga', { pos: official ? e.pos : null, nat: i ? i.nat ?? null : null,
        games: official ? e.games : ((st.liveLiiga.teamGames || {})[team.name] || 0), goals: e.goals, assists: e.assists,
        pim: official ? e.pim ?? null : null, plusMinus: official ? e.plusMinus ?? null : null, shots: official ? e.shots ?? null : null, number: i ? i.number ?? null : null, ppPoints: e.ppPoints ?? null }));
    }
    if (st.liveAHL) for (const [key, list] of Object.entries(st.liveAHL.byName)) for (const e of list) {
      if (!(e.goals + e.assists > 0)) continue;
      const tag = 'AHL|' + key; const team = this.teamByName[e.abbr];
      if (have.has(tag) || !e.name || !team) continue; have.add(tag);
      const i = st.liveAHL.info && st.liveAHL.info[key];
      out.push(mk('ahl-' + (e.playerId ?? key), e.name, team, 'AHL', { pos: e.pos === 'D' ? 'D' : 'F', games: e.games, goals: e.goals, assists: e.assists, pim: e.pim ?? null, plusMinus: e.plusMinus ?? null, shots: e.shots ?? null, slot: e.pos, ppPoints: e.ppPoints ?? null, number: i ? i.number ?? null : null }));
    }
    if (st.liveMestis) for (const [key, list] of Object.entries(st.liveMestis.byName)) for (const e of list) {
      const tag = 'Mestis|' + key; const team = this.teamByName[e.abbr];
      if (have.has(tag) || !e.name || !team) continue; have.add(tag);
      const i = st.liveMestis.info && st.liveMestis.info[key];
      out.push(mk('mestis-' + (e.playerId ?? key), e.name, team, 'Mestis', { pos: e.pos, games: e.games, goals: e.goals, assists: e.assists, pim: e.pim ?? null, plusMinus: e.plusMinus ?? null, shots: e.shots ?? null, number: i ? i.number ?? null : null, nat: i ? i.nat ?? null : null }));
    }
    this.players = out; this.playerIndex = null;
  },

  player(id) { if (!this.playerIndex) this.playerIndex = new Map(this.players.map(p => [p.id, p])); return this.playerIndex.get(id) || null; },
  rating(id) { return this.state.ratings[id] || 0; },
  note(id) { return this.state.notes[id] || ''; },
  logoURL(name) {
    return this.state.logos[name] || this.state.autoLogos[name] || SEED.staticLogos[name] ||
      (this.teamByName[name] && this.teamByName[name].league === 'NHL' ? `https://assets.nhle.com/logos/nhl/svg/${this.teamByName[name].abbr}_dark.svg` : null);
  },
  abbr(name) { const t = this.teamByName[name]; if (t) return t.abbr; return name.split(' ').filter(Boolean).map(s => s[0]).slice(0, 3).join('').toUpperCase(); },
  teamNames(league) {
    const names = this.teams.filter(t => !league || t.league === league).map(t => t.name);
    for (const p of this.players) if ((!league || p.league === league) && !this.teamByName[p.team] && !names.includes(p.team)) names.push(p.team);
    return names;
  },
  get ratedCount() { return this.players.filter(p => this.rating(p.id) > 0).length; },
  get notesCount() { return this.players.filter(p => this.note(p.id)).length; },

  // ----- Muutokset -----
  setRating(id, v) {
    if (this.rating(id) === v) delete this.state.ratings[id]; else this.state.ratings[id] = v;
    this.persist(); const p = this.player(id), r = this.rating(id);
    if (p) this.flash(r > 0 ? `${p.name}: ${'⭐'.repeat(r)}` : `${p.name}: arvostelu poistettu`);
    this.emit('ratings');
  },
  resetRatings(list) { for (const p of list) delete this.state.ratings[p.id]; this.persist(); this.flash('Tähdet nollattu'); this.emit('ratings'); },
  setNote(id, text) { if (!text.trim()) delete this.state.notes[id]; else this.state.notes[id] = text; this.persist(); this.emit('notes'); },
  saveEdit(id, e) { this.state.edits[id] = e; this.persist(); this.rebuild(); this.flash('Tiedot päivitetty'); this.emit(); },
  resetEdit(id) { delete this.state.edits[id]; this.persist(); this.rebuild(); this.flash('Alkuperäiset tiedot palautettu'); this.emit(); },
  setLogo(team, url) { const t = url.trim(); if (!t) delete this.state.logos[team]; else this.state.logos[team] = t; this.persist(); },
  addPlayer(p) { this.state.customPlayers.push(storedFrom(p)); this.persist(); this.rebuild(); this.flash(`${p.name} lisätty`); this.emit(); },
  updateCustom(p) { const i = this.state.customPlayers.findIndex(x => x.id === p.id); if (i < 0) return; this.state.customPlayers[i] = storedFrom(p); this.persist(); this.rebuild(); this.flash('Tiedot päivitetty'); this.emit(); },
  deleteCustom(id) { this.state.customPlayers = this.state.customPlayers.filter(p => p.id !== id); delete this.state.ratings[id]; delete this.state.notes[id]; delete this.state.edits[id]; this.persist(); this.rebuild(); this.flash('Pelaaja poistettu'); this.emit(); },
  newCustomID() { return 'custom-' + Math.random().toString(16).slice(2, 10); },

  exportText() {
    const s = this.state;
    const sorted = o => Object.fromEntries(Object.entries(o).sort(([a], [b]) => a < b ? -1 : 1));
    return JSON.stringify({ app: 'jaakiekko-pistepörssi', version: 2, season: '2026/2027', exportedAt: new Date().toISOString(), ratings: sorted(s.ratings), notes: sorted(s.notes), edits: sorted(s.edits), logos: sorted(s.logos), customPlayers: s.customPlayers }, null, 2);
  },
  importText(text) {
    let b; try { b = JSON.parse(text); } catch { this.flash('Virheellinen JSON-tiedosto'); return false; }
    let r = 0, n = 0, c = 0; const s = this.state;
    for (const [k, v] of Object.entries(b.ratings || {})) if (v >= 1 && v <= 3) { s.ratings[k] = v; r++; }
    for (const [k, v] of Object.entries(b.notes || {})) if (String(v).trim()) { s.notes[k] = v; n++; }
    for (const [k, v] of Object.entries(b.edits || {})) s.edits[k] = v;
    for (const [k, v] of Object.entries(b.logos || {})) if (String(v).toLowerCase().startsWith('http')) s.logos[k] = v;
    for (const sp of b.customPlayers || []) if (String(sp.id).startsWith('custom-') && LEAGUES.some(l => l.id === sp.league)) {
      const i = s.customPlayers.findIndex(x => x.id === sp.id); if (i >= 0) s.customPlayers[i] = sp; else s.customPlayers.push(sp); c++;
    }
    this.persist(); this.rebuild(); this.flash(`Tuotu: ${r} arvostelua, ${n} muistiinpanoa, ${c} pelaajaa`); this.emit(); return true;
  },

  // ----- Päivitys -----
  async refreshLive(force = false) {
    if (this.isRefreshing) return;
    this.isRefreshing = true; this.emit('status'); this.lastFullRefresh = Date.now();
    try {
      await this.refreshNHL(); await this.refreshLiiga(); await this.refreshAHL(); await this.refreshMestis();
      this.notifyArmed = true;
      if (this.hasEPKey && (force || !this.lastEPFetch || Date.now() - this.lastEPFetch > 7200000)) await this.refreshEP();
    } finally { this.isRefreshing = false; this.emit(); }
  },

  async autoRefreshTick() {
    if (this.isRefreshing) return;
    if (Date.now() - this.lastFullRefresh >= 600000) { await this.refreshLive(); return; }
    const [nhl, ahl, liiga] = await Promise.all([nhlHasLiveGames(), ahlHasLiveGames(), liigaHasLiveGames()]);
    this.liveGamesOn = nhl || ahl || liiga; this.emit('status');
    if (!this.liveGamesOn || Date.now() - this.lastFastRefresh < 55000) return;
    this.isRefreshing = true; this.lastFastRefresh = Date.now();
    try { if (nhl) await this.refreshNHL(true); if (ahl) await this.refreshAHL(); if (liiga) await this.refreshLiiga(); }
    finally { this.isRefreshing = false; this.emit(); }
  },

  async setEPKey(key) {
    const t = key.trim(); await native.setSecret(t); this.epKey = t || null; this.hasEPKey = !!t;
    if (!this.hasEPKey) this.status.ep = 'SHL/HA: ei avainta'; this.emit('status');
  },

  async refreshEP() {
    if (!this.epKey) return;
    this.status.ep = 'Päivitetään SHL/HA…'; this.emit('status');
    const snapshots = { ...(this.state.liveEP || {}) }; const failures = []; let fetched = 0;
    for (const [league, slug, label] of [['SHL', 'shl', 'SHL'], ['HockeyAllsvenskan', 'hockeyallsvenskan', 'HockeyAllsvenskan']]) {
      const res = await fetchEPLeague(slug, this.epKey);
      if (!res.rows || !res.rows.length) { failures.push(`${label}: ${res.error || 'tuntematon virhe'}`); continue; }
      const byName = {};
      for (const r of res.rows) {
        const pl = r.player || {}; const name = pl.name || [pl.firstName, pl.lastName].filter(Boolean).join(' '); const st = r.regularStats;
        if (!name || !st) continue; const k = norm(name);
        const e = byName[k] || { abbr: (r.team && r.team.name) || '', pos: '', games: 0, goals: 0, assists: 0, pim: null, plusMinus: null };
        e.games += st.GP || 0; e.goals += st.G || 0; e.assists += st.A || 0;
        if (st.PIM != null) e.pim = (e.pim || 0) + st.PIM; if (st.PM != null) e.plusMinus = (e.plusMinus || 0) + st.PM;
        byName[k] = e;
      }
      if (!Object.keys(byName).length) { failures.push(`${label}: ei tilastorivejä`); continue; }
      const snap = {}; for (const [k, v] of Object.entries(byName)) snap[k] = [v];
      snapshots[league] = { byName: snap, timestamp: new Date().toISOString() }; fetched++;
    }
    this.lastEPFetch = Date.now();
    if (fetched > 0) { this.state.liveEP = snapshots; this.persist(); this.rebuild(); }
    this.status.ep = failures.length ? 'SHL/HA: ' + failures.join('; ') : 'SHL/HA päivitetty ' + timeString(new Date()); this.emit();
  },

  async refreshNHL(fast = false) {
    this.status.nhl = 'Päivitetään NHL…'; this.emit('status');
    const nhlTeams = this.teams.filter(t => t.league === 'NHL');
    const results = (await pool(nhlTeams, 16, t => fetchNHLTeam(t))).filter(Boolean);
    if (!results.length) { const ts = this.state.live && this.state.live.timestamp; this.status.nhl = ts ? 'NHL: ei yhteyttä, tallennettu ' + timeString(ts) : 'NHL: ei yhteyttä'; this.emit('status'); return; }
    const ppMap = await fetchNHLPowerPlay(); const byName = {};
    for (const { team, skaters } of results) for (const s of skaters) {
      const full = s.firstName.default + ' ' + s.lastName.default; const key = norm(full);
      (byName[key] ||= []).push({ abbr: team.abbr, pos: s.positionCode, games: s.gamesPlayed, goals: s.goals, assists: s.assists, pim: s.penaltyMinutes ?? null, plusMinus: s.plusMinus ?? null, playerId: s.playerId ?? null, shots: s.shots ?? null, name: full, ppPoints: s.playerId != null ? (ppMap[s.playerId] ?? null) : null });
    }
    const now = new Date().toISOString(); const old = this.state.live || {};
    this.state.live = { byName, timestamp: now, hot: old.hot, info: old.info };
    this.persist(); this.rebuild(); this.status.nhl = 'NHL päivitetty ' + timeString(now); this.emit();
    this.checkScoringNotifications();
    const ids = []; for (const [k, list] of Object.entries(byName)) { if (!list.some(e => e.goals + e.assists > 0)) continue; const e = list.find(x => x.playerId != null); if (e) ids.push([k, e.playerId]); }
    if (!fast) (async () => { await this.refreshNHLHot(ids); await this.refreshNHLRosters(); })();
  },

  async refreshLiiga() {
    this.status.liiga = 'Päivitetään Liiga…'; this.emit('status');
    const games = await fetchLiigaGames();
    if (!games) { const ts = this.state.liveLiiga && this.state.liveLiiga.timestamp; this.status.liiga = ts ? 'Liiga: ei yhteyttä, tallennettu ' + timeString(ts) : 'Liiga: ei yhteyttä'; this.emit('status'); return; }
    const byName = {}, teamGames = {}, logos = { ...this.state.autoLogos }, infoAcc = {}, recentAcc = {}, teamStarts = {}, teamRecentAcc = {}, pointGames = [];
    const seedByKey = Object.fromEntries(this.teams.filter(t => t.league === 'SM-liiga').map(t => [liigaKey(t.name), t.name]));
    const bump = (person, team, goal, pp) => {
      if (!person || !personName(person)) return;
      const key = norm(personName(person)); const j = personJersey(person); if (j != null) infoAcc[key] = { number: j, nat: null };
      const e = byName[key] || { abbr: team, pos: '', games: 0, goals: 0, assists: 0, pim: null, plusMinus: null, name: personName(person) };
      if (goal) e.goals++; else e.assists++; if (pp) e.ppPoints = (e.ppPoints || 0) + 1; byName[key] = e;
    };
    for (const g of games) {
      [g.homeTeam, g.awayTeam].forEach((t, side) => {
        if (!t || !t.teamName) return; const seedName = seedByKey[liigaKey(t.teamName)]; if (!seedName) return;
        const lg = t.logos && (t.logos.darkBg || t.logos.lightBg); if (lg && lg.toLowerCase().startsWith('http')) logos[seedName] = lg;
        if (!flexBool(g.ended)) return;
        teamGames[seedName] = (teamGames[seedName] || 0) + 1; (teamStarts[seedName] ||= []).push(g.start || '');
        const evs = t.goalEvents || []; const local = {};
        const isPP = ev => (ev.goalTypes || []).some(x => String(x).toUpperCase().startsWith('YV'));
        for (const ev of evs) {
          const pp = isPP(ev); bump(ev.scorerPlayer, seedName, true, pp);
          for (const a of ev.assistantPlayers || []) bump(a, seedName, false, pp);
          const sn = ev.scorerPlayer && personName(ev.scorerPlayer);
          if (sn) { const k = norm(sn); const l = local[k] ||= { g: 0, a: 0, pp: 0 }; l.g++; if (pp) l.pp++; }
          for (const a of ev.assistantPlayers || []) { const n = personName(a); if (!n) continue; const l = local[norm(n)] ||= { g: 0, a: 0, pp: 0 }; l.a++; if (pp) l.pp++; }
        }
        const other = side === 0 ? (g.awayTeam && g.awayTeam.teamName) : (g.homeTeam && g.homeTeam.teamName);
        const date = String(g.start || '').slice(0, 10);
        (teamRecentAcc[seedName] ||= []).push({ date, opponent: other || '?', home: side === 0, goals: 0, assists: 0, pp: 0 });
        for (const [k, v] of Object.entries(local)) {
          pointGames.push({ key: k, team: seedName, start: g.start || '' });
          (recentAcc[k] ||= []).push({ date, opponent: other || '?', home: side === 0, goals: v.g, assists: v.a, pp: v.pp });
        }
      });
    }
    const now = new Date().toISOString(); const snapshot = {};
    for (const [k, v] of Object.entries(byName)) snapshot[k] = [v];
    const stats = await fetchLiigaPlayerStats();
    if (stats) for (const s of stats) {
      const seedName = seedByKey[liigaKey(s.teamName || '')]; if (!seedName || !s.firstName || !s.lastName) continue;
      const full = s.firstName + ' ' + s.lastName; const key = norm(full);
      snapshot[key] = [{ abbr: seedName, pos: s.role === 'P' ? 'D' : 'F', games: s.playedGames || 0, goals: s.goals || 0, assists: s.assists || 0, pim: s.penaltyMinutes ?? null, plusMinus: s.plusMinus ?? null, playerId: s.playerId ?? null, shots: s.shots ?? null, name: full, ppPoints: byName[key] ? byName[key].ppPoints : undefined }];
      infoAcc[key] = { number: s.jersey ?? null, nat: s.nationality ?? null };
    }
    const recent = {}; for (const [k, list] of Object.entries(recentAcc)) recent[k] = list.sort((a, b) => b.date < a.date ? -1 : b.date > a.date ? 1 : 0).slice(0, 5);
    const lastStarts = {}; for (const [t, starts] of Object.entries(teamStarts)) lastStarts[t] = new Set(starts.slice().sort().slice(-4));
    const hitStarts = {}; for (const pg of pointGames) if (lastStarts[pg.team] && lastStarts[pg.team].has(pg.start)) (hitStarts[pg.key] ||= new Set()).add(pg.start);
    const hot = Object.entries(hitStarts).filter(([, s]) => s.size === 4).map(([k]) => k);
    const teamRecent = {}; for (const [t, l] of Object.entries(teamRecentAcc)) teamRecent[t] = l.sort((a, b) => b.date < a.date ? -1 : b.date > a.date ? 1 : 0).slice(0, 5);
    this.state.liveLiiga = { byName: snapshot, timestamp: now, teamGames, recent, hot, teamRecent, info: infoAcc };
    this.state.autoLogos = logos; this.persist(); this.rebuild(); this.status.liiga = 'Liiga päivitetty ' + timeString(now); this.emit();
    this.checkScoringNotifications();
  },

  async refreshAHL() {
    this.status.ahl = 'Päivitetään AHL…'; this.emit('status');
    const season = await fetchAHLSeasonId(); const feedTeams = await fetchAHLTeams(season);
    const skaters = await fetchAHLSkaters(season, feedTeams.map(t => t.id));
    if (!skaters) { const ts = this.state.liveAHL && this.state.liveAHL.timestamp; this.status.ahl = ts ? 'AHL: ei yhteyttä, tallennettu ' + timeString(ts) : 'AHL: ei yhteyttä'; this.emit('status'); return; }
    const byCode = Object.fromEntries(this.teams.filter(t => t.league === 'AHL').map(t => [t.abbr, t.name]));
    const byName = {}, info = {};
    for (const s of skaters.slice().sort((a, b) => b.games - a.games)) {
      const teamName = (this.teamByName[s.team] && this.teamByName[s.team].name) || byCode[s.code]; if (!teamName) continue;
      const pos = ({ LW: 'L', L: 'L', RW: 'R', R: 'R', D: 'D' })[s.pos] || 'C'; const key = norm(s.name);
      (byName[key] ||= []).push({ abbr: teamName, pos, games: s.games, goals: s.goals, assists: s.assists, pim: s.pim, plusMinus: s.plusMinus, playerId: s.id, shots: s.shots, name: s.name, ppPoints: s.ppPoints });
      if (!info[key]) info[key] = { number: s.number, nat: null };
    }
    const now = new Date().toISOString(); this.state.liveAHL = { byName, timestamp: now, info };
    const logos = { ...this.state.autoLogos };
    for (const t of feedTeams) if (this.teamByName[t.name] && this.teamByName[t.name].league === 'AHL' && t.logo) logos[t.name] = t.logo;
    this.state.autoLogos = logos; this.persist(); this.rebuild(); this.status.ahl = 'AHL päivitetty ' + timeString(now); this.emit();
    this.checkScoringNotifications();
  },

  async refreshMestis() {
    this.status.mestis = 'Päivitetään Mestis…'; this.emit('status');
    const skaters = await fetchMestisSkaters();
    if (!skaters) { const ts = this.state.liveMestis && this.state.liveMestis.timestamp; this.status.mestis = ts ? 'Mestis: ei yhteyttä, tallennettu ' + timeString(ts) : 'Mestis: ei yhteyttä'; this.emit('status'); return; }
    const byName = {};
    for (const s of skaters.slice().sort((a, b) => b.games - a.games)) {
      const teamName = mestisResolve(s.team, this.teams); if (!teamName) continue; const key = norm(s.name);
      (byName[key] ||= []).push({ abbr: teamName, pos: s.pos === 'P' ? 'D' : 'F', games: s.games, goals: s.goals, assists: s.assists, pim: s.pim, plusMinus: s.plusMinus, playerId: s.id, shots: s.shots, name: s.name, link: s.link });
    }
    const now = new Date().toISOString(); this.state.liveMestis = { byName, timestamp: now, info: this.state.liveMestis && this.state.liveMestis.info };
    const logos = { ...this.state.autoLogos }; for (const [n, u] of Object.entries(MESTIS_LOGOS)) logos[n] = MESTIS_BASE + u;
    this.state.autoLogos = logos; this.persist(); this.rebuild(); this.status.mestis = 'Mestis päivitetty ' + timeString(now); this.emit();
    this.checkScoringNotifications(); this.refreshMestisInfo();
  },

  async refreshMestisInfo() {
    const snap = this.state.liveMestis; if (!snap) return;
    const info = { ...(snap.info || {}) };
    const todo = []; for (const [k, list] of Object.entries(snap.byName)) { if (!info[k] && list[0] && list[0].link) todo.push([k, list[0].link]); }
    if (!todo.length) return;
    const res = await pool(todo, 8, async ([k, l]) => [k, await fetchMestisPlayerInfo(l)]);
    for (const [k, i] of res) if (i) info[k] = i;
    if (this.state.liveMestis) { this.state.liveMestis.info = info; this.persist(); this.rebuild(); this.emit(); }
  },

  isHot(p) {
    const k = norm(p.name);
    if (p.league === 'NHL') return !!(this.state.live && this.state.live.hot && this.state.live.hot.includes(k));
    if (p.league === 'SM-liiga') return !!(this.state.liveLiiga && this.state.liveLiiga.hot && this.state.liveLiiga.hot.includes(k));
    return false;
  },

  async refreshNHLRosters() {
    const rosters = await pool(this.teams.filter(t => t.league === 'NHL'), 16, t => fetchNHLRoster(t.abbr));
    const info = {};
    for (const p of rosters.flat()) { if (!p.firstName || !p.lastName) continue; info[norm(p.firstName.default + ' ' + p.lastName.default)] = { number: p.sweaterNumber ?? null, nat: p.birthCountry ?? null }; }
    if (!Object.keys(info).length || !this.state.live) return;
    this.state.live.info = info; this.persist(); this.rebuild(); this.emit();
  },
  async refreshNHLHot(ids) {
    const res = await pool(ids, 8, ([k, id]) => nhlHotCheck(k, id)); const hot = [];
    for (const r of res) if (r && r[1]) hot.push(r[0]);
    if (this.state.live) { this.state.live.hot = hot; this.persist(); this.emit(); }
  },

  async recentGames(p) {
    const c = this.recentCache[p.id]; if (c && Date.now() - c.t < 600000) return c.v;
    const res = { games: [], note: null };
    if (p.league === 'NHL') {
      const lv = this.liveFor(p); const id = lv && lv.entry.playerId;
      if (!id) { res.note = 'Pelaajan NHL-tunnusta ei ole vielä haettu. Paina Päivitä ja avaa pelaaja uudelleen.'; return res; }
      const j = await getJSON(`https://api-web.nhle.com/v1/player/${id}/game-log/now`);
      if (!j) { res.note = 'Ottelulokin haku epäonnistui.'; return res; }
      res.games = (j.gameLog || []).slice(0, 5).map(g => ({ date: g.gameDate || '', opponent: g.opponentAbbrev || '?', home: g.homeRoadFlag ? g.homeRoadFlag === 'H' : null, goals: g.goals || 0, assists: g.assists || 0, shots: g.shots ?? null, pp: g.powerPlayPoints ?? null }));
      if (!res.games.length) res.note = 'Ei pelattuja otteluja tällä kaudella.';
    } else if (p.league === 'SM-liiga') {
      const L = this.state.liveLiiga || {}; const mine = (L.recent && L.recent[norm(p.name)]) || [];
      const teamList = L.teamRecent && L.teamRecent[p.team];
      const gid = g => g.date + g.opponent;
      if (teamList && teamList.length) {
        res.games = teamList.map(tg => mine.find(m => gid(m) === gid(tg)) || tg);
        res.note = 'Liiga: joukkueen viimeiset 5 ottelua. Rajapinta ei kerro, pelasiko pelaaja kaikissa, joten pisteetön ottelu voi olla myös poissaolo.';
      } else { res.games = mine; res.note = mine.length ? 'Paina Päivitä nähdäksesi myös pisteettömät ottelut.' : 'Ei pisteotteluja tällä kaudella (tai Liigaa ei ole vielä päivitetty).'; }
    } else if (p.league === 'Mestis') {
      const e = this.state.liveMestis && (this.state.liveMestis.byName[norm(p.name)] || [])[0];
      if (e && e.link) { const g = await fetchMestisGameLog(e.link, p.team); if (g) { res.games = g; if (!g.length) res.note = 'Ei pelattuja otteluja tällä kaudella.'; } else res.note = 'Ottelulokin haku epäonnistui.'; }
      else res.note = 'Pelaajan sivua ei ole vielä haettu. Paina Päivitä ja avaa pelaaja uudelleen.';
    } else res.note = 'Pelikohtaisia tietoja ei ole saatavilla tälle sarjalle.';
    if (!res.note || res.games.length) this.recentCache[p.id] = { t: Date.now(), v: res };
    return res;
  },

  // ----- Ilmoitukset -----
  checkScoringNotifications() {
    const snap = {}; const fired = [];
    for (const p of this.players) {
      const g = p.goals || 0, a = p.assists || 0; snap[p.id] = [g, a];
      const old = this.scoreBaseline[p.id];
      if (!this.notifyArmed || !this.settings.notifyEnabled || !old || this.rating(p.id) < this.settings.notifyMinStars || !(g > old[0] || a > old[1])) continue;
      fired.push([p, Math.max(0, g - old[0]), Math.max(0, a - old[1])]);
    }
    this.scoreBaseline = snap;
    if (fired.length && this.settings.notifySound) Sound.play();
    for (const [p, dg, da] of fired) {
      const what = dg > 0 && da > 0 ? 'Maali ja syöttö' : dg > 0 ? (dg > 1 ? `${dg} maalia` : 'Maali') : (da > 1 ? `${da} syöttöä` : 'Syöttö');
      try { new Notification(`${what}: ${p.name}`, { body: `${p.team} · ${playerPoints(p) ?? 0} p (${p.goals || 0}+${p.assists || 0})`, silent: true }); } catch {}
    }
  },

  flash(msg) { this.toast = msg; this.emit('toast'); clearTimeout(this._tt); this._tt = setTimeout(() => { if (this.toast === msg) { this.toast = null; this.emit('toast'); } }, 2500); },
};

function storedFrom(p) {
  return { id: p.id, name: p.name, team: p.team, league: p.league, flag: p.flag, teamLogo: null, pos: p.pos, nat: p.nat, born: p.born, shoots: p.shoots, games: p.games, goals: p.goals, assists: p.assists, pim: p.pim, plusMinus: p.plusMinus };
}

// ---------- Ääni ----------
const Sound = {
  audio: null, name: null,
  async load() { const s = await native.loadSound(); if (s) { this.audio = new Audio(`data:${s.mime};base64,${s.data}`); this.name = s.name; } else { this.audio = null; this.name = null; } },
  async setFromFile() {
    const f = await native.openAudio(); if (!f) return null;
    const ok = await native.saveSound(f.name, f.data); if (!ok) return false;
    await this.load(); return this.audio ? true : false;
  },
  async clear() { await native.clearSound(); this.audio = null; this.name = null; },
  play() {
    if (this.audio) { try { this.audio.currentTime = 0; this.audio.play(); return; } catch {} }
    try {
      const ctx = new (window.AudioContext || window.webkitAudioContext)();
      [880, 1175].forEach((f, i) => { const o = ctx.createOscillator(), g = ctx.createGain(); o.frequency.value = f; o.type = 'sine'; o.connect(g); g.connect(ctx.destination); const t = ctx.currentTime + i * 0.16; g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.3, t + 0.02); g.gain.exponentialRampToValueAtTime(0.0001, t + 0.18); o.start(t); o.stop(t + 0.2); });
    } catch {}
  },
};
