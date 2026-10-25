'use strict';
// ---------- Apurit ----------
const norm = s => String(s || '').normalize('NFD').replace(/\p{M}/gu, '').toLowerCase().replace(/[^\p{L}]/gu, ' ').split(' ').filter(Boolean).join(' ');
const liigaKey = name => { const n = norm(name); return n === 'k espoo' ? 'kiekko espoo' : n; };
const mestisKey = s => String(s || '').normalize('NFD').replace(/\p{M}/gu, '').toLowerCase().replace(/[^\p{L}\p{N}]/gu, '');
const num = v => (v === null || v === undefined) ? '–' : String(v);
const signed = v => (v === null || v === undefined) ? '–' : (v > 0 ? '+' + v : String(v));
const ppgString = v => (v === null || v === undefined) ? '–' : v.toFixed(2).replace('.', ',');
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const sleep = ms => new Promise(r => setTimeout(r, ms));
const timeString = d => { const x = new Date(d); return String(x.getHours()).padStart(2, '0') + ':' + String(x.getMinutes()).padStart(2, '0'); };
const toInt = v => { if (v === null || v === undefined || v === '') return null; const n = parseInt(String(v).replace('+', '').trim(), 10); return Number.isNaN(n) ? null : n; };

function tzOffset(ts, tz) {
  const p = new Intl.DateTimeFormat('en-US', { timeZone: tz, hourCycle: 'h23', year: 'numeric', month: 'numeric', day: 'numeric', hour: 'numeric', minute: 'numeric', second: 'numeric' }).formatToParts(new Date(ts));
  const g = t => +p.find(x => x.type === t).value;
  return Date.UTC(g('year'), g('month') - 1, g('day'), g('hour'), g('minute'), g('second')) - Math.floor(ts / 1000) * 1000;
}
function zonedToDate(y, mo, d, h, mi, tz) {
  const utc = Date.UTC(y, mo - 1, d, h, mi);
  const o1 = tzOffset(utc, tz);
  const o2 = tzOffset(utc - o1, tz);
  return new Date(utc - o2);
}
const dayStr = (date, tz) => new Intl.DateTimeFormat('en-CA', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit' }).format(date);

async function fetchRaw(url, { timeout = 15000, headers } = {}) {
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), timeout);
  try {
    const r = await fetch(url, { cache: 'no-store', signal: ctl.signal, headers });
    return r;
  } catch { return null; } finally { clearTimeout(t); }
}
async function getJSON(url, timeout = 15000) {
  const r = await fetchRaw(url, { timeout });
  if (!r || r.status !== 200) return null;
  try { return await r.json(); } catch { return null; }
}
async function getText(url, timeout = 25000) {
  const r = await fetchRaw(url, { timeout });
  if (!r || r.status !== 200) return null;
  try { return await r.text(); } catch { return null; }
}
async function pool(items, limit, fn) {
  const out = []; let i = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (i < items.length) { const k = i++; out[k] = await fn(items[k]); }
  });
  await Promise.all(workers); return out;
}

// ---------- Maat ----------
const COUNTRIES = {
  SWE: ['🇸🇪', 'Ruotsi'], FIN: ['🇫🇮', 'Suomi'], USA: ['🇺🇸', 'USA'], CAN: ['🇨🇦', 'Kanada'], RUS: ['🇷🇺', 'Venäjä'], CZE: ['🇨🇿', 'Tsekki'],
  SVK: ['🇸🇰', 'Slovakia'], CHE: ['🇨🇭', 'Sveitsi'], DEU: ['🇩🇪', 'Saksa'], DNK: ['🇩🇰', 'Tanska'], NOR: ['🇳🇴', 'Norja'], LVA: ['🇱🇻', 'Latvia'],
  AUT: ['🇦🇹', 'Itävalta'], BLR: ['🇧🇾', 'Valko-Venäjä'], UKR: ['🇺🇦', 'Ukraina'], FRA: ['🇫🇷', 'Ranska'], GBR: ['🇬🇧', 'Britannia'],
  SVN: ['🇸🇮', 'Slovenia'], AUS: ['🇦🇺', 'Australia'], JPN: ['🇯🇵', 'Japani'], KAZ: ['🇰🇿', 'Kazakstan'], LTU: ['🇱🇹', 'Liettua'], POL: ['🇵🇱', 'Puola'],
  NLD: ['🇳🇱', 'Hollanti'], ITA: ['🇮🇹', 'Italia'], HUN: ['🇭🇺', 'Unkari'], EST: ['🇪🇪', 'Viro'], BHS: ['🇧🇸', 'Bahama'], JAM: ['🇯🇲', 'Jamaika'],
  NGA: ['🇳🇬', 'Nigeria'], BRA: ['🇧🇷', 'Brasilia'], KOR: ['🇰🇷', 'Etelä-Korea'], HRV: ['🇭🇷', 'Kroatia'], ROU: ['🇷🇴', 'Romania'], ISL: ['🇮🇸', 'Islanti'], DEN: ['🇩🇰', 'Tanska'],
};
function natLabel(nat) {
  if (!nat) return '–';
  const c = COUNTRIES[nat.toUpperCase()];
  if (c) return c[0] + ' ' + c[1];
  const f = Object.values(COUNTRIES).find(v => v[1].toLowerCase() === nat.toLowerCase());
  return f ? f[0] + ' ' + f[1] : nat;
}

// ---------- Sarjat ----------
const LEAGUES = [
  { id: 'NHL', label: 'NHL', flags: '🇺🇸 🇨🇦' }, { id: 'AHL', label: 'AHL', flags: '🇺🇸 🇨🇦' },
  { id: 'SM-liiga', label: 'Liiga', flags: '🇫🇮' }, { id: 'Mestis', label: 'Mestis', flags: '🇫🇮' },
  { id: 'SHL', label: 'SHL', flags: '🇸🇪' }, { id: 'HockeyAllsvenskan', label: 'HockeyAllsvenskan', flags: '🇸🇪' },
];
const leagueLabel = id => (LEAGUES.find(l => l.id === id) || {}).label || id;
const leagueFlag = id => ((LEAGUES.find(l => l.id === id) || {}).flags || '').split(' ')[0];

// ---------- NHL ----------
async function fetchNHLTeam(team) {
  const j = await getJSON(`https://api-web.nhle.com/v1/club-stats/${team.abbr}/now`);
  return j && j.skaters ? { team, skaters: j.skaters } : null;
}
async function fetchNHLRoster(abbr) {
  const j = await getJSON(`https://api-web.nhle.com/v1/roster/${abbr}/current`);
  return j ? [...(j.forwards || []), ...(j.defensemen || []), ...(j.goalies || [])] : [];
}
async function nhlHotCheck(key, id) {
  const j = await getJSON(`https://api-web.nhle.com/v1/player/${id}/game-log/now`);
  if (!j) return null;
  const last4 = (j.gameLog || []).slice(0, 4);
  return [key, last4.length === 4 && last4.every(g => (g.goals || 0) + (g.assists || 0) >= 1)];
}
async function nhlHasLiveGames() {
  const j = await getJSON('https://api-web.nhle.com/v1/schedule/now', 10000);
  if (!j || !j.gameWeek) return false;
  return j.gameWeek.some(d => (d.games || []).some(g => ['LIVE', 'CRIT'].includes(String(g.gameState || '').toUpperCase())));
}
async function fetchNHLPowerPlay() {
  const j = await getJSON('https://api.nhle.com/stats/rest/en/skater/summary?limit=-1&cayenneExp=seasonId=20262027%20and%20gameTypeId=2', 20000);
  const out = {};
  for (const r of (j && j.data) || []) if (r.playerId != null && r.ppPoints != null) out[r.playerId] = r.ppPoints;
  return out;
}

// ---------- Liiga ----------
const fx = v => { if (v === null || v === undefined) return null; if (typeof v === 'number') return Math.trunc(v); const n = parseInt(v, 10); return Number.isNaN(n) ? null : n; };
const flexBool = v => typeof v === 'boolean' ? v : typeof v === 'string' ? v !== '' : typeof v === 'number';
const personName = p => p ? [p.firstName, p.lastName].filter(Boolean).join(' ') : '';
const personJersey = p => p ? (fx(p.jersey) ?? fx(p.jerseyNumber) ?? fx(p.number) ?? fx(p.shirtNumber)) : null;
const rinkName = r => r == null ? null : typeof r === 'string' ? r : (r.name || null);
async function fetchLiigaGames() {
  const j = await getJSON('https://liiga.fi/api/v2/games?tournament=runkosarja&season=2027', 30000);
  return Array.isArray(j) ? j : null;
}
async function liigaHasLiveGames() {
  const j = await getJSON(`https://liiga.fi/api/v2/games?tournament=runkosarja&date=${dayStr(new Date(), 'Europe/Helsinki')}`, 10000);
  if (!Array.isArray(j)) return false;
  return j.some(g => flexBool(g.started) && !flexBool(g.ended));
}
async function fetchLiigaPlayerStats() {
  const j = await getJSON('https://liiga.fi/api/v2/players/stats/summed/2027/2027/runkosarja/true?dataType=basicStats', 25000);
  return Array.isArray(j) ? j.filter(s => s.goalkeeper !== true && s.role !== 'M') : null;
}
function liigaDetail(g) {
  const d = { goals: [], rink: null, spectators: null, homePP: null, awayPP: null, resultNote: null };
  for (const [isHome, team] of [[true, g.homeTeam], [false, g.awayTeam]]) {
    for (const ev of (team && team.goalEvents) || []) {
      d.goals.push({
        seconds: fx(ev.gameTime) || 0, period: fx(ev.period) || 0, home: isHome,
        scorer: personName(ev.scorerPlayer) || '?',
        assists: (ev.assistantPlayers || []).map(personName).filter(Boolean),
        homeScore: fx(ev.homeTeamScore), awayScore: fx(ev.awayTeamScore),
        powerPlay: (ev.goalTypes || []).some(t => String(t).toUpperCase().startsWith('YV')),
      });
    }
  }
  d.goals.sort((a, b) => a.seconds - b.seconds);
  d.rink = rinkName(g.iceRink); d.spectators = fx(g.spectators);
  const pp = t => { const inst = t ? fx(t.powerplayInstances) : null; return inst == null ? null : `${fx(t.powerplayGoals) || 0}/${inst}`; };
  d.homePP = pp(g.homeTeam); d.awayPP = pp(g.awayTeam);
  const ft = String(g.finishedType || '').toLowerCase();
  if (ft.includes('shootout')) d.resultNote = 'Ratkesi rankkarikisassa';
  else if (ft.includes('extended') || ft.includes('overtime')) d.resultNote = 'Ratkesi jatkoajalla';
  return d;
}

// ---------- Elite Prospects ----------
async function fetchEPLeague(slug, key, season = '2026-2027') {
  let all = [];
  for (let page = 0; page < 5; page++) {
    const url = `https://api.eliteprospects.com/v1/leagues/${slug}/player-stats?season=${season}&limit=1000&offset=${page * 1000}&fields=${encodeURIComponent('player,team,regularStats.GP,regularStats.G,regularStats.A,regularStats.PIM,regularStats.PM')}&apiKey=${encodeURIComponent(key)}`;
    const r = await fetchRaw(url, { timeout: 30000 });
    if (!r) return { rows: page === 0 ? null : all, error: 'ei vastausta' };
    if (r.status !== 200) { let b = ''; try { b = (await r.text()).slice(0, 160).replace(/\n/g, ' '); } catch {} return { rows: page === 0 ? null : all, error: `HTTP ${r.status} ${b}` }; }
    let j; try { j = await r.json(); } catch (e) { return { rows: page === 0 ? null : all, error: 'vastauksen luku epäonnistui' }; }
    const rows = j.data || []; all = all.concat(rows);
    if (rows.length < 1000) break;
  }
  return { rows: all, error: all.length ? null : 'tyhjä vastaus (ei pelaajia kaudelle 2026-2027)' };
}

// ---------- AHL ----------
async function ahlFetch(query) {
  const j = await getJSON('https://lscluster.hockeytech.com/feed/index.php?feed=modulekit&key=ccb91f29d6744675&fmt=json&client_code=ahl&lang=en&' + query, 20000);
  if (!j || !j.SiteKit) return null;
  const k = j.SiteKit;
  const rows = k.Statviewtype || k.Seasons || k.Teamsbyseason || k.Schedule || [];
  return rows.map(r => { const o = {}; for (const [a, b] of Object.entries(r)) if (typeof b === 'string' || typeof b === 'number') o[a] = String(b); return o; });
}
async function fetchAHLSeasonId() {
  const rows = await ahlFetch('view=seasons'); if (!rows) return '94';
  const reg = rows.filter(r => r.career === '1' && r.playoff === '0');
  const named = reg.filter(r => (r.season_name || '').includes('Regular'));
  const list = named.length ? named : reg;
  let best = null;
  for (const r of list) { const n = parseInt(r.season_id, 10); if (!Number.isNaN(n) && (!best || n > best[0])) best = [n, r.season_id]; }
  return best ? best[1] : '94';
}
async function fetchAHLTeams(season) {
  const rows = await ahlFetch(`view=teamsbyseason&season_id=${season}`) || [];
  return rows.filter(r => r.id && r.name).map(r => ({ id: r.id, name: r.name, code: r.code || '', logo: r.team_logo_url }));
}
async function fetchAHLSkaters(season, teamIDs) {
  let any = false, all = [];
  const res = await pool(teamIDs, 8, id => ahlFetch(`view=statviewtype&type=skaters&season_id=${season}&team_id=${id}&limit=100&first=0&sort=points`));
  for (const rows of res) {
    if (!rows) continue; any = true;
    for (const r of rows) {
      const name = r.name || r.shortname, team = r.team_name; if (!name || !team) continue;
      all.push({ id: toInt(r.player_id), name, team, code: r.team_code || '', pos: (r.position || '').toUpperCase(), number: toInt(r.jersey_number),
        games: toInt(r.games_played) || 0, goals: toInt(r.goals) || 0, assists: toInt(r.assists) || 0, pim: toInt(r.penalty_minutes), plusMinus: toInt(r.plus_minus), shots: toInt(r.shots), ppPoints: toInt(r.power_play_points) });
    }
  }
  return any ? all : null;
}
async function ahlHasLiveGames() {
  const rows = await ahlFetch('view=schedule&season_id=94');
  return !!rows && rows.some(r => r.started === '1' && r.final !== '1');
}

// ---------- Mestis ----------
const MESTIS_BASE = 'https://mestis.fi';
const MESTIS_LOGOS = {
  'Hermes': '/media/team-logos/hermes.png.150x150_q85.png', 'IPK': '/media/team-logos/ipk.png.150x150_q85.png',
  'JoKP': '/media/team-logos/kiekkopojat.png.150x150_q85.png', 'Ketterä': '/media/team-logos/kettera.png.150x150_q85.png',
  'KeuPa HT': '/media/team-logos/keupa_elAJWhB.png.150x150_q85.png', 'K-Vantaa': '/media/team-logos/kiekko-vantaa.png.150x150_q85.png',
  'Pyry': '/media/team-logos/Pyry_Hockey_Logo.png.150x150_q85.png', 'RoKi': '/media/team-logos/roki_new.png.150x150_q85.png',
  'TUTO Hockey': '/media/team-logos/tuto.png.150x150_q85.png',
};
function mestisResolve(name, teams) {
  const seed = teams.filter(t => t.league === 'Mestis');
  const k = mestisKey(name);
  let t = seed.find(t => mestisKey(t.name) === k); if (t) return t.name;
  const alias = { kiekkopojat: 'jokp', kiekkovantaa: 'kvantaa', tuto: 'tutohockey', keupa: 'keupaht' }[k];
  if (alias) { t = seed.find(t => mestisKey(t.name) === alias); if (t) return t.name; }
  return null;
}
const mestisClean = s => String(s || '').replace(/\s+/g, ' ').trim();
const mestisHTML = path => getText(MESTIS_BASE + path, 25000);
function mestisTable(html, id) {
  const doc = new DOMParser().parseFromString(html, 'text/html');
  const t = doc.getElementById(id); if (!t) return [];
  const rows = [];
  for (const tr of t.querySelectorAll('tbody tr, tr')) {
    if (rows.some(r => r.tr === tr)) continue;
    const tds = [...tr.querySelectorAll(':scope > td')];
    if (!tds.length) continue;
    rows.push({ tr, cells: tds.map(td => mestisClean(td.textContent)), tds });
  }
  return rows;
}
const mInt = s => s == null ? null : toInt(s);
async function fetchMestisSkaters() {
  const html = await mestisHTML('/fi/tilastot/pelaajat/'); if (!html) return null;
  const out = [];
  for (const r of mestisTable(html, 'stats')) {
    if (r.cells.length < 16) continue;
    const pos = r.cells[3]; if (pos === 'MV') continue;
    let name = r.cells[1]; const ci = name.indexOf(', ');
    if (ci >= 0) name = name.slice(ci + 2) + ' ' + name.slice(0, ci);
    let id = null, link = null;
    const a = r.tds[1].querySelector('a[href*="/pelaajat/"]');
    if (a) { const h = a.getAttribute('href'); const m = h.match(/\/pelaajat\/(\d+)/); if (m) id = +m[1]; if (h.startsWith('/fi/pelaajat/')) link = h.replace(/\/$/, ''); }
    out.push({ id, name, team: r.cells[2], pos, games: mInt(r.cells[4]) || 0, goals: mInt(r.cells[5]) || 0, assists: mInt(r.cells[6]) || 0, pim: mInt(r.cells[8]), plusMinus: mInt(r.cells[11]), shots: mInt(r.cells[15]), link });
  }
  return out.length ? out : null;
}
async function fetchMestisStandings(teams) {
  const html = await mestisHTML('/fi/tilastot/joukkueet/'); if (!html) return null;
  const out = [];
  for (const r of mestisTable(html, 'stats')) {
    if (r.cells.length < 9) continue;
    const team = mestisResolve(r.cells[1], teams); if (!team) continue;
    const v = mInt(r.cells[3]) || 0, jav = mInt(r.cells[4]) || 0;
    out.push({ team, gp: mInt(r.cells[2]) || 0, w: v + jav, l: mInt(r.cells[6]) || 0, otl: mInt(r.cells[5]) || 0, pts: mInt(r.cells[9]) || 0, gf: mInt(r.cells[7]) || 0, ga: mInt(r.cells[8]) || 0, group: '' });
  }
  return out.length ? out : null;
}
async function fetchMestisSchedule(teams) {
  const html = await mestisHTML('/fi/ottelut/'); if (!html) return null;
  const out = [];
  for (const r of mestisTable(html, 'games')) {
    if (r.cells.length < 6) continue;
    const day = r.tr.getAttribute('data-time'); if (!day || !/^\d{8}$/.test(day)) continue;
    const tm = r.cells[2].match(/(\d{1,2}):(\d{2})/); if (!tm) continue;
    const date = zonedToDate(+day.slice(0, 4), +day.slice(4, 6), +day.slice(6, 8), +tm[1], +tm[2], 'Europe/Helsinki');
    const parts = r.cells[3].split(' - '); if (parts.length !== 2) continue;
    const h = mestisResolve(parts[0], teams), a = mestisResolve(parts[1], teams); if (!h || !a) continue;
    let hs = null, aw = null;
    const sm = r.cells[5].match(/(\d+) ?[—–-] ?(\d+)/); if (sm) { hs = +sm[1]; aw = +sm[2]; }
    const link = r.tds[3].querySelector('a[href*="/runkosarja/"]'); const gm = link && link.getAttribute('href').match(/\/runkosarja\/(\d+)/);
    const recent = Date.now() - date.getTime() < 2.5 * 3600 * 1000;
    out.push({ id: 'mestis-' + (gm ? gm[1] : out.length), date, home: h, away: a, live: hs !== null && recent, final: hs !== null && !recent, homeScore: hs, awayScore: aw });
  }
  return out.length ? out : null;
}
async function fetchMestisGameLog(link, team) {
  const html = await mestisHTML(link + '/ottelu-ottelulta'); if (!html) return null;
  const doc = new DOMParser().parseFromString(html, 'text/html');
  const games = [];
  for (const tr of doc.querySelectorAll('tr')) {
    const c = [...tr.querySelectorAll(':scope > td')].map(td => mestisClean(td.textContent));
    if (c.length < 13 || !/^\d{1,2}\.\d{1,2}\.\d{4}$/.test(c[0])) continue;
    const [d, m, y] = c[0].split('.').map(Number);
    const date = zonedToDate(y, m, d, 12, 0, 'Europe/Helsinki'); if (date.getTime() > Date.now()) continue;
    const parts = c[1].split(' - '); if (parts.length !== 2) continue;
    const isHome = mestisKey(parts[0]) === mestisKey(team);
    games.push([date, { date: `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`, opponent: isHome ? parts[1] : parts[0], home: isHome, goals: mInt(c[2]) || 0, assists: mInt(c[3]) || 0, shots: mInt(c[12]), pp: null }]);
  }
  return games.sort((a, b) => b[0] - a[0]).slice(0, 5).map(x => x[1]);
}
async function fetchMestisPlayerInfo(link) {
  const html = await mestisHTML(link); if (!html) return null;
  let number = null, nat = null;
  const t = html.match(/<title>([^<]*)<\/title>/i); if (t) { const m = t[1].match(/#(\d+)/); if (m) number = +m[1]; }
  const n = html.match(/Kansalaisuus\s*<\/th>\s*<td[^>]*>\s*([A-Za-z]{3})/); if (n) nat = n[1].toUpperCase();
  return { number, nat };
}

// ---------- Sarjataulukot ----------
const standDiff = r => r.gf - r.ga;
function sortStandings(rows) {
  return rows.slice().sort((a, b) => b.pts - a.pts || a.gp - b.gp || standDiff(b) - standDiff(a) || b.gf - a.gf);
}
async function fetchNHLStandings(teams) {
  const j = await getJSON('https://api-web.nhle.com/v1/standings/now'); if (!j || !j.standings) return null;
  const byAbbr = Object.fromEntries(teams.filter(t => t.league === 'NHL').map(t => [t.abbr, t.name]));
  return j.standings.map(s => {
    const name = byAbbr[s.teamAbbrev && s.teamAbbrev.default]; if (!name) return null;
    return { team: name, gp: s.gamesPlayed || 0, w: s.wins || 0, l: s.losses || 0, otl: s.otLosses || 0, pts: s.points || 0, gf: s.goalFor || 0, ga: s.goalAgainst || 0, group: `${s.conferenceName || ''}|${s.divisionName || ''}` };
  }).filter(Boolean);
}
async function fetchAHLStandings(teams, season) {
  const rows = await ahlFetch(`view=statviewtype&type=standings&stat=overall&season_id=${season}&groupTeamsBy=division`); if (!rows) return null;
  const seed = teams.filter(t => t.league === 'AHL');
  const byName = Object.fromEntries(seed.map(t => [norm(t.name), t.name])), byAbbr = Object.fromEntries(seed.map(t => [t.abbr, t.name]));
  const out = [];
  for (const r of rows) {
    if (!r.team_id) continue;
    const team = (r.name && byName[norm(r.name)]) || (r.team_code && byAbbr[r.team_code]); if (!team) continue;
    const gp = toInt(r.games_played) || 0, w = toInt(r.wins) || 0, otl = (toInt(r.ot_losses) || 0) + (toInt(r.shootout_losses) || 0);
    out.push({ team, gp, w, l: Math.max(0, gp - w - otl), otl, pts: toInt(r.points) || 0, gf: toInt(r.goals_for) || 0, ga: toInt(r.goals_against) || 0, group: `${r.conference_name || ''}|${r.division_name || r.divisname || ''}` });
  }
  return out.length ? out : null;
}
async function fetchLiigaStandings(teams) {
  const games = await fetchLiigaGames(); if (!games) return null;
  const lt = teams.filter(t => t.league === 'SM-liiga');
  const seedByKey = Object.fromEntries(lt.map(t => [liigaKey(t.name), t.name]));
  const table = Object.fromEntries(lt.map(t => [t.name, { team: t.name, gp: 0, w: 0, l: 0, otl: 0, pts: 0, gf: 0, ga: 0, group: '' }]));
  for (const g of games) {
    if (!flexBool(g.ended)) continue;
    const h = g.homeTeam, a = g.awayTeam; if (!h || !a) continue;
    const hn = seedByKey[liigaKey(h.teamName || '')], an = seedByKey[liigaKey(a.teamName || '')]; if (!hn || !an) continue;
    const hg = h.goals ?? (h.goalEvents || []).length, ag = a.goals ?? (a.goalEvents || []).length;
    const ft = String(g.finishedType || '').toLowerCase();
    const extra = ft.includes('extended') || ft.includes('overtime') || ft.includes('shootout');
    const hr = table[hn], ar = table[an];
    hr.gp++; ar.gp++; hr.gf += hg; hr.ga += ag; ar.gf += ag; ar.ga += hg;
    if (hg > ag) { hr.w++; hr.pts += extra ? 2 : 3; if (extra) { ar.otl++; ar.pts++; } else ar.l++; }
    else if (ag > hg) { ar.w++; ar.pts += extra ? 2 : 3; if (extra) { hr.otl++; hr.pts++; } else hr.l++; }
  }
  return Object.values(table);
}

// ---------- Otteluohjelmat ----------
async function fetchAHLSchedule(teams) {
  const byCode = Object.fromEntries(teams.filter(t => t.league === 'AHL').map(t => [t.abbr, t.name]));
  const season = await fetchAHLSeasonId();
  const rows = await ahlFetch(`view=schedule&season_id=${season}`); if (!rows) return null;
  const out = [];
  for (const r of rows) {
    const h = byCode[r.home_team_code], a = byCode[r.visiting_team_code], d = r.GameDateISO8601 ? new Date(r.GameDateISO8601) : null;
    if (!h || !a || !d || isNaN(d)) continue;
    const fin = r.final === '1', started = r.started === '1';
    out.push({ id: 'ahl-' + (r.game_id || out.length), date: d, home: h, away: a, live: started && !fin, final: fin, homeScore: toInt(r.home_goal_count), awayScore: toInt(r.visiting_goal_count) });
  }
  return out;
}
async function fetchNHLSchedule(teams) {
  const byAbbr = Object.fromEntries(teams.filter(t => t.league === 'NHL').map(t => [t.abbr, t.name]));
  const out = []; let path = dayStr(new Date(Date.now() - 2 * 86400000), 'America/New_York'); let got = false;
  for (let i = 0; i < 3; i++) {
    const j = await getJSON(`https://api-web.nhle.com/v1/schedule/${path}`); if (!j) break;
    got = true;
    for (const day of j.gameWeek || []) for (const g of day.games || []) {
      const st = String(g.gameState || '').toUpperCase();
      const d = g.startTimeUTC ? new Date(g.startTimeUTC) : null;
      const h = g.homeTeam && byAbbr[g.homeTeam.abbrev], a = g.awayTeam && byAbbr[g.awayTeam.abbrev];
      if (!d || !h || !a) continue;
      out.push({ id: 'nhl-' + (g.id ?? out.length), date: d, home: h, away: a, live: st === 'LIVE' || st === 'CRIT', gameId: g.id, final: st === 'FINAL' || st === 'OFF', homeScore: g.homeTeam.score ?? null, awayScore: g.awayTeam.score ?? null });
    }
    if (!j.nextStartDate) break; path = j.nextStartDate;
  }
  return got ? out : null;
}
async function fetchLiigaSchedule(teams) {
  const games = await fetchLiigaGames(); if (!games) return null;
  const seedByKey = Object.fromEntries(teams.filter(t => t.league === 'SM-liiga').map(t => [liigaKey(t.name), t.name]));
  const now = Date.now(); const out = [];
  games.forEach((g, i) => {
    const d = g.start ? new Date(g.start) : null; const ht = g.homeTeam, at = g.awayTeam;
    if (!d || isNaN(d) || !ht || !at) return;
    const h = seedByKey[liigaKey(ht.teamName || '')], a = seedByKey[liigaKey(at.teamName || '')]; if (!h || !a) return;
    const ended = flexBool(g.ended), started = flexBool(g.started);
    if (ended && d.getTime() < now - 48 * 3600000) return;
    const game = { id: 'liiga-' + (fx(g.id) ?? i), date: d, home: h, away: a, live: false, final: false, homeScore: null, awayScore: null, liiga: null };
    if (ended || started) {
      game.final = ended; game.live = !ended;
      game.homeScore = ht.goals ?? (ht.goalEvents || []).length; game.awayScore = at.goals ?? (at.goalEvents || []).length;
      game.liiga = liigaDetail(g);
    }
    out.push(game);
  });
  return out;
}
async function fetchBoxscore(id) { return await getJSON(`https://api-web.nhle.com/v1/gamecenter/${id}/boxscore`); }

// ---------- Joukkueen viimeisimmät tulokset ----------
// Palauttaa { games: [{date, opponent, home, gf, ga, win, extra}], note } (uusin ensin, enintään 5)
async function fetchTeamResults(teamName, teams) {
  const team = teams.find(t => t.name === teamName); const L = team && team.league;
  const mk = (date, opponent, home, gf, ga, extra, game) => ({ date, opponent, home, gf, ga, win: gf > ga, extra, game: game || null });
  const finish = list => list.sort((a, b) => b.date - a.date).slice(0, 5);
  if (!team) return { games: [], note: 'Omalle joukkueelle ei ole tuloksia.' };
  if (L === 'NHL') {
    const j = await getJSON(`https://api-web.nhle.com/v1/club-schedule-season/${team.abbr}/now`, 20000);
    if (!j || !j.games) return null;
    const byAbbr = Object.fromEntries(teams.filter(t => t.league === 'NHL').map(t => [t.abbr, t.name]));
    const out = [];
    for (const g of j.games) {
      const st = String(g.gameState || '').toUpperCase(); if (st !== 'FINAL' && st !== 'OFF') continue;
      const home = g.homeTeam && g.homeTeam.abbrev === team.abbr; const own = home ? g.homeTeam : g.awayTeam, opp = home ? g.awayTeam : g.homeTeam;
      if (!own || !opp || own.score == null || opp.score == null) continue;
      const lp = g.gameOutcome && g.gameOutcome.lastPeriodType;
      out.push(mk(new Date(g.startTimeUTC), byAbbr[opp.abbrev] || opp.abbrev, home, own.score, opp.score, lp === 'SO' ? 'RL' : lp === 'OT' ? 'JA' : null,
        { id: 'nhl-' + g.id, date: new Date(g.startTimeUTC), home: home ? team.name : (byAbbr[opp.abbrev] || opp.abbrev), away: home ? (byAbbr[opp.abbrev] || opp.abbrev) : team.name, gameId: g.id, final: true, live: false, homeScore: home ? own.score : opp.score, awayScore: home ? opp.score : own.score, liiga: null }));
    }
    return { games: finish(out), note: null };
  }
  if (L === 'AHL') {
    const season = await fetchAHLSeasonId(); const rows = await ahlFetch(`view=schedule&season_id=${season}`); if (!rows) return null;
    const byCode = Object.fromEntries(teams.filter(t => t.league === 'AHL').map(t => [t.abbr, t.name]));
    const out = [];
    for (const r of rows) {
      if (r.final !== '1') continue; const h = byCode[r.home_team_code], a = byCode[r.visiting_team_code]; if (!h || !a || (h !== teamName && a !== teamName)) continue;
      const home = h === teamName; const hs = toInt(r.home_goal_count), as = toInt(r.visiting_goal_count); if (hs == null || as == null) continue;
      const extra = r.shootout === '1' ? 'RL' : r.overtime === '1' ? 'JA' : null;
      out.push(mk(new Date(r.GameDateISO8601), home ? a : h, home, home ? hs : as, home ? as : hs, extra));
    }
    return { games: finish(out), note: null };
  }
  if (L === 'SM-liiga') {
    const games = await fetchLiigaGames(); if (!games) return null;
    const seedByKey = Object.fromEntries(teams.filter(t => t.league === 'SM-liiga').map(t => [liigaKey(t.name), t.name]));
    const out = [];
    for (const g of games) {
      if (!flexBool(g.ended) || !g.homeTeam || !g.awayTeam || !g.start) continue;
      const h = seedByKey[liigaKey(g.homeTeam.teamName || '')], a = seedByKey[liigaKey(g.awayTeam.teamName || '')]; if (!h || !a || (h !== teamName && a !== teamName)) continue;
      const home = h === teamName; const hs = g.homeTeam.goals ?? (g.homeTeam.goalEvents || []).length, as = g.awayTeam.goals ?? (g.awayTeam.goalEvents || []).length;
      const ft = String(g.finishedType || '').toLowerCase(); const extra = ft.includes('shootout') ? 'RL' : (ft.includes('extended') || ft.includes('overtime')) ? 'JA' : null;
      out.push(mk(new Date(g.start), home ? a : h, home, home ? hs : as, home ? as : hs, extra, { id: 'liiga-' + (fx(g.id) ?? out.length), date: new Date(g.start), home: h, away: a, live: false, final: true, homeScore: hs, awayScore: as, liiga: liigaDetail(g) }));
    }
    return { games: finish(out), note: null };
  }
  if (L === 'Mestis') {
    const games = await fetchMestisSchedule(teams); if (!games) return null;
    const out = games.filter(g => g.final && g.homeScore != null && (g.home === teamName || g.away === teamName)).map(g => { const home = g.home === teamName; return mk(g.date, home ? g.away : g.home, home, home ? g.homeScore : g.awayScore, home ? g.awayScore : g.homeScore, null); });
    return { games: finish(out), note: 'Mestis: sivusto ei kerro jatkoaika- tai rankkaritietoa.' };
  }
  return { games: [], note: 'Ottelutuloksia ei ole saatavilla tälle sarjalle.' };
}

// ---------- Koko sarjan ottelut (kunto- ja yli/alle-taulukot) ----------
// Palauttaa [{date, home, away, final, hs, as, extra}] tai null. extra: 'JA' | 'RL' | null
async function fetchLeagueGames(league, teams) {
  if (league === 'NHL') {
    const nhl = teams.filter(t => t.league === 'NHL'); const byAbbr = Object.fromEntries(nhl.map(t => [t.abbr, t.name]));
    const lists = await pool(nhl, 8, t => getJSON(`https://api-web.nhle.com/v1/club-schedule-season/${t.abbr}/now`, 20000));
    if (!lists.some(Boolean)) return null;
    const seen = new Set(), out = [];
    for (const j of lists) for (const g of (j && j.games) || []) {
      if (seen.has(g.id)) continue; seen.add(g.id);
      const h = g.homeTeam && byAbbr[g.homeTeam.abbrev], a = g.awayTeam && byAbbr[g.awayTeam.abbrev], d = g.startTimeUTC ? new Date(g.startTimeUTC) : null;
      if (!h || !a || !d) continue;
      const st = String(g.gameState || '').toUpperCase(), fin = (st === 'FINAL' || st === 'OFF') && g.homeTeam.score != null && g.awayTeam.score != null;
      const lp = g.gameOutcome && g.gameOutcome.lastPeriodType;
      out.push({ date: d, home: h, away: a, final: fin, hs: fin ? g.homeTeam.score : null, as: fin ? g.awayTeam.score : null, extra: fin ? (lp === 'SO' ? 'RL' : lp === 'OT' ? 'JA' : null) : null });
    }
    return out;
  }
  if (league === 'AHL') {
    const byCode = Object.fromEntries(teams.filter(t => t.league === 'AHL').map(t => [t.abbr, t.name]));
    const rows = await ahlFetch(`view=schedule&season_id=${await fetchAHLSeasonId()}`); if (!rows) return null;
    const out = [];
    for (const r of rows) {
      const h = byCode[r.home_team_code], a = byCode[r.visiting_team_code], d = r.GameDateISO8601 ? new Date(r.GameDateISO8601) : null; if (!h || !a || !d || isNaN(d)) continue;
      const fin = r.final === '1';
      out.push({ date: d, home: h, away: a, final: fin, hs: fin ? toInt(r.home_goal_count) : null, as: fin ? toInt(r.visiting_goal_count) : null, extra: fin ? (r.shootout === '1' ? 'RL' : r.overtime === '1' ? 'JA' : null) : null });
    }
    return out;
  }
  if (league === 'SM-liiga') {
    const games = await fetchLiigaGames(); if (!games) return null;
    const seedByKey = Object.fromEntries(teams.filter(t => t.league === 'SM-liiga').map(t => [liigaKey(t.name), t.name]));
    const out = [];
    for (const g of games) {
      const ht = g.homeTeam, at = g.awayTeam; if (!ht || !at || !g.start) continue;
      const h = seedByKey[liigaKey(ht.teamName || '')], a = seedByKey[liigaKey(at.teamName || '')]; if (!h || !a) continue;
      const fin = flexBool(g.ended), ft = String(g.finishedType || '').toLowerCase();
      out.push({ date: new Date(g.start), home: h, away: a, final: fin, hs: fin ? (ht.goals ?? (ht.goalEvents || []).length) : null, as: fin ? (at.goals ?? (at.goalEvents || []).length) : null, extra: fin ? (ft.includes('shootout') ? 'RL' : (ft.includes('extended') || ft.includes('overtime')) ? 'JA' : null) : null });
    }
    return out;
  }
  const games = await fetchMestisSchedule(teams); if (!games) return null;
  return games.map(g => ({ date: g.date, home: g.home, away: g.away, final: !!g.final && g.homeScore != null, hs: g.final ? g.homeScore : null, as: g.final ? g.awayScore : null, extra: null }));
}

// Laskee jokaiselle joukkueelle kunto-/yli-alle-tiedot. side: 'all' | 'home' | 'away'
function computeTeamForm(games, teamNames, league, side, n, line) {
  const twoWay = league === 'NHL' || league === 'AHL';
  const out = [];
  for (const name of teamNames) {
    const mine = games.filter(g => (side === 'home' ? g.home === name : side === 'away' ? g.away === name : (g.home === name || g.away === name)))
      .sort((a, b) => a.date - b.date);
    const fin = mine.filter(g => g.final), up = mine.filter(g => !g.final);
    const view = g => { const home = g.home === name; return { g, home, gf: home ? g.hs : g.as, ga: home ? g.as : g.hs, opp: home ? g.away : g.home }; };
    const all = fin.map(view);
    const win = n ? all.slice(-n) : all;
    const s = { team: name, gp: win.length, w: 0, otw: 0, otl: 0, l: 0, gf: 0, ga: 0, pts: 0, over: 0, under: 0, tot: 0, form: [], next: up[0] || null };
    for (const x of win) {
      const won = x.gf > x.ga, ex = x.g.extra; s.gf += x.gf; s.ga += x.ga;
      if (won) { if (ex) s.otw++; else s.w++; s.pts += twoWay ? 2 : (ex ? 2 : 3); } else { if (ex) { s.otl++; s.pts += 1; } else s.l++; }
    }
    for (const x of all) { const t = x.gf + x.ga; s.tot += t; if (t > line) s.over++; else s.under++; }
    s.allGp = all.length; s.allGf = all.reduce((a, x) => a + x.gf, 0); s.allGa = all.reduce((a, x) => a + x.ga, 0);
    s.form = all.slice(-5).map(x => ({ win: x.gf > x.ga, over: x.gf + x.ga > line, x }));
    s.form10 = all.slice(-10).map(x => ({ win: x.gf > x.ga, over: x.gf + x.ga > line, x }));
    s.formN = all.slice(-(n || 5)).map(x => ({ win: x.gf > x.ga, over: x.gf + x.ga > line, x }));
    out.push(s);
  }
  return out;
}
