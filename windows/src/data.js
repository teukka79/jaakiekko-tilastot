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
  if (url.startsWith('https://stats.swehockey.se') && window.native && native.httpText) {
    const r = await native.httpText(url, timeout); window.__lastHttp = r && { status: r.status, err: r.err };
    return r && r.text ? r.text : null;
  }
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
  { id: 'National League', label: 'NL', flags: '🇨🇭' },
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
  if (L === 'SHL' || L === 'HockeyAllsvenskan') {
    const games = await fetchSweGames(L, teams); if (!games) return null;
    const out = games.filter(g => g.final && (g.home === teamName || g.away === teamName)).map(g => { const home = g.home === teamName; return mk(g.date, home ? g.away : g.home, home, home ? g.homeScore : g.awayScore, home ? g.awayScore : g.homeScore, g.extra); });
    return { games: finish(out), note: null };
  }
  if (L === 'National League') {
    const games = await fetchNLGames(teams); if (!games) return null;
    const out = games.filter(g => g.final && (g.home === teamName || g.away === teamName)).map(g => { const home = g.home === teamName; return mk(g.date, home ? g.away : g.home, home, home ? g.hs : g.as, home ? g.as : g.hs, g.extra); });
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
  if (league === 'National League') return await fetchNLGames(teams);
  if (league === 'SHL' || league === 'HockeyAllsvenskan') {
    const gs = await fetchSweGames(league, teams); if (!gs) return null;
    return gs.map(g => ({ date: g.date, home: g.home, away: g.away, final: g.final, hs: g.homeScore, as: g.awayScore, extra: g.extra }));
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
    s.form = all.slice(-5).map(x => ({ win: x.gf > x.ga, over: x.gf + x.ga > line, x })).reverse();
    s.form10 = all.slice(-10).map(x => ({ win: x.gf > x.ga, over: x.gf + x.ga > line, x })).reverse();
    s.formN = all.slice(-(n || 5)).map(x => ({ win: x.gf > x.ga, over: x.gf + x.ga > line, x })).reverse();
    out.push(s);
  }
  return out;
}

// ---------- SHL ja HockeyAllsvenskan (stats.swehockey.se) ----------
const SWE_BASE = 'https://stats.swehockey.se';
const SWE_NAMES = { SHL: 'SHL', HockeyAllsvenskan: 'HockeyAllsvenskan' };
const sweKey = s => norm(s).replace(/ /g, '');
function sweResolve(name, teams, league) {
  const seed = teams.filter(t => t.league === league), k = sweKey(name);
  let t = seed.find(t => sweKey(t.name) === k); if (t) return t.name;
  t = seed.find(t => { const a = sweKey(t.name); const [s, l] = a.length < k.length ? [a, k] : [k, a]; return s.length >= 6 && l.includes(s); });
  return t ? t.name : null;
}
const sweCache = {};
// Palauttaa [{id, date, home, away, final, homeScore, awayScore, extra, live:false}] tai null
const sweIds = {};
async function sweLeagueId(league) {
  const c = sweIds[league]; if (c && Date.now() - c.t < 3600000) return c.id;
  const home = await getText(SWE_BASE + '/'); if (!home) return null;
  const doc0 = new DOMParser().parseFromString(home, 'text/html');
  let id = null;
  for (const a of doc0.querySelectorAll('a[href*="/ScheduleAndResults/"]')) {
    if (a.textContent.trim() === SWE_NAMES[league]) { const m = a.getAttribute('href').match(/\/(?:Overview|Schedule|Live)\/(\d+)/); if (m) { id = m[1]; break; } }
  }
  if (id) sweIds[league] = { t: Date.now(), id };
  return id;
}
async function fetchSweGames(league, teams) {
  const c = sweCache[league]; if (c && Date.now() - c.t < 300000) return c.v;
  const id = await sweLeagueId(league); if (!id) return null;
  const html = await getText(`${SWE_BASE}/ScheduleAndResults/Schedule/${id}`, 40000); if (!html) return null;
  const doc = new DOMParser().parseFromString(html, 'text/html');
  const out = []; let day = null;
  for (const tr of doc.querySelectorAll('tr')) {
    const tds = Array.from(tr.children).filter(e => e.tagName === 'TD'); if (tds.length < 8) continue;
    const dm = tds[0].textContent.trim().match(/^(\d{4})-(\d{2})-(\d{2})$/); if (dm) day = dm;
    if (!day) continue;
    const tmEl = tr.querySelector('.lnkTooltip'); const tm = tmEl && tmEl.textContent.trim().match(/(\d{1,2}):(\d{2})/); if (!tm) continue;
    const parts = tds[3].textContent.replace(/\s+/g, ' ').trim().split(/\s-\s/); if (parts.length !== 2) continue;
    const h = sweResolve(parts[0], teams, league), a = sweResolve(parts[1], teams, league); if (!h || !a) continue;
    const date = zonedToDate(+day[1], +day[2], +day[3], +tm[1], +tm[2], 'Europe/Stockholm');
    const rm = tds[4].textContent.match(/(\d+)\s*-\s*(\d+)/);
    const periods = (tds[5].textContent.match(/\d+-\d+/g) || []).length;
    const gm = tds[4].innerHTML.match(/\/Game\/Events\/(\d+)/);
    out.push({ id: 'swe-' + (gm ? gm[1] : out.length), gid: gm ? gm[1] : null, date, home: h, away: a, live: false, final: !!rm, homeScore: rm ? +rm[1] : null, awayScore: rm ? +rm[2] : null, extra: rm ? (periods >= 5 ? 'RL' : periods === 4 ? 'JA' : null) : null });
  }
  if (!out.length) return null;
  sweCache[league] = { t: Date.now(), v: out }; return out;
}
async function fetchSweStandings(league, teams) {
  const games = await fetchSweGames(league, teams); if (!games) return null;
  const table = Object.fromEntries(teams.filter(t => t.league === league).map(t => [t.name, { team: t.name, gp: 0, w: 0, l: 0, otl: 0, pts: 0, gf: 0, ga: 0, group: '' }]));
  for (const g of games) {
    if (!g.final) continue; const hr = table[g.home], ar = table[g.away]; if (!hr || !ar) continue;
    hr.gp++; ar.gp++; hr.gf += g.homeScore; hr.ga += g.awayScore; ar.gf += g.awayScore; ar.ga += g.homeScore;
    const ex = !!g.extra;
    if (g.homeScore > g.awayScore) { hr.w++; hr.pts += ex ? 2 : 3; if (ex) { ar.otl++; ar.pts++; } else ar.l++; }
    else if (g.awayScore > g.homeScore) { ar.w++; ar.pts += ex ? 2 : 3; if (ex) { hr.otl++; hr.pts++; } else hr.l++; }
  }
  return Object.values(table);
}

async function fetchSweSchedule(league, teams) { return await fetchSweGames(league, teams); }

// SHL-logot (TheSportsDB). Puuttuvat haetaan ajon aikana (Store.fetchMissingLogos).
const EXTRA_LOGOS = {
  'Brynäs IF': 'https://r2.thesportsdb.com/images/media/team/badge/n7ngcn1700826181.png',
  'Djurgårdens IF': 'https://r2.thesportsdb.com/images/media/team/badge/eoxtmh1644937914.png',
  'Färjestad BK': 'https://r2.thesportsdb.com/images/media/team/badge/svvxxu1421610693.png',
  'Frölunda HC': 'https://r2.thesportsdb.com/images/media/team/badge/1zbgup1656774483.png',
  'HV71': 'https://r2.thesportsdb.com/images/media/team/badge/k10ji41663411948.png',
  'IF Björklöven': 'https://r2.thesportsdb.com/images/media/team/badge/0yuhv71700826189.png',
  'Linköping HC': 'https://r2.thesportsdb.com/images/media/team/badge/330nt41783580950.png',
  'Luleå HF': 'https://r2.thesportsdb.com/images/media/team/badge/5l7gw41644937943.png',
  'Malmö Redhawks': 'https://r2.thesportsdb.com/images/media/team/badge/j8gnby1644937928.png',
  'Örebro HK': 'https://r2.thesportsdb.com/images/media/team/badge/wqtspp1422389481.png',
};

// ---------- SHL/HA: kokoonpanot, ottelutapahtumat ja pelaajatilastot ----------
function sweDay(d) { return new Intl.DateTimeFormat('sv-SE', { timeZone: 'Europe/Stockholm', year: 'numeric', month: '2-digit', day: '2-digit' }).format(d); }
const sweName = s => { const p = String(s).split(','); return p.length >= 2 ? (p.slice(1).join(',').trim() + ' ' + p[0].trim()) : String(s).trim(); };
const swePos = r => { r = String(r || '').toUpperCase(); if (r === 'GK' || r === 'G') return ['G', null]; if (r === 'C' || r === 'CE') return ['F', 'C']; if (r === 'LW') return ['F', 'L']; if (r === 'RW') return ['F', 'R']; if (/D$/.test(r)) return ['D', 'D']; return ['F', null]; };

// {joukkue: [{no, name, pos, slot, nat, born}]}
async function fetchSweRoster(league, teams) {
  const id = await sweLeagueId(league); if (!id) return null;
  const html = await getText(`${SWE_BASE}/Teams/Info/TeamRoster/${id}`, 40000); if (!html) return null;
  const doc = new DOMParser().parseFromString(html, 'text/html');
  const seed = teams.filter(t => t.league === league), out = {};
  for (const tb of doc.querySelectorAll('table')) {
    const rows = Array.from(tb.querySelectorAll('tr')); if (!rows.length) continue;
    const head = rows[0].textContent.replace(/\s+/g, ' ').trim().replace(/\[Top\]/, '').trim();
    const team = sweResolve(head.slice(0, Math.ceil(head.length / 2)).trim() === head.slice(Math.floor(head.length / 2)).trim() ? head.slice(0, Math.ceil(head.length / 2)).trim() : head, teams, league) || sweResolve(head, teams, league);
    if (!team) continue;
    const list = [];
    for (const r of rows) {
      const tds = Array.from(r.children).filter(e => e.tagName === 'TD'); if (tds.length < 8) continue;
      const no = tds[0].textContent.trim(); if (!/^\d+$/.test(no)) continue;
      const [pos, slot] = swePos(tds[3].textContent.trim());
      list.push({ no: +no, name: sweName(tds[1].textContent.replace(/\s+/g, ' ').trim()), pos, slot, nat: tds[7].textContent.trim().split(/\s|\//)[0] || null, born: tds[2].textContent.trim() || null });
    }
    if (list.length) out[team] = list;
  }
  return Object.keys(out).length ? out : null;
}

// Jäsentää yhden ottelun tapahtumasivun pieneen muotoon
function parseSweEvents(html) {
  const doc = new DOMParser().parseFromString(String(html).replace(/<(\/?)(td|th|tr|br)\b/gi, ' <$1$2'), 'text/html');
  const rows = Array.from(doc.querySelectorAll('tr')).map(tr => tr.textContent.replace(/\s+/g, ' ').trim());
  const goalRows = [], pens = [], gk = [];
  for (const t of rows) {
    let m = t.match(/^(\d+):(\d+) (\d+)-(\d+) \(([A-Z]+\d?)\) (\S+) (.*)$/);
    if (m) { goalRows.push(m); continue; }
    m = t.match(/^(\d+):(\d+) (\d+) min (\S+) (\d+)\./); if (m) { pens.push({ ab: m[4], n: +m[5], m: +m[3] }); continue; }
    m = t.match(/^(\S{2,5}) \d+\. .+ \d+,\d+% \(\d+\/\d+\)$/); if (m && !gk.includes(m[1])) gk.push(m[1]);
  }
  goalRows.sort((x, y) => (+x[3] + +x[4]) - (+y[3] + +y[4]));
  const side = {}; let ph = 0, pa = 0; const goals = [];
  for (const m of goalRows) {
    const hs = +m[3], as = +m[4]; const s = hs > ph ? 'h' : 'a'; ph = hs; pa = as; side[m[6]] = s;
    const dtl = m[7]; const pi = dtl.search(/Pos\. Part\./); const main = (pi >= 0 ? dtl.slice(0, pi) : dtl).trim();
    const sm = main.match(/^(\d+)\.\s+(.+?)\s+\((\d+)\)\s*(.*)$/); if (!sm) continue;
    const ast = []; for (const x of sm[4].matchAll(/(\d+)\.\s+([^\d]+?)\s*(?=\d+\.\s|$)/g)) ast.push({ n: +x[1], name: x[2].trim() });
    const nums = re => { const mm = dtl.match(re); return mm && mm[1] ? mm[1].split(',').map(v => parseInt(v, 10)).filter(v => !isNaN(v)) : []; };
    goals.push({ s, type: m[5], sc: { n: +sm[1], name: sm[2].trim() }, ast, pos: nums(/Pos\. Part\.:\s*([\d\s,]*?)\s*(?:Neg\. Part\.|$)/), neg: nums(/Neg\. Part\.:\s*([\d\s,]*)$/) });
  }
  if (gk.length >= 2) { if (!side[gk[0]] && !Object.values(side).includes('h')) side[gk[0]] = 'h'; if (!side[gk[1]] && !Object.values(side).includes('a')) side[gk[1]] = 'a'; }
  const pl = []; for (const p of pens) { const s = side[p.ab] || (gk[0] === p.ab ? 'h' : gk[1] === p.ab ? 'a' : null); if (s) pl.push({ s, n: p.n, m: p.m }); }
  return { goals, pens: pl };
}

// Laskee pelaajatilastot päättyneistä otteluista. cache: {gid: parseSweEvents-tulos}
function aggregateSwe(league, teams, games, cache, roster) {
  const numMap = {}, ents = {}, perGame = {}, teamGames = {}, teamList = {};
  const seed = teams.filter(t => t.league === league);
  const key = (team, name) => team + '|' + norm(name);
  const blank = (team, name, extra) => Object.assign({ name, team, number: null, pos: null, slot: null, nat: null, born: null, goals: 0, assists: 0, ppPoints: 0, plusMinus: 0, pim: 0 }, extra);
  for (const [team, list] of Object.entries(roster || {})) {
    numMap[team] = {};
    for (const r of list) { numMap[team][r.no] = r.name; ents[key(team, r.name)] = blank(team, r.name, { number: r.no, pos: r.pos, slot: r.slot, nat: r.nat, born: r.born }); }
  }
  const ent = (team, name, no) => { const k = key(team, name); return ents[k] || (ents[k] = blank(team, name, { number: no ?? null })); };
  const rec = (gid, team, name) => { const k = key(team, name); const pg = perGame[k] || (perGame[k] = {}); return pg[gid] || (pg[gid] = { goals: 0, assists: 0, pp: 0 }); };
  const fin = games.filter(g => g.final && g.gid && cache[g.gid]).sort((a, b) => a.date - b.date);
  for (const g of fin) {
    const ev = cache[g.gid]; const tn = s => s === 'h' ? g.home : g.away, on = s => s === 'h' ? g.away : g.home;
    for (const t of [g.home, g.away]) { teamGames[t] = (teamGames[t] || 0) + 1; (teamList[t] ||= []).push({ id: g.gid, date: sweDay(g.date), opponent: t === g.home ? g.away : g.home, home: t === g.home }); }
    for (const gl of ev.goals) {
      const team = tn(gl.s), opp = on(gl.s), pp = /^PP/.test(gl.type);
      const sn = sweName(gl.sc.name); const se = ent(team, sn, gl.sc.n); se.goals++; rec(g.gid, team, sn).goals++;
      if (pp) { se.ppPoints++; rec(g.gid, team, sn).pp++; }
      for (const a of gl.ast) { const an = sweName(a.name); const ae = ent(team, an, a.n); ae.assists++; rec(g.gid, team, an).assists++; if (pp) { ae.ppPoints++; rec(g.gid, team, an).pp++; } }
      if (!pp && gl.type !== 'PS') {
        for (const n of gl.pos) { const nm = (numMap[team] || {})[n]; if (nm) { const e = ents[key(team, nm)]; if (e && e.pos !== 'G') e.plusMinus++; } }
        for (const n of gl.neg) { const nm = (numMap[opp] || {})[n]; if (nm) { const e = ents[key(opp, nm)]; if (e && e.pos !== 'G') e.plusMinus--; } }
      }
    }
    for (const p of ev.pens) { const team = tn(p.s); const nm = (numMap[team] || {})[p.n]; if (nm) { const e = ents[key(team, nm)]; if (e) e.pim += p.m; } }
  }
  const byName = {};
  for (const e of Object.values(ents)) (byName[norm(e.name)] ||= []).push(e);
  const teamRecent = {}, recent = {}, hot = [];
  for (const [t, l] of Object.entries(teamList)) teamRecent[t] = l.slice().sort((a, b) => b.date < a.date ? -1 : b.date > a.date ? 1 : 0).slice(0, 5);
  for (const [k, pg] of Object.entries(perGame)) {
    const team = k.slice(0, k.indexOf('|')); const tr = teamRecent[team] || [];
    const mine = tr.filter(g => pg[g.id]).map(g => ({ id: g.id, date: g.date, opponent: g.opponent, home: g.home, goals: pg[g.id].goals, assists: pg[g.id].assists, pp: pg[g.id].pp }));
    if (mine.length) recent[k] = mine;
    const last4 = (teamList[team] || []).slice().sort((a, b) => b.date < a.date ? -1 : b.date > a.date ? 1 : 0).slice(0, 4);
    if (last4.length === 4 && last4.every(g => pg[g.id] && pg[g.id].goals + pg[g.id].assists > 0)) hot.push(k);
  }
  return { byName, teamGames, teamRecent, recent, hot };
}


// ---------- Maalivahdit (NHL, Liiga, AHL) ----------
async function fetchNHLGoalies(teamByAbbr) {
  const j = await getJSON('https://api.nhle.com/stats/rest/en/goalie/summary?limit=-1&cayenneExp=seasonId=20262027%20and%20gameTypeId=2', 20000);
  if (!j || !Array.isArray(j.data)) return null;
  const out = [];
  for (const r of j.data) {
    const abbr = String(r.teamAbbrevs || '').split(',').pop().trim(); const t = teamByAbbr[abbr];
    if (r.playerId == null || !r.goalieFullName || !t) continue;
    out.push({ id: 'g-nhl-' + r.playerId, name: r.goalieFullName, team: t.name, league: 'NHL', flag: t.flag, games: r.gamesPlayed || 0, wins: r.wins ?? null,
      shotsAgainst: r.shotsAgainst ?? null, saves: r.saves ?? null, goalsAgainst: r.goalsAgainst ?? null, shutouts: r.shutouts ?? null, gaaValue: r.goalsAgainstAverage ?? null });
  }
  return out;
}
async function fetchLiigaGoalies(teams) {
  const j = await getJSON('https://liiga.fi/api/v2/players/stats/summed/2027/2027/runkosarja/true', 30000);
  if (!Array.isArray(j)) return null;
  const byKey = Object.fromEntries(teams.filter(t => t.league === 'SM-liiga').map(t => [liigaKey(t.name), t]));
  const out = [];
  for (const g of j) {
    if (!(g.goalkeeper === true || g.role === 'MV')) continue;
    const t = byKey[liigaKey(g.teamName || '')]; if (g.playerId == null || !t || !(g.playedGames > 0)) continue;
    const sv = g.blockedOrSavedShots, ga = g.goalsAgainst;
    out.push({ id: 'g-liiga-' + g.playerId, name: [g.firstName, g.lastName].filter(Boolean).join(' '), team: t.name, league: 'SM-liiga', flag: t.flag, nat: g.nationality || null,
      number: g.jersey ?? null, games: g.playedGames, wins: g.gkWins ?? null, shotsAgainst: (sv != null && ga != null) ? sv + ga : null, saves: sv ?? null,
      goalsAgainst: ga ?? null, shutouts: g.shutOut ?? null, gaaValue: g.goalsAgainstAvg ?? null });
  }
  return out;
}
async function fetchAHLGoalies(teams, season, teamIDs) {
  const byName = Object.fromEntries(teams.filter(t => t.league === 'AHL').map(t => [t.name, t]));
  const byCode = Object.fromEntries(teams.filter(t => t.league === 'AHL').map(t => [t.abbr, t]));
  let any = false; const out = [];
  const res = await pool(teamIDs, 8, id => ahlFetch(`view=statviewtype&type=goalies&season_id=${season}&team_id=${id}&limit=20&first=0&sort=wins`));
  for (const rows of res) {
    if (!rows) continue; any = true;
    for (const r of rows) {
      const name = r.name || r.shortname; const t = byName[r.team_name] || byCode[r.team_code]; const gp = toInt(r.games_played) || 0;
      if (!r.player_id || !name || !t || gp <= 0) continue;
      const f = parseFloat(r.goals_against_average);
      out.push({ id: 'g-ahl-' + r.player_id, name, team: t.name, league: 'AHL', flag: t.flag, number: toInt(r.jersey_number), games: gp, wins: toInt(r.wins),
        shotsAgainst: toInt(r.shots), saves: toInt(r.saves), goalsAgainst: toInt(r.goals_against), shutouts: toInt(r.shutouts), gaaValue: Number.isNaN(f) ? null : f });
    }
  }
  return any ? out : null;
}
const goaliePct = g => (g.saves != null && g.shotsAgainst > 0) ? g.saves / g.shotsAgainst * 100 : null;
const goalieGAA = g => g.gaaValue != null ? g.gaaValue : (g.goalsAgainst != null && g.games > 0 ? g.goalsAgainst / g.games : null);


// ---------- Odds API (vedonlyöntikertoimet) ----------

// ---------- Sveitsin National League (data.sihf.ch) ----------
const NL_SEASON = '2027', NL_RANGE = '01.07.2026-30.06.2027';
async function nlTable(query) {
  const url = 'https://data.sihf.ch/Statistic/api/cms/table?' + query;
  let j = null;
  if (window.native && native.httpText) { const r = await native.httpText(url, 30000); try { j = r && r.text ? JSON.parse(r.text) : null; } catch { j = null; } }
  else j = await getJSON(url, 30000);
  if (!j || !Array.isArray(j.data) || !Array.isArray(j.header)) return null;
  const idx = {}; j.header.forEach((h, i) => { if (h && h.alias) idx[h.alias] = i; });
  const t = { rows: j.data, idx };
  t.s = (r, a) => { const v = r[idx[a]]; return typeof v === 'string' ? v : null; };
  t.n = (r, a) => { const v = t.s(r, a); if (v == null) return null; const x = parseInt(v.trim(), 10); return isNaN(x) ? null : x; };
  t.f = (r, a) => { const v = t.s(r, a); if (v == null) return null; const x = parseFloat(v.replace(',', '.')); return isNaN(x) ? null : x; };
  t.o = (r, a) => { const v = r[idx[a]]; return v && typeof v === 'object' ? v : null; };
  return t;
}
const nlBase = alias => `alias=${alias}&searchQuery=1//1&filterBy=Season&filterQuery=${NL_SEASON}&language=en`;
function nlTeam(o, teams) { if (!o) return null; const list = teams.filter(t => t.league === 'National League'); return list.find(t => t.name === o.name) || list.find(t => t.abbr === o.acronym) || null; }
function nlName(s) { const p = String(s).split(/\s+/).filter(Boolean); return p.length >= 2 ? p[p.length - 1] + ' ' + p.slice(0, -1).join(' ') : String(s); }
async function fetchNLSkaters(teams) {
  const t = await nlTable(nlBase('player') + '&orderBy=points&orderByDescending=true&take=500&skip=0'); if (!t) return null;
  const out = [];
  for (const r of t.rows) { const team = nlTeam(t.o(r, 'team'), teams), raw = t.s(r, 'player'); if (!team || !raw) continue;
    out.push({ name: nlName(raw), team: team.name, pos: (t.s(r, 'position') || '').startsWith('Verteid') ? 'D' : 'F', games: t.n(r, 'gamesPlayed') || 0, goals: t.n(r, 'goals') || 0, assists: t.n(r, 'assists') || 0, pim: t.n(r, 'pimTotal'), plusMinus: t.n(r, 'plusMinus') }); }
  return out.length ? out : null;
}
async function fetchNLGoalies(teams) {
  const t = await nlTable(nlBase('goalkeeper') + '&take=100&skip=0'); if (!t) return null;
  const out = [];
  for (const r of t.rows) { const team = nlTeam(t.o(r, 'team'), teams), raw = t.s(r, 'player'); if (!team || !raw) continue; const name = nlName(raw);
    out.push({ id: 'g-nl-' + norm(name) + '-' + team.abbr, name, team: team.name, league: 'National League', flag: team.flag, nat: null, number: null, games: t.n(r, 'gamesPlayed') || 0, wins: null, shotsAgainst: t.n(r, 'shotsAgainst'), saves: t.n(r, 'saves'), goalsAgainst: t.n(r, 'goalsAgainst'), shutouts: null, gaaValue: t.f(r, 'goalsAgainstAverage') }); }
  return out;
}
async function fetchNLStandings(teams) {
  const t = await nlTable(nlBase('standing')); if (!t) return null;
  const out = [];
  for (const r of t.rows) { const team = nlTeam(t.o(r, 'team'), teams); if (!team) continue;
    out.push({ team: team.name, gp: t.n(r, 'gamesPlayed') || 0, w: (t.n(r, 'gamesWonInTime') || 0) + (t.n(r, 'gamesWonExtraTime') || 0) + (t.n(r, 'gamesWonPenalty') || 0), l: t.n(r, 'gamesLostInTime') || 0, otl: (t.n(r, 'gamesLostExtraTime') || 0) + (t.n(r, 'gamesLostPenalty') || 0), pts: t.n(r, 'points') || 0, gf: t.n(r, 'goalsFor') || 0, ga: t.n(r, 'goalsAgainst') || 0, group: '' }); }
  return out.length ? out : null;
}
async function fetchNLGames(teams) {
  const t = await nlTable(`alias=results&searchQuery=1//1&language=en&filterBy=Date&filterQuery=${NL_RANGE}`); if (!t) return null;
  const out = [];
  t.rows.forEach((r, i) => {
    const h = nlTeam(t.o(r, 'homeTeam'), teams), a = nlTeam(t.o(r, 'awayTeam'), teams); if (!h || !a) return;
    const st = t.o(r, 'status') || {}; let d = st.startDateTime ? new Date(st.startDateTime) : null;
    if (!d || isNaN(d)) { const ds = t.s(r, 'date'), tm = t.s(r, 'time'); if (ds && tm) { const [dd, mm, yy] = ds.split('.'); d = zonedToDate(+yy, +mm, +dd, +tm.split(':')[0], +tm.split(':')[1], 'Europe/Zurich'); } }
    if (!d || isNaN(d)) return;
    const pc = Number(st.percent) || 0, sc = t.o(r, 'score') || {}; const hs = sc.homeTeam != null && sc.homeTeam !== '' ? parseInt(sc.homeTeam, 10) : null, as = sc.awayTeam != null && sc.awayTeam !== '' ? parseInt(sc.awayTeam, 10) : null;
    const fin = pc >= 100 && hs != null && as != null && !isNaN(hs) && !isNaN(as);
    const dec = String(t.s(r, 'decision') || '').toUpperCase(); const det = t.o(r, 'details');
    out.push({ id: 'nl-' + ((det && det.gameId) || i), date: d, home: h.name, away: a.name, final: fin, live: !fin && pc > 0 && pc < 100, hs: fin ? hs : null, as: fin ? as : null, extra: fin ? (dec === 'OT' ? 'JA' : (dec === 'SO' || dec === 'PS' || dec === 'GWS') ? 'RL' : null) : null });
  });
  return out.length ? out : null;
}
async function fetchNLSchedule(teams) {
  const g = await fetchNLGames(teams); if (!g) return null;
  return g.map(x => ({ id: x.id, date: x.date, home: x.home, away: x.away, live: x.live, final: x.final, homeScore: x.final ? x.hs : null, awayScore: x.final ? x.as : null }));
}

const nlScoringCache = {};
function nlParseGoalText(text) {
  const out = { scorer: null, assists: [] }; if (!text) return out;
  const clean = s => String(s).replace(/\*/g, '').replace(/\s*\(\d+\)\s*$/, '').trim();
  const lines = String(text).split('\n'); const i = lines[0].lastIndexOf(' - ');
  if (i >= 0) { const n = clean(lines[0].slice(i + 3)); if (n) out.scorer = norm(nlName(n)); }
  if (lines[1]) for (const part of lines[1].split(/\),\s*/)) { const n = clean(part.endsWith(')') ? part : part + ')'); if (n) out.assists.push(norm(nlName(n))); }
  return out;
}
async function fetchNLGameScoring(gid) {
  if (nlScoringCache[gid]) return nlScoringCache[gid];
  const url = 'https://data.sihf.ch/Statistic/api/cms/gameoverview?alias=gameDetail&searchQuery=' + gid + '&language=en';
  let j = null;
  if (window.native && native.httpText) { const r = await native.httpText(url, 30000); try { j = r && r.text ? JSON.parse(r.text) : null; } catch { j = null; } }
  else j = await getJSON(url, 30000);
  if (!j || !j.summary || !Array.isArray(j.summary.periods)) return null;
  const names = {}, out = { goals: {}, assists: {}, pp: {}, sog: {}, num: {} };
  for (const p of j.players || []) if (p.id != null && p.fullName) { const k = norm(nlName(p.fullName)); names[p.id] = k; if (p.jerseyNumber != null) out.num[k] = +p.jerseyNumber; }
  for (const per of j.summary.periods) for (const g of per.goals || []) {
    if (g.isShootout) continue;
    const isPP = String((g.situation && g.situation.code) || '').startsWith('PP');
    const pt = nlParseGoalText(g.text);
    const s = names[g.scorerLicenceNr] || pt.scorer; if (s) { out.goals[s] = (out.goals[s] || 0) + 1; if (isPP) out.pp[s] = (out.pp[s] || 0) + 1; }
    ['assist1LicenceNr', 'assist2LicenceNr'].forEach((k, i) => { if (g[k] != null && +g[k] <= 0) return; const a = names[g[k]] || pt.assists[i]; if (a) { out.assists[a] = (out.assists[a] || 0) + 1; if (isPP) out.pp[a] = (out.pp[a] || 0) + 1; } });
  }
  for (const tb of j.stats || []) {
    const al = (tb.header || []).map(h => h && h.alias), ni = al.indexOf('player'), si = al.indexOf('shotsOnGoal'); if (ni < 0 || si < 0) continue;
    for (const r of tb.data || []) { const n = parseInt(r[si], 10); if (typeof r[ni] === 'string' && !isNaN(n)) { const k = norm(nlName(r[ni])); out.sog[k] = (out.sog[k] || 0) + n; } }
  }
  nlScoringCache[gid] = out; return out;
}

const Odds = {
  cache: {}, remaining: null,
  sportKey: l => ({ NHL: 'icehockey_nhl', AHL: 'icehockey_ahl', 'SM-liiga': 'icehockey_liiga', Mestis: 'icehockey_mestis', SHL: 'icehockey_sweden_hockey_league', 'National League': 'icehockey_switzerland_nla', HockeyAllsvenskan: 'icehockey_sweden_allsvenskan' })[l],
  hasProps: l => l === 'NHL',
  PROP_MARKETS: 'player_points,player_assists,player_goals,player_goal_scorer_anytime',
  book: (k, t) => ({ veikkaus_fi: 'Veikkaus', unibet_fi: 'Unibet', nordicbet: 'NordicBet', coolbet: 'Coolbet', pinnacle: 'Pinnacle' })[k] || t || k,
  async get(path, q, ttl) {
    const key = Store.state.oddsKey; if (!key) return null;
    const url = 'https://api.the-odds-api.com/v4' + path + '?' + new URLSearchParams({ apiKey: key, ...q }).toString();
    const ck = path + JSON.stringify(q); const c = this.cache[ck]; if (c && Date.now() - c.t < ttl) return c.v;
    try {
      const r = await fetch(url); const rem = r.headers.get('x-requests-remaining'); if (rem != null) this.remaining = rem;
      if (!r.ok) return null; const v = await r.json(); this.cache[ck] = { t: Date.now(), v }; return v;
    } catch { return null; }
  },
  same(a, b) { const x = norm(a), y = norm(b); return x === y || x.includes(y) || y.includes(x); },
  async findEvent(game, league) {
    const ev = await this.get(`/sports/${this.sportKey(league)}/events`, {}, 1800000); if (!ev) return null;
    return ev.find(e => this.same(e.home_team, game.home) && this.same(e.away_team, game.away) && Math.abs(new Date(e.commence_time) - new Date(game.date)) < 86400000) || null;
  },
  async h2h(league, eventId) {
    const l = await this.get(`/sports/${this.sportKey(league)}/odds`, { regions: 'fi,eu', markets: 'h2h', bookmakers: 'veikkaus_fi,unibet_fi,nordicbet,coolbet,pinnacle' }, 900000); if (!l) return null;
    const e = l.find(x => x.id === eventId); if (!e) return null; const out = {};
    for (const b of e.bookmakers || []) for (const m of b.markets || []) if (m.key === 'h2h') for (const o of m.outcomes || []) (out[o.name] = out[o.name] || []).push({ book: this.book(b.key, b.title), price: o.price });
    return out;
  },
  async props(league, eventId) {
    const e = await this.get(`/sports/${this.sportKey(league)}/events/${eventId}/odds`, { regions: 'eu', markets: this.PROP_MARKETS, bookmakers: 'coolbet,pinnacle' }, 1800000); if (!e) return null;
    const out = {};
    for (const b of e.bookmakers || []) for (const m of b.markets || []) for (const o of m.outcomes || []) {
      const any = m.key === 'player_goal_scorer_anytime';
      let mk = m.key; if (any) { if (o.name === 'No') continue; } else { const pt = o.point == null ? 0.5 : o.point; if (!(o.name === 'Over' && (pt === 0.5 || pt === 1.5))) continue; mk = m.key + '@' + pt; }
      const who = o.description || o.name; ((out[mk] = out[mk] || {})[norm(who)] = (out[mk][norm(who)] || [])).push({ book: this.book(b.key, b.title), price: o.price });
    }
    return out;
  },
};

// ---------- Uudistettu ilme: liekki ja tulospilleri ----------
const FLAME = '<svg class="flame"><use href="#flameS"/></svg>';
/** Tulospilleri. teamColors: koti syaani / vieras indigo voittajalle; muuten keltainen. */
function scorePill(l, r, size = 'md', tc = false) {
  if (l == null || r == null) return '<span class="muted">–</span>';
  const lc = l > r ? (tc ? 'h' : 'w') : '', rc = r > l ? (tc ? 'a' : 'w') : '';
  return `<span class="sp ${size === 'md' ? '' : size}${tc ? ' tc' : ''}"><span class="${lc}">${l}</span><span class="${rc}">${r}</span></span>`;
}

// ---------- NHL-ottelun lisätiedot (play-by-play, right-rail, landing) ----------
const nhlSecs = s => { const p = String(s || '').split(':').map(Number); return p.length === 2 && !p.some(isNaN) ? p[0] * 60 + p[1] : 0; };
const nhlClockStr = t => `${Math.floor(t / 60)}:${String(t % 60).padStart(2, '0')}`;
const nhlRName = r => r ? [r.firstName && r.firstName.default, r.lastName && r.lastName.default].filter(Boolean).join(' ') : '?';
const NHL_PEN = { hooking: 'koukkaus', holding: 'kiinnipito', tripping: 'kampitus', slashing: 'mailalyönti', 'high-sticking': 'korkea maila', interference: 'estäminen', 'cross-checking': 'ristiintaklaus', roughing: 'karkea peli', boarding: 'laitaan ajo', elbowing: 'kyynärpää', 'delaying-game': 'pelin viivytys', 'too-many-men-on-the-ice': 'liikaa pelaajia', fighting: 'tappelu', 'unsportsmanlike-conduct': 'epäurheilijamainen käytös', charging: 'taklaus hyökkäämällä', 'closing-hand-on-puck': 'kiekon peittäminen', 'holding-the-stick': 'mailan pitely', 'illegal-check-to-head': 'kielletty taklaus päähän', kneeing: 'polvitaklaus', embellishment: 'näyttely', 'goalie-leaves-crease': 'maalivahti pois alueeltaan', 'delay-of-game': 'pelin viivytys', 'puck-over-glass-delay-of-game': 'kiekko katsomoon', misconduct: 'pelirangaistus', 'game-misconduct': 'ottelurangaistus', spearing: 'keihästys', clipping: 'polviin taklaus', 'face-off-violation': 'aloitusrike', 'playing-without-a-helmet': 'ei kypärää' };
const nhlPenReason = k => !k ? 'jäähy' : (NHL_PEN[k] || String(k).replace(/-/g, ' '));

function nhlGameDetail(p) {
  const d = { goals: [], rink: (p.venue && p.venue.default) || null, spectators: null, homePP: null, awayPP: null, resultNote: null };
  const roster = {}; for (const r of p.rosterSpots || []) roster[r.playerId] = r;
  const isSO = String((p.gameOutcome || {}).lastPeriodType || '').toUpperCase() === 'SO';
  const goals = (p.plays || []).filter(x => x.typeDescKey === 'goal' && String((x.periodDescriptor || {}).periodType || '').toUpperCase() !== 'SO');
  let fH = 0, fA = 0; for (const g of goals) { fH = Math.max(fH, (g.details || {}).homeScore || 0); fA = Math.max(fA, (g.details || {}).awayScore || 0); }
  for (const pl of goals) {
    const det = pl.details; if (!det) continue;
    const n = (pl.periodDescriptor || {}).number || 1, secs = (n - 1) * 1200 + nhlSecs(pl.timeInPeriod), home = det.eventOwnerTeamId === (p.homeTeam || {}).id;
    // situationCode: [vieras MV][vieras kentällä][koti kentällä][koti MV]; MV 0 = tyhjä maali, ylimääräinen hyökkääjä vähennetään
    const dg = String(pl.situationCode || '').split('').map(Number); const tags = [];
    if (dg.length === 4 && !dg.some(isNaN)) {
      const aG = dg[0], hG = dg[3], aS = dg[1] - (aG === 0 ? 1 : 0), hS = dg[2] - (hG === 0 ? 1 : 0);
      const mine = home ? hS : aS, theirs = home ? aS : hS;
      if ((home ? aG : hG) === 0) tags.push('TM');
      if (mine > theirs) tags.push('YV'); else if (mine < theirs) tags.push('AV');
    }
    if (!isSO && fH !== fA && det.homeScore != null && det.awayScore != null) { const hw = fH > fA; if (home === hw && (home ? det.homeScore : det.awayScore) === (hw ? fA : fH) + 1) tags.push('VM'); }
    d.goals.push({
      seconds: secs, period: n, home, scorer: det.scoringPlayerId != null ? nhlRName(roster[det.scoringPlayerId]) : '?',
      assists: [det.assist1PlayerId, det.assist2PlayerId].filter(x => x != null).map(x => nhlRName(roster[x])),
      homeScore: det.homeScore ?? null, awayScore: det.awayScore ?? null, powerPlay: tags.includes('YV'), tags,
      video: det.highlightClip ? `https://players.brightcove.net/6415718365001/default_default/index.html?videoId=${det.highlightClip}&autoplay=true&muted=false&applicationId=nhl` : (det.highlightClipSharingUrl || null),
    });
  }
  return d;
}

function nhlPenalties(p) {
  const roster = {}; for (const r of p.rosterSpots || []) roster[r.playerId] = r;
  const out = [];
  for (const pl of p.plays || []) {
    if (pl.typeDescKey !== 'penalty' || !pl.details) continue;
    const n = (pl.periodDescriptor || {}).number || 1, det = pl.details;
    out.push({ period: n, seconds: (n - 1) * 1200 + nhlSecs(pl.timeInPeriod), home: det.eventOwnerTeamId === (p.homeTeam || {}).id,
      player: det.committedByPlayerId != null ? nhlRName(roster[det.committedByPlayerId]) : 'Joukkue', reason: nhlPenReason(det.descKey), minutes: det.duration || 2 });
  }
  return out;
}

function nhlSummary(rr, ln, hAb, aAb) {
  const ex = { outcome: null, penalties: [], periods: [], totalGoals: null, stats: [], stars: [], shootout: [] };
  const srcs = [rr, ln && ln.summary, ln];
  const find = k => { for (const s of srcs) if (s && s[k] != null) return s[k]; return null; };
  const str = a => a == null ? null : (typeof a === 'string' ? a : (a.default || null));
  const nv = v => { if (v == null) return null; const n = typeof v === 'number' ? v : parseFloat(String(v).replace(',', '.')); return isNaN(n) ? null : n; };
  const pk = d => { if (!d || d.number == null) return null; const n = +d.number, t = String(d.periodType || 'REG').toUpperCase(); return t === 'SO' ? ['RL', 100] : t === 'OT' ? [n > 4 ? 'JA' + (n - 3) : 'JA', n] : [n + '.', n]; };
  const per = {};
  const ls = find('linescore');
  if (ls) {
    for (const e of ls.byPeriod || []) { const k = pk(e.periodDescriptor); if (!k) continue; const l = per[k[0]] || (per[k[0]] = { label: k[0], order: k[1] }); l.hg = nv(e.home); l.ag = nv(e.away); }
    if (ls.totals && nv(ls.totals.home) != null && nv(ls.totals.away) != null) ex.totalGoals = [nv(ls.totals.home), nv(ls.totals.away)];
  }
  for (const e of find('shotsByPeriod') || []) { const k = pk(e.periodDescriptor); if (!k) continue; const l = per[k[0]] || (per[k[0]] = { label: k[0], order: k[1] }); l.hsh = nv(e.home); l.ash = nv(e.away); }
  ex.periods = Object.values(per).sort((a, b) => a.order - b.order);
  const cats = [['sog', 'Laukaukset'], ['powerPlay', 'Ylivoimat'], ['pim', 'Jäähyminuutit'], ['hits', 'Taklaukset'], ['blockedShots', 'Blokatut laukaukset'], ['faceoffWinningPctg', 'Aloitusvoitot'], ['giveaways', 'Menetetyt kiekot'], ['takeaways', 'Riistot']];
  const shown = (cat, v) => {
    if (typeof v === 'string') {
      const first = parseFloat(v.split('/')[0]); const d = parseFloat(v.replace(',', '.'));
      if (cat === 'faceoffWinningPctg' && !isNaN(d)) { const pct = d <= 1 ? d * 100 : d; return [Math.round(pct) + ' %', pct]; }
      return [v, isNaN(first) ? 0 : first];
    }
    const d = nv(v); if (d == null) return null;
    if (cat === 'faceoffWinningPctg') { const pct = d <= 1 ? d * 100 : d; return [Math.round(pct) + ' %', pct]; }
    return [String(Math.trunc(d)), d];
  };
  const rows = find('teamGameStats') || [];
  for (const [key, label] of cats) {
    const r = rows.find(x => x.category === key); if (!r) continue;
    const h = shown(key, r.homeValue), a = shown(key, r.awayValue); if (!h || !a) continue;
    ex.stats.push({ label, home: h[0], away: a[0], hv: h[1], av: a[1] });
  }
  for (const e of find('threeStars') || []) {
    const name = str(e.name) || [str(e.firstName), str(e.lastName)].filter(Boolean).join(' '); if (!name) continue;
    const ab = str(e.teamAbbrev); const home = ab == null ? null : ab === hAb ? true : ab === aAb ? false : null;
    let detail = '';
    if (e.position === 'G') { const sp = nv(e.savePctg); if (sp != null) detail = 'torjunta-% ' + sp.toFixed(3).replace('0.', '.'); }
    else detail = `${nv(e.goals) || 0} + ${nv(e.assists) || 0}`;
    ex.stars.push({ star: nv(e.star) || ex.stars.length + 1, name, home, detail });
  }
  ex.stars.sort((a, b) => a.star - b.star);
  for (const e of find('shootout') || []) {
    const name = [str(e.firstName), str(e.lastName)].filter(Boolean).join(' '); if (!name) continue;
    ex.shootout.push({ home: str(e.teamAbbrev) === hAb, name, scored: String(e.result || '') === 'goal' });
  }
  return ex;
}

async function fetchNHLBundle(id) {
  const base = `https://api-web.nhle.com/v1/gamecenter/${id}`;
  const [p, rr, ln] = await Promise.all([getJSON(base + '/play-by-play', 20000), getJSON(base + '/right-rail', 20000), getJSON(base + '/landing', 20000)]);
  if (!p) return null;
  const ex = nhlSummary(rr, ln, (p.homeTeam || {}).abbrev, (p.awayTeam || {}).abbrev);
  ex.penalties = nhlPenalties(p);
  ex.outcome = { REG: 'normaaliajalla', OT: 'jatkoajalla', SO: 'rankkareilla' }[String((p.gameOutcome || {}).lastPeriodType || '').toUpperCase()] || null;
  return { detail: nhlGameDetail(p), extras: ex };
}

/** Kokoonpano boxscoresta; NHL ei julkaise ketjuja, joten ne arvioidaan peliajan perusteella. */
async function fetchNHLLineup(id) {
  const base = `https://api-web.nhle.com/v1/gamecenter/${id}`;
  const [box, p] = await Promise.all([getJSON(base + '/boxscore', 20000), getJSON(base + '/play-by-play', 20000)]);
  const stats = box && box.playerByGameStats; if (!stats) return null;
  const roster = {}; for (const r of (p && p.rosterSpots) || []) roster[r.playerId] = r;
  const goals = {}, assists = {};
  for (const pl of (p && p.plays) || []) {
    if (pl.typeDescKey !== 'goal' || !pl.details || String((pl.periodDescriptor || {}).periodType || '').toUpperCase() === 'SO') continue;
    const n = (pl.periodDescriptor || {}).number || 1, det = pl.details;
    const note = { time: nhlClockStr((n - 1) * 1200 + nhlSecs(pl.timeInPeriod)), period: n, score: `${det.homeScore ?? 0}–${det.awayScore ?? 0}` };
    if (det.scoringPlayerId != null) (goals[det.scoringPlayerId] = goals[det.scoringPlayerId] || []).push(note);
    for (const a of [det.assist1PlayerId, det.assist2PlayerId]) if (a != null) (assists[a] = assists[a] || []).push(note);
  }
  const build = (ts, team) => {
    if (!ts) return []; const out = [];
    const mk = (b, role, line) => {
      const r = roster[b.playerId]; const last = (r && r.lastName && r.lastName.default) || (b.name && b.name.default ? b.name.default.split('. ').pop() : '?');
      return { id: b.playerId, team, name: last, first: (r && r.firstName && r.firstName.default) || '', jersey: b.sweaterNumber ?? (r && r.sweaterNumber) ?? null, role, line, captain: false, alt: false, goals: goals[b.playerId] || [], assists: assists[b.playerId] || [] };
    };
    const byToi = (a, b) => nhlSecs(b.toi) - nhlSecs(a.toi);
    const fw = (ts.forwards || []).slice().sort(byToi);
    for (let g = 0; g < 4; g++) {
      if (g * 3 >= fw.length) break; const rest = fw.slice(g * 3, g * 3 + 3);
      const take = pos => { const i = rest.findIndex(x => x.position === pos); if (i >= 0) return rest.splice(i, 1)[0]; return rest.length ? rest.shift() : null; };
      const c = take('C'); if (c) out.push(mk(c, 'KH', g + 1));
      const l = take('L'); if (l) out.push(mk(l, 'VL', g + 1));
      const r = take('R'); if (r) out.push(mk(r, 'OL', g + 1));
    }
    fw.forEach((b, i) => { if (i >= 12) out.push(mk(b, `${i + 1}. H`, 5)); });
    (ts.defense || []).slice().sort(byToi).forEach((b, i) => { if (i < 6) out.push(mk(b, i % 2 === 0 ? 'VP' : 'OP', Math.floor(i / 2) + 1)); else out.push(mk(b, `${i + 1}. P`, 4)); });
    (ts.goalies || []).slice().sort(byToi).forEach((b, i) => out.push(mk(b, 'MV', i + 1)));
    return out;
  };
  return { home: build(stats.homeTeam, 'home'), away: build(stats.awayTeam, 'away'), note: 'NHL ei julkaise ketjuja: ketjut ja puolustusparit on arvioitu pelaajien peliajan perusteella.' };
}
