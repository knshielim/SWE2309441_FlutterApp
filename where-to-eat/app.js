'use strict';

/* ---------- Storage ---------- */

const KEY = 'w2e.v1';
const NEARBY_CACHE_KEY = 'w2e.nearbyCache';

const defaultState = () => ({
  favourites: [],
  history: [],
  settings: {
    theme: 'auto',
    radius: 1000,
    source: 'both',
    location: null, // { lat, lon, label }
    xmum: false,
    xmumAreas: ['campus', 'sunsuria', 'warisan', 'favourites'],
    filters: { cuisine: '', list: '', price: 0, distance: 0, avoid: 0, meal: '', open: false, weighted: true, veg: false, halal: false, snacks: false },
  },
});

function loadState() {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return defaultState();
    const saved = JSON.parse(raw);
    const base = defaultState();
    return {
      favourites: Array.isArray(saved.favourites) ? saved.favourites : [],
      history: Array.isArray(saved.history) ? saved.history : [],
      settings: { ...base.settings, ...saved.settings, filters: { ...base.settings.filters, ...(saved.settings?.filters || {}) } },
    };
  } catch {
    return defaultState();
  }
}

let state = loadState();
let nearby = [];            // places from OpenStreetMap
const skipped = new Set();  // "Not today" for this session
let currentPick = null;
let xmumLive = { sunsuria: [], warisan: [] }; // OpenStreetMap places around the off-campus areas
const XMUM_LIVE_KEY = 'w2e.xmumLive';

function save() {
  try { localStorage.setItem(KEY, JSON.stringify(state)); }
  catch { toast('Could not save. Is storage full or blocked?'); }
}

/* ---------- Helpers ---------- */

const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
const uid = () => Math.random().toString(36).slice(2, 10) + Date.now().toString(36);

function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function titleCase(s) {
  return s.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
}

// "chinese;noodle" -> ["Chinese", "Noodle"]
function splitCuisine(s) {
  return String(s || '').split(/[;,]/).map(x => x.trim()).filter(Boolean).map(titleCase);
}

function distanceM(a, b) {
  if (!a || !b || a.lat == null || b.lat == null) return null;
  const R = 6371000, rad = Math.PI / 180;
  const dLat = (b.lat - a.lat) * rad, dLon = (b.lon - a.lon) * rad;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

function fmtDistance(m) {
  if (m == null) return '';
  const walk = Math.max(1, Math.round(m / 80));
  return (m < 1000 ? `${Math.round(m / 10) * 10} m` : `${(m / 1000).toFixed(1)} km`) + ` · ${walk} min walk`;
}

const priceLabel = p => (p > 0 ? '$'.repeat(p) : '');
const starsLabel = r => (r > 0 ? '★'.repeat(r) + '☆'.repeat(5 - r) : '');

function directionsUrl(p) {
  if (p.lat != null) return `https://www.google.com/maps/dir/?api=1&destination=${p.lat},${p.lon}`;
  if (p.area === 'campus') return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent('Xiamen University Malaysia ' + (p.block || ''))}`;
  if (p.address) return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(p.name + ' ' + p.address + (p.area ? ', Sepang' : ''))}`;
  return null;
}

let toastTimer;
function toast(msg, actionLabel, action) {
  const el = $('#toast');
  el.innerHTML = esc(msg) + (actionLabel ? ` <button class="btn small" id="toastAction">${esc(actionLabel)}</button>` : '');
  el.style.pointerEvents = actionLabel ? 'auto' : 'none';
  el.classList.add('show');
  if (actionLabel) $('#toastAction').onclick = () => { action(); el.classList.remove('show'); };
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove('show'), actionLabel ? 5000 : 2500);
}

/* ---------- Opening hours ----------
   Understands the common OpenStreetMap forms, e.g.
   "24/7", "Mo-Fr 08:00-17:00; Sa 09:00-13:00", "Mo,We 10:00-14:00,17:00-22:00", "Su off",
   and ranges past midnight like "18:00-02:00". Returns true/false, or null when unknown. */

const DAYS = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

function parseDays(spec) {
  const days = new Set();
  for (const part of spec.split(',')) {
    const p = part.trim();
    if (!p || p === 'PH' || p === 'SH') continue;
    const [a, b] = p.split('-').map(x => DAYS.indexOf(x.trim()));
    if (a < 0 || (b !== undefined && b < 0)) return null;
    if (b === undefined) { days.add(a); continue; }
    for (let i = a; ; i = (i + 1) % 7) { days.add(i); if (i === b) break; }
  }
  return days;
}

function parseTimes(spec) {
  const ranges = [];
  for (const part of spec.split(',')) {
    const m = part.trim().match(/^(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})$/);
    if (!m) return null;
    ranges.push([+m[1] * 60 + +m[2], +m[3] * 60 + +m[4]]);
  }
  return ranges;
}

function isOpenNow(spec, date = new Date()) {
  if (!spec) return null;
  const s = spec.trim();
  if (s === '24/7') return true;
  const today = (date.getDay() + 6) % 7;
  const yesterday = (today + 6) % 7;
  const now = date.getHours() * 60 + date.getMinutes();
  let todayResult = null;
  let fromYesterday = false;
  let anyRule = false;

  for (const raw of s.split(';')) {
    const rule = raw.trim();
    if (!rule) continue;
    const m = rule.match(/^((?:PH|SH|Mo|Tu|We|Th|Fr|Sa|Su)(?:\s*[-,]\s*(?:PH|SH|Mo|Tu|We|Th|Fr|Sa|Su))*)?\s*(.*)$/);
    const days = m[1] ? parseDays(m[1].replace(/\s+/g, '')) : new Set([0, 1, 2, 3, 4, 5, 6]);
    if (!days) return null;
    if (days.size === 0) continue; // public-holiday-only rule
    const timePart = m[2].trim();
    anyRule = true;
    if (/^(off|closed)$/i.test(timePart)) {
      if (days.has(today)) todayResult = false;
      continue;
    }
    const ranges = parseTimes(timePart);
    if (!ranges) return null;
    if (days.has(today)) {
      todayResult = ranges.some(([a, b]) => (b > a ? now >= a && now < b : now >= a));
    }
    if (days.has(yesterday) && ranges.some(([a, b]) => b <= a && now < b)) fromYesterday = true;
  }
  if (!anyRule) return null;
  return fromYesterday || todayResult === true;
}

const DAY_NAMES = { Mo: 'Mon', Tu: 'Tue', We: 'Wed', Th: 'Thu', Fr: 'Fri', Sa: 'Sat', Su: 'Sun', PH: 'Public holidays' };

// "Mo-Sa 10:00-24:00; Su off" -> "Mon-Sat 10am–12am · Sun closed"
function prettyHours(spec) {
  if (!spec) return '';
  if (spec.trim() === '24/7') return 'Open 24 hours';
  return spec.split(';').map(r => r.trim()).filter(Boolean).join(' · ')
    .replace(/\b(Mo|Tu|We|Th|Fr|Sa|Su|PH)\b/g, d => DAY_NAMES[d])
    .replace(/\boff\b/gi, 'closed')
    .replace(/(\d{1,2}):(\d{2})/g, (_, h, m) => {
      h = +h % 24;
      return `${h % 12 || 12}${m === '00' ? '' : ':' + m}${h < 12 ? 'am' : 'pm'}`;
    })
    .replace(/(am|pm)-/g, '$1–')
    .replace(/,/g, ', ');
}

// Whether a place is good for a meal: uses the meals the user ticked, otherwise
// checks the opening hours at a typical time for that meal today.
const MEAL_TIMES = { breakfast: [8, 30], lunch: [12, 30], dinner: [19, 0], supper: [23, 0] };
function mealOk(p, meal) {
  if (p.meals && p.meals.length) return p.meals.includes(meal);
  if (!p.hours || !MEAL_TIMES[meal]) return true;
  const d = new Date();
  d.setHours(MEAL_TIMES[meal][0], MEAL_TIMES[meal][1], 0, 0);
  return isOpenNow(p.hours, d) !== false;
}

/* ---------- Location ---------- */

function setLocation(loc) {
  state.settings.location = loc;
  save();
  renderLocation();
}

function renderLocation() {
  const loc = state.settings.location;
  $('#locLabel').textContent = loc ? loc.label : 'No location set';
  $('#locChip').classList.toggle('on', !!loc);
}

function useMyLocation() {
  if (!navigator.geolocation) { toast('Your browser does not support location.'); return; }
  setNearbyStatus('Finding you…');
  navigator.geolocation.getCurrentPosition(async pos => {
    const loc = { lat: pos.coords.latitude, lon: pos.coords.longitude, label: 'My location' };
    setLocation(loc);
    reverseGeocode(loc);
    if (state.settings.xmum) { setNearbyStatus(''); renderAll(); }
    else await loadNearby(true);
  }, err => {
    setNearbyStatus(err.code === 1
      ? 'Location permission was denied. Search for an area instead.'
      : 'Could not get your location. Search for an area instead.');
  }, { enableHighAccuracy: true, timeout: 15000, maximumAge: 60000 });
}

async function reverseGeocode(loc) {
  try {
    const r = await fetch(`https://nominatim.openstreetmap.org/reverse?format=json&zoom=16&lat=${loc.lat}&lon=${loc.lon}`, { headers: { 'Accept-Language': navigator.language || 'en' } });
    const j = await r.json();
    const a = j.address || {};
    const label = a.university || a.college || a.suburb || a.neighbourhood || a.road || a.town || a.city;
    if (label && state.settings.location && state.settings.location.lat === loc.lat) {
      setLocation({ ...loc, label: `Near ${label}` });
    }
  } catch { /* label is optional */ }
}

async function searchArea(q) {
  const list = $('#placeResults');
  list.hidden = false;
  list.innerHTML = '<li><button disabled>Searching…</button></li>';
  try {
    const r = await fetch(`https://nominatim.openstreetmap.org/search?format=json&limit=5&q=${encodeURIComponent(q)}`, { headers: { 'Accept-Language': navigator.language || 'en' } });
    const results = await r.json();
    if (!results.length) { list.innerHTML = '<li><button disabled>No matches. Try a different name.</button></li>'; return; }
    list.innerHTML = results.map((p, i) => `<li><button data-i="${i}">${esc(p.display_name)}</button></li>`).join('');
    $$('button', list).forEach(b => b.onclick = () => {
      const p = results[+b.dataset.i];
      list.hidden = true;
      setLocation({ lat: +p.lat, lon: +p.lon, label: p.display_name.split(',')[0] });
      loadNearby(true);
    });
  } catch {
    list.innerHTML = '<li><button disabled>Search failed. Check your connection.</button></li>';
  }
}

/* ---------- Nearby (OpenStreetMap Overpass) ---------- */

// Public Overpass servers, tried in turn because any one of them can be busy
const OVERPASS = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.private.coffee/api/interpreter',
  'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
];

function setNearbyStatus(msg) { $('#nearbyStatus').textContent = msg; }

function osmToPlace(el) {
  const t = el.tags || {};
  const lat = el.lat ?? el.center?.lat, lon = el.lon ?? el.center?.lon;
  const addr = [t['addr:housenumber'], t['addr:street']].filter(Boolean).join(' ') || t['addr:full'] || '';
  const kind = { fast_food: 'Fast food', cafe: 'Café', food_court: 'Food court', restaurant: '' }[t.amenity] || '';
  return {
    id: `osm:${el.type}/${el.id}`,
    name: t.name || t['name:en'],
    cuisine: splitCuisine(t.cuisine).join(', ') || kind,
    kind,
    lat, lon,
    address: addr,
    hours: t.opening_hours || '',
    veg: ['yes', 'only'].includes(t['diet:vegetarian']) || ['yes', 'only'].includes(t['diet:vegan']),
    halal: ['yes', 'only'].includes(t['diet:halal']),
    website: t.website || t['contact:website'] || '',
    phone: t.phone || t['contact:phone'] || '',
    source: 'osm',
  };
}

async function fetchOverpass(query) {
  let lastErr;
  for (const url of OVERPASS) {
    try {
      const ctrl = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), 20000);
      const r = await fetch(url, { method: 'POST', body: 'data=' + encodeURIComponent(query), signal: ctrl.signal, headers: { 'Content-Type': 'application/x-www-form-urlencoded' } });
      clearTimeout(timer);
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      return await r.json();
    } catch (e) { lastErr = e; }
  }
  throw lastErr;
}

async function loadNearby(force = false) {
  const loc = state.settings.location;
  if (!loc) { setNearbyStatus('Set your location to see places around you.'); nearby = []; renderNearby(); updatePoolInfo(); return; }
  const radius = state.settings.radius;

  if (!force) {
    try {
      const c = JSON.parse(localStorage.getItem(NEARBY_CACHE_KEY) || 'null');
      if (c && c.radius === radius && distanceM(c, loc) < 100 && Date.now() - c.at < 30 * 60 * 1000) {
        nearby = c.places;
        setNearbyStatus('');
        renderNearby(); updatePoolInfo();
        return;
      }
    } catch { /* ignore broken cache */ }
  }

  setNearbyStatus('Looking for food nearby…');
  $('#refreshNearby').disabled = true;
  const q = `[out:json][timeout:25];nwr["amenity"~"^(restaurant|fast_food|cafe|food_court)$"]["name"](around:${radius},${loc.lat},${loc.lon});out center tags 300;`;
  try {
    const data = await fetchOverpass(q);
    const seen = new Set();
    nearby = data.elements.map(osmToPlace)
      .filter(p => p.name && p.lat != null && !seen.has(p.id) && seen.add(p.id))
      .map(p => ({ ...p, dist: distanceM(loc, p) }))
      .sort((a, b) => a.dist - b.dist);
    try { localStorage.setItem(NEARBY_CACHE_KEY, JSON.stringify({ lat: loc.lat, lon: loc.lon, radius, at: Date.now(), places: nearby })); } catch { /* cache is optional */ }
    setNearbyStatus(nearby.length ? '' : 'No places found on the map here. Try a bigger radius, or add your own in My places.');
  } catch {
    setNearbyStatus('The map servers are busy right now. Tap Refresh to try again in a minute. My places still work.');
  } finally {
    $('#refreshNearby').disabled = false;
  }
  renderNearby();
  updatePoolInfo();
}

/* ---------- Favourites ---------- */

const favByOsm = id => state.favourites.find(f => f.osmId === id);
const allXmum = () => [...XMUM_PLACES, ...xmumLive.sunsuria, ...xmumLive.warisan];
const findPlace = id => state.favourites.find(f => f.id === id) || nearby.find(p => p.id === id) || allXmum().find(p => p.id === id);

function visitsFor(place) {
  return state.history.filter(h => h.placeId === place.id || (place.osmId && h.placeId === place.osmId) || h.name === place.name).length;
}

function toggleFavFromNearby(id) {
  const existing = favByOsm(id);
  if (existing) {
    removeFav(existing.id);
    return;
  }
  const p = findPlace(id) || (currentPick && currentPick.id === id ? currentPick : null);
  if (!p) return;
  state.favourites.unshift({
    id: 'f_' + uid(), osmId: p.id, name: p.name, cuisine: p.cuisine, list: p.area ? XMUM_AREAS[p.area].short : '', price: 0, rating: 0,
    meals: [], veg: !!p.veg, halal: !!p.halal, hours: p.hours, address: p.address, notes: p.notes || '',
    lat: p.lat ?? null, lon: p.lon ?? null, source: p.source, area: p.area, block: p.block, kind: p.kind, createdAt: Date.now(),
  });
  save();
  toast(`Saved ${p.name} to My places`);
  renderAll();
}

function removeFav(id) {
  const idx = state.favourites.findIndex(f => f.id === id);
  if (idx < 0) return;
  const [removed] = state.favourites.splice(idx, 1);
  save();
  renderAll();
  toast(`Removed ${removed.name}`, 'Undo', () => {
    state.favourites.splice(idx, 0, removed);
    save();
    renderAll();
  });
}

let editingId = null;
let editingCoords = null;

function openFavDialog(id) {
  const f = id ? state.favourites.find(x => x.id === id) : null;
  editingId = f ? f.id : null;
  editingCoords = f && f.lat != null ? { lat: f.lat, lon: f.lon } : null;
  const form = $('#favForm');
  form.reset();
  $('#favDialogTitle').textContent = f ? 'Edit place' : 'Add a place';
  $('#deleteFavBtn').hidden = !f;
  if (f) {
    form.name.value = f.name;
    form.cuisine.value = f.cuisine || '';
    form.list.value = f.list || '';
    form.price.value = f.price || 0;
    form.rating.value = f.rating || 0;
    form.hours.value = f.hours || '';
    form.address.value = f.address || '';
    form.notes.value = f.notes || '';
    form.veg.checked = !!f.veg;
    form.halal.checked = !!f.halal;
    $$('input[name="meal"]', form).forEach(cb => { cb.checked = (f.meals || []).includes(cb.value); });
  }
  renderCoords();
  fillDatalists();
  $('#favDialog').showModal();
}

function renderCoords() {
  $('#favCoords').textContent = editingCoords ? `📌 ${editingCoords.lat.toFixed(5)}, ${editingCoords.lon.toFixed(5)}` : 'No map pin';
  $('#clearPinBtn').hidden = !editingCoords;
}

function saveFavFromForm() {
  const form = $('#favForm');
  const name = form.name.value.trim();
  if (!name) return false;
  const hours = form.hours.value.trim();
  if (hours && isOpenNow(hours) === null) {
    if (!confirm("I couldn't understand those opening hours, so the \"Open now\" filter will ignore them. Save anyway?")) return false;
  }
  const data = {
    name,
    cuisine: form.cuisine.value.trim(),
    list: form.list.value.trim(),
    price: +form.price.value,
    rating: +form.rating.value,
    hours,
    address: form.address.value.trim(),
    notes: form.notes.value.trim(),
    veg: form.veg.checked,
    halal: form.halal.checked,
    meals: $$('input[name="meal"]:checked', form).map(cb => cb.value),
    lat: editingCoords ? editingCoords.lat : null,
    lon: editingCoords ? editingCoords.lon : null,
  };
  if (editingId) {
    Object.assign(state.favourites.find(f => f.id === editingId), data);
    toast('Saved changes');
  } else {
    state.favourites.unshift({ id: 'f_' + uid(), source: 'custom', createdAt: Date.now(), ...data });
    toast(`Added ${name}`);
  }
  save();
  renderAll();
  return true;
}

function allCuisines() {
  const set = new Set();
  [...state.favourites, ...(state.settings.xmum ? allXmum() : nearby)].forEach(p => splitCuisine(p.cuisine).forEach(c => set.add(c)));
  return [...set].sort();
}
const allLists = () => [...new Set(state.favourites.map(f => f.list).filter(Boolean))].sort();

function fillDatalists() {
  const base = ['Chinese', 'Malay', 'Indian', 'Western', 'Japanese', 'Korean', 'Thai', 'Vietnamese', 'Mamak', 'Noodles', 'Rice', 'Café', 'Fast food', 'Dessert'];
  $('#cuisineOptions').innerHTML = [...new Set([...base, ...allCuisines()])].map(c => `<option value="${esc(c)}">`).join('');
  $('#listOptions').innerHTML = [...new Set(['Uni canteen', 'Near home', 'Date night', 'Cheap eats', ...allLists()])].map(c => `<option value="${esc(c)}">`).join('');
}

/* ---------- Rendering: place cards ---------- */

function placeCard(p, { saved, showArea = true }) {
  const loc = state.settings.location;
  const dist = distanceM(loc, p);
  const open = isOpenNow(p.hours);
  const visits = saved ? visitsFor(p) : 0;
  const meta = [
    p.cuisine && `<span>${esc(p.cuisine)}</span>`,
    p.list && `<span class="tag">${esc(p.list)}</span>`,
    p.price ? `<span>${priceLabel(p.price)}</span>` : '',
    p.rating ? `<span class="stars" aria-label="${p.rating} stars">${starsLabel(p.rating)}</span>` : '',
    open === true ? '<span class="open">Open now</span>' : open === false ? '<span class="closed">Closed now</span>' : '',
    showArea && p.area && XMUM_AREAS[p.area] ? `<span class="tag">${XMUM_AREAS[p.area].icon} ${esc(XMUM_AREAS[p.area].short)}</span>` : '',
    dist != null ? `<span>${fmtDistance(dist)}</span>` : '',
    p.veg ? '<span class="tag">Veg</span>' : '',
    p.halal ? '<span class="tag">Halal</span>' : '',
    visits ? `<span>Visited ${visits}×</span>` : '',
  ].filter(Boolean).join('');
  const dir = directionsUrl(p);
  const isFav = saved || !!favByOsm(p.id);
  const starAction = saved ? '' :
    `<button class="star-btn" data-action="fav-toggle" data-id="${esc(p.id)}" aria-label="${isFav ? 'Remove from' : 'Save to'} My places" title="${isFav ? 'Saved' : 'Save to My places'}">${isFav ? '★' : '☆'}</button>`;
  return `<li class="place">
    <div>
      <div class="title">${esc(p.name)}</div>
      <div class="meta">${meta}</div>
    </div>
    ${starAction || '<span></span>'}
    ${p.address ? `<div class="notes muted">📍 ${esc(p.address)}</div>` : ''}
    ${p.hours && p.source === 'xmum' ? `<div class="notes muted">🕘 ${esc(prettyHours(p.hours))}</div>` : ''}
    ${p.notes ? `<div class="notes">📝 ${esc(p.notes)}</div>` : ''}
    ${p.unverified && !p.hours ? '<div class="notes muted small">ℹ️ From web listings. Check the hours before you go.</div>' : ''}
    <div class="actions">
      <button class="btn small" data-action="pick-this" data-id="${esc(p.id)}">✅ Eat here</button>
      ${dir ? `<a class="btn small ghost" href="${dir}" target="_blank" rel="noopener">🧭 Directions</a>` : ''}
      ${p.website ? `<a class="btn small ghost" href="${esc(p.website)}" target="_blank" rel="noopener">🌐 Website</a>` : ''}
      ${saved ? `<button class="btn small ghost" data-action="edit-fav" data-id="${esc(p.id)}">✏️ Edit</button>` : ''}
    </div>
  </li>`;
}

function renderNearby() {
  const q = $('#nearbyFilter').value.trim().toLowerCase();
  const list = nearby.filter(p => !q || p.name.toLowerCase().includes(q) || (p.cuisine || '').toLowerCase().includes(q));
  $('#nearbyList').innerHTML = list.map(p => placeCard(p, { saved: false })).join('');
  if (nearby.length && !list.length) $('#nearbyList').innerHTML = '<li class="empty">Nothing matches that filter.</li>';
  if (map && !$('#nearbyMap').hidden) renderMapMarkers();
}

function renderFavourites() {
  const q = $('#favFilter').value.trim().toLowerCase();
  const listFilter = $('#favListFilter').value;
  const sort = $('#favSort').value;
  const loc = state.settings.location;
  let list = state.favourites.filter(f =>
    (!listFilter || f.list === listFilter) &&
    (!q || [f.name, f.cuisine, f.list, f.notes, f.address].join(' ').toLowerCase().includes(q)));
  const sorters = {
    recent: (a, b) => (b.createdAt || 0) - (a.createdAt || 0),
    name: (a, b) => a.name.localeCompare(b.name),
    rating: (a, b) => (b.rating || 0) - (a.rating || 0),
    visits: (a, b) => visitsFor(b) - visitsFor(a),
    distance: (a, b) => (distanceM(loc, a) ?? Infinity) - (distanceM(loc, b) ?? Infinity),
  };
  list.sort(sorters[sort]);
  $('#favCount').textContent = `${state.favourites.length} saved`;
  $('#favList').innerHTML = list.length
    ? list.map(f => placeCard(f, { saved: true })).join('')
    : state.favourites.length
      ? '<li class="empty">Nothing matches.</li>'
      : `<li class="empty">No saved places yet.<br><br>Tap <b>＋ Add a place</b> for spots that aren't on maps (like your uni canteen), or ☆ places in Nearby.</li>`;
}

function renderHistory() {
  const h = [...state.history].sort((a, b) => b.at - a.at);
  const weekAgo = Date.now() - 7 * 864e5;
  const counts = {};
  h.forEach(e => { counts[e.name] = (counts[e.name] || 0) + 1; });
  const top = Object.entries(counts).sort((a, b) => b[1] - a[1])[0];
  $('#stats').innerHTML = `
    <div class="stat"><b>${h.filter(e => e.at >= weekAgo).length}</b><span>meals this week</span></div>
    <div class="stat"><b>${Object.keys(counts).length}</b><span>places tried</span></div>
    <div class="stat"><b title="${esc(top ? top[0] : '')}">${top ? esc(top[0]) : '–'}</b><span>go-to spot</span></div>`;
  if (!h.length) {
    $('#historyList').innerHTML = '<li class="empty" style="display:block">No meals logged yet. When you pick a place, tap <b>✅ Eat here</b> and it shows up here, so you can skip places you just had.</li>';
    return;
  }
  let lastDay = '';
  const out = [];
  for (const e of h) {
    const d = new Date(e.at);
    const day = d.toLocaleDateString(undefined, { weekday: 'long', day: 'numeric', month: 'short' });
    if (day !== lastDay) { out.push(`<li class="history-day">${esc(day)}</li>`); lastDay = day; }
    out.push(`<li>
      <div class="h-main">
        <div class="h-name">${esc(e.name)}</div>
        <div class="h-date">${d.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })}</div>
      </div>
      <button class="btn small ghost" data-action="delete-history" data-id="${esc(e.id)}" aria-label="Delete entry">✕</button>
    </li>`);
  }
  $('#historyList').innerHTML = out.join('');
}

function renderFilterOptions() {
  const f = state.settings.filters;
  const cuisines = allCuisines();
  $('#fCuisine').innerHTML = '<option value="">Any</option>' + cuisines.map(c => `<option>${esc(c)}</option>`).join('');
  if (f.cuisine && !cuisines.includes(f.cuisine)) $('#fCuisine').insertAdjacentHTML('beforeend', `<option>${esc(f.cuisine)}</option>`);
  $('#fCuisine').value = f.cuisine;
  const lists = allLists();
  $('#fList').innerHTML = '<option value="">All my places</option>' + lists.map(c => `<option>${esc(c)}</option>`).join('');
  $('#fList').value = lists.includes(f.list) ? f.list : '';
  const favListSel = $('#favListFilter');
  const keep = favListSel.value;
  favListSel.innerHTML = '<option value="">All lists</option>' + lists.map(c => `<option>${esc(c)}</option>`).join('');
  favListSel.value = lists.includes(keep) ? keep : '';
}

function renderAll() {
  renderFilterOptions();
  renderNearby();
  renderXmum();
  renderFavourites();
  renderHistory();
  updatePoolInfo();
  if (currentPick) renderResult(currentPick, true);
}

/* ---------- Picking ---------- */

function readFilters() {
  const f = state.settings.filters;
  f.cuisine = $('#fCuisine').value;
  f.list = $('#fList').value;
  f.price = +$('#fPrice').value;
  f.distance = +$('#fDistance').value;
  f.avoid = +$('#fAvoid').value;
  f.meal = $('#fMeal').value;
  f.open = $('#fOpen').checked;
  f.weighted = $('#fWeighted').checked;
  f.veg = $('#fVeg').checked;
  f.halal = $('#fHalal').checked;
  f.snacks = $('#fSnacks').checked;
  save();
  const active = [f.cuisine, f.list, f.price, f.distance, f.avoid, f.meal, f.open, f.veg, f.halal, f.snacks].filter(Boolean).length;
  $('#filterCount').textContent = active || '';
}

function applyFiltersToUI() {
  const f = state.settings.filters;
  $('#fPrice').value = f.price;
  $('#fDistance').value = f.distance;
  $('#fAvoid').value = f.avoid;
  $('#fMeal').value = f.meal;
  $('#fOpen').checked = f.open;
  $('#fWeighted').checked = f.weighted;
  $('#fVeg').checked = f.veg;
  $('#fHalal').checked = f.halal;
  $('#fSnacks').checked = f.snacks;
  $$('#areaChips button').forEach(b => b.setAttribute('aria-pressed', state.settings.xmumAreas.includes(b.dataset.area)));
  $('#radius').value = String(state.settings.radius);
  $$('#sourceSeg button').forEach(b => b.classList.toggle('active', b.dataset.source === state.settings.source));
  $$('#sourceSeg button').forEach(b => b.setAttribute('aria-checked', b.dataset.source === state.settings.source));
}

function buildPool() {
  const f = state.settings.filters;
  const src = state.settings.source;
  const loc = state.settings.location;
  let pool = [];
  const savedRefs = new Set(state.favourites.map(p => p.osmId).filter(Boolean));
  if (state.settings.xmum) {
    const areas = state.settings.xmumAreas;
    const withFavs = areas.includes('favourites');
    if (withFavs) pool.push(...state.favourites.filter(p => !f.list || p.list === f.list));
    if (!f.list) pool.push(...allXmum().filter(p => areas.includes(p.area) && !(withFavs && savedRefs.has(p.id))));
  } else {
    if (src !== 'nearby') pool.push(...state.favourites.filter(p => !f.list || p.list === f.list));
    if (src !== 'favourites' && !f.list) pool.push(...nearby.filter(p => !savedRefs.has(p.id)));
  }
  const total = pool.length;
  const recentCutoff = Date.now() - f.avoid * 864e5;
  const recent = new Set(state.history.filter(h => h.at >= recentCutoff).flatMap(h => [h.placeId, h.name]));

  pool = pool.filter(p => {
    if (skipped.has(p.id)) return false;
    if (f.cuisine && !splitCuisine(p.cuisine).includes(f.cuisine)) return false;
    if (f.price && p.price > f.price) return false;
    if (f.distance) { const d = distanceM(loc, p); if (d != null && d > f.distance) return false; }
    if (f.avoid && (recent.has(p.id) || recent.has(p.osmId) || recent.has(p.name))) return false;
    if (f.meal && !mealOk(p, f.meal)) return false;
    if (!f.snacks && (p.kind === 'snack' || p.kind === 'store')) return false;
    if (f.open && isOpenNow(p.hours) === false) return false;
    if (f.veg && !p.veg) return false;
    if (f.halal && !p.halal) return false;
    return true;
  });
  return { pool, total };
}

function updatePoolInfo() {
  const { pool, total } = buildPool();
  const src = state.settings.source;
  let msg;
  if (!total) {
    msg = state.settings.xmum ? 'Choose at least one area above.'
      : src === 'favourites' ? 'You have no saved places yet. Add some in My places.'
      : src === 'nearby' && !state.settings.location ? 'Set your location in the Nearby tab first.'
        : !state.settings.location && !state.favourites.length ? 'Set your location in Nearby, or add places in My places to get started.'
          : 'Nothing to pick from yet.';
  } else {
    msg = `Picking from <b>${pool.length}</b> of ${total} places`;
    if (skipped.size) msg += ` · <a href="#" id="resetSkips">bring back ${skipped.size} skipped</a>`;
    if (state.settings.filters.open) {
      const unknown = pool.filter(p => isOpenNow(p.hours) === null).length;
      if (unknown) msg += ` · ${unknown} with unknown hours`;
    }
  }
  $('#poolInfo').innerHTML = msg;
  const reset = $('#resetSkips');
  if (reset) reset.onclick = e => { e.preventDefault(); skipped.clear(); updatePoolInfo(); };
  $('#spinBtn').disabled = $('#threeBtn').disabled = !pool.length;
}

function weightOf(p) {
  if (!state.settings.filters.weighted) return 1;
  const visits = Math.min(visitsFor(p), 10);
  return (p.rating ? p.rating : 2.5) + (state.favourites.includes(p) || favByOsm(p.id) ? 1 : 0) + visits * 0.1;
}

function weightedPick(pool, exclude = new Set()) {
  const options = pool.filter(p => !exclude.has(p.id));
  if (!options.length) return null;
  const total = options.reduce((s, p) => s + weightOf(p), 0);
  let r = Math.random() * total;
  for (const p of options) { r -= weightOf(p); if (r <= 0) return p; }
  return options[options.length - 1];
}

const reducedMotion = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;

async function spin() {
  const { pool } = buildPool();
  if (!pool.length) return;
  $('#choices').hidden = true;
  // Avoid repeating the previous pick when there's another option
  const winner = weightedPick(pool, pool.length > 1 && currentPick ? new Set([currentPick.id]) : new Set());
  const el = $('#result');
  el.hidden = false;
  el.className = 'result spinning';
  $('#spinBtn').disabled = true;
  if (!reducedMotion() && pool.length > 1) {
    let delay = 40;
    while (delay < 260) {
      const p = pool[Math.floor(Math.random() * pool.length)];
      el.innerHTML = `<div class="label">Hmm…</div><div class="name">${esc(p.name)}</div>`;
      await new Promise(r => setTimeout(r, delay));
      delay *= 1.15;
    }
  }
  $('#spinBtn').disabled = false;
  currentPick = winner;
  renderResult(winner);
  el.scrollIntoView({ behavior: reducedMotion() ? 'auto' : 'smooth', block: 'nearest' });
}

function giveThree() {
  const { pool } = buildPool();
  const picks = [];
  const ex = new Set();
  for (let i = 0; i < 3; i++) {
    const p = weightedPick(pool, ex);
    if (!p) break;
    picks.push(p); ex.add(p.id);
  }
  $('#result').hidden = true;
  currentPick = null;
  const box = $('#choices');
  box.hidden = false;
  box.innerHTML = `<h3>Pick one of these ${picks.length}</h3><ul class="place-list">${picks.map(p => placeCard(p, { saved: state.favourites.includes(p) })).join('')}</ul>`;
}

function renderResult(p, quiet = false) {
  const el = $('#result');
  if (!p) { el.hidden = true; return; }
  const dist = distanceM(state.settings.location, p);
  const open = isOpenNow(p.hours);
  const dir = directionsUrl(p);
  const meta = [p.cuisine, p.list || (p.area && XMUM_AREAS[p.area] ? XMUM_AREAS[p.area].short : ''), priceLabel(p.price), p.rating ? starsLabel(p.rating) : '', dist != null ? fmtDistance(dist) : '',
    open === true ? 'Open now' : open === false ? 'Closed now' : ''].filter(Boolean).map(esc).join(' · ');
  const savable = !state.favourites.includes(p) && !favByOsm(p.id);
  el.hidden = false;
  el.className = quiet ? 'result' : 'result done';
  el.innerHTML = `
    <div class="label">Let's eat at</div>
    <div class="name">${esc(p.name)}</div>
    ${meta ? `<div class="meta">${meta}</div>` : ''}
    ${p.address ? `<div class="meta">📍 ${esc(p.address)}</div>` : ''}
    ${p.hours && p.source === 'xmum' ? `<div class="meta">🕘 ${esc(prettyHours(p.hours))}</div>` : ''}
    ${p.notes ? `<div class="notes">“${esc(p.notes)}”</div>` : ''}
    ${p.unverified && !p.hours ? '<div class="meta small">ℹ️ Hours not checked. Look it up before you go.</div>' : ''}
    <div class="btn-row">
      <button class="btn primary" data-action="pick-this" data-id="${esc(p.id)}">✅ Eat here</button>
      ${dir ? `<a class="btn" href="${dir}" target="_blank" rel="noopener">🧭 Directions</a>` : ''}
      <button class="btn" data-action="share" data-id="${esc(p.id)}">📤 Share</button>
      ${savable ? `<button class="btn" data-action="fav-toggle" data-id="${esc(p.id)}">☆ Save</button>` : ''}
    </div>
    <div class="btn-row">
      <button class="btn ghost" id="againBtn">🔁 Spin again</button>
      <button class="btn ghost" id="notTodayBtn" title="Leave this place out until you reload">🙅 Not today</button>
    </div>`;
  $('#againBtn').onclick = spin;
  $('#notTodayBtn').onclick = () => {
    skipped.add(p.id);
    currentPick = null;
    updatePoolInfo();
    if (buildPool().pool.length) spin();
    else { el.hidden = true; toast('No places left. Loosen the filters or bring back skipped ones.'); }
  };
}

function logMeal(p) {
  state.history.push({ id: 'h_' + uid(), placeId: p.osmId || p.id, name: p.name, at: Date.now() });
  save();
  renderAll();
  toast(`Enjoy your meal at ${p.name}! 🍽`, 'Undo', () => {
    state.history.pop();
    save();
    renderAll();
  });
}

async function sharePick(p) {
  const dir = directionsUrl(p);
  const text = `Let's eat at ${p.name}!` + (p.address ? ` (${p.address})` : '');
  try {
    if (navigator.share) { await navigator.share({ title: 'Where2Eat', text, url: dir || undefined }); return; }
    await navigator.clipboard.writeText(dir ? `${text} ${dir}` : text);
    toast('Copied. Paste it in your group chat!');
  } catch (e) {
    if (e && e.name !== 'AbortError') toast('Could not share on this device.');
  }
}

/* ---------- Map ---------- */

let map, markerLayer;

function ensureMap() {
  if (map) return true;
  if (!window.L) { $('#nearbyMap').innerHTML = '<p class="status" style="padding:2rem">The map could not load. Check your connection.</p>'; return false; }
  map = L.map('nearbyMap');
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19, attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
  }).addTo(map);
  markerLayer = L.layerGroup().addTo(map);
  return true;
}

function renderMapMarkers() {
  if (!ensureMap()) return;
  markerLayer.clearLayers();
  const loc = state.settings.location;
  const bounds = [];
  if (loc) {
    L.circleMarker([loc.lat, loc.lon], { radius: 8, color: '#1c7ed6', fillOpacity: .9 }).addTo(markerLayer).bindPopup('You are here');
    bounds.push([loc.lat, loc.lon]);
  }
  const icon = (emoji) => L.divIcon({ html: `<span style="font-size:22px;line-height:1">${emoji}</span>`, className: '', iconSize: [24, 24], iconAnchor: [12, 22] });
  const popup = (p, saved) => `<b>${esc(p.name)}</b><br>${esc(p.cuisine || '')}<br>
    <button class="btn small" data-action="pick-this" data-id="${esc(p.id)}">✅ Eat here</button>
    ${saved ? '' : `<button class="btn small" data-action="fav-toggle" data-id="${esc(p.id)}">${favByOsm(p.id) ? '★ Saved' : '☆ Save'}</button>`}`;
  const q = $('#nearbyFilter').value.trim().toLowerCase();
  nearby.filter(p => !q || p.name.toLowerCase().includes(q) || (p.cuisine || '').toLowerCase().includes(q)).forEach(p => {
    if (favByOsm(p.id)) return;
    L.marker([p.lat, p.lon], { icon: icon('🍴'), title: p.name }).addTo(markerLayer).bindPopup(popup(p, false));
    bounds.push([p.lat, p.lon]);
  });
  state.favourites.filter(f => f.lat != null).forEach(f => {
    L.marker([f.lat, f.lon], { icon: icon('⭐'), title: f.name }).addTo(markerLayer).bindPopup(popup(f, true));
    bounds.push([f.lat, f.lon]);
  });
  if (loc) map.setView([loc.lat, loc.lon], state.settings.radius <= 1000 ? 16 : state.settings.radius <= 2000 ? 15 : 13);
  else if (bounds.length) map.fitBounds(bounds, { padding: [30, 30] });
  else map.setView([3.139, 101.687], 11);
}

/* ---------- Backup & sharing ---------- */

function exportData() {
  const blob = new Blob([JSON.stringify({ app: 'where2eat', version: 1, exportedAt: new Date().toISOString(), favourites: state.favourites, history: state.history }, null, 2)], { type: 'application/json' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `where2eat-backup-${new Date().toISOString().slice(0, 10)}.json`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}

function mergeData(data) {
  const favs = Array.isArray(data.favourites) ? data.favourites : [];
  const hist = Array.isArray(data.history) ? data.history : [];
  const favIds = new Set(state.favourites.map(f => f.id));
  const favKeys = new Set(state.favourites.map(f => f.osmId || f.name.toLowerCase()));
  let added = 0;
  for (const f of favs) {
    if (!f || typeof f.name !== 'string' || !f.name.trim()) continue;
    if (favIds.has(f.id) || favKeys.has(f.osmId || f.name.toLowerCase())) continue;
    state.favourites.push({ ...f, id: f.id || 'f_' + uid(), createdAt: f.createdAt || Date.now() });
    added++;
  }
  const histIds = new Set(state.history.map(h => h.id));
  for (const h of hist) {
    if (h && h.name && typeof h.at === 'number' && !histIds.has(h.id)) state.history.push(h);
  }
  save();
  renderAll();
  return added;
}

function importFile(file) {
  const reader = new FileReader();
  reader.onload = () => {
    try {
      const added = mergeData(JSON.parse(reader.result));
      toast(`Imported ${added} new place${added === 1 ? '' : 's'}`);
    } catch {
      toast("That file doesn't look like a Where2Eat backup.");
    }
  };
  reader.readAsText(file);
}

/* ---------- XMUM mode ---------- */

let xmumView = 'campus';
const normName = s => s.toLowerCase().replace(/\(.*?\)/g, '').replace(/[^a-z0-9]/g, '');

function setXmumMode(on) {
  state.settings.xmum = on;
  save();
  applyMode();
  const tab = location.hash.slice(1);
  if (on && tab === 'nearby') location.hash = '#xmum';
  else if (!on && tab === 'xmum') location.hash = '#nearby';
  if (on) { loadXmumLive(false); toast('XMUM mode on 🎓'); }
  else loadNearby(false);
}

function applyMode() {
  const on = state.settings.xmum;
  document.body.classList.toggle('xmum', on);
  $('#xmumBtn').setAttribute('aria-pressed', on);
  $('.tab[data-tab="nearby"]').hidden = on;
  $('.tab[data-tab="xmum"]').hidden = !on;
  $('#sourceSeg').hidden = on;
  $('#areaChips').hidden = !on;
  $('#heroSub').textContent = on
    ? 'Choose where to pick from: campus canteens, Sunsuria City or Kota Warisan.'
    : 'Choose where to pick from, tweak the filters, then spin.';
  renderAll();
}

// Adds OpenStreetMap places around each off-campus area to the built-in list.
async function loadXmumLive(force) {
  if (!force) {
    try {
      const c = JSON.parse(localStorage.getItem(XMUM_LIVE_KEY) || 'null');
      if (c && Date.now() - c.at < 24 * 3600 * 1000) { xmumLive = c.areas; renderAll(); return; }
    } catch { /* ignore broken cache */ }
  }
  $('#xmumStatus').textContent = 'Loading more places from the map…';
  $('#xmumRefresh').disabled = true;
  const known = new Set(XMUM_PLACES.map(p => normName(p.name)));
  const seen = new Set();
  const result = { sunsuria: [], warisan: [] };
  let failed = false;
  for (const area of ['sunsuria', 'warisan']) {
    const cfg = XMUM_AREAS[area];
    try {
      let centre = null;
      for (const q of cfg.geocode) {
        const r = await fetch(`https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=my&q=${encodeURIComponent(q)}`);
        const j = await r.json();
        if (j.length) { centre = { lat: +j[0].lat, lon: +j[0].lon }; break; }
      }
      if (!centre) continue;
      const data = await fetchOverpass(`[out:json][timeout:25];nwr["amenity"~"^(restaurant|fast_food|cafe|food_court)$"]["name"](around:${cfg.radius},${centre.lat},${centre.lon});out center tags 200;`);
      for (const el of data.elements) {
        const p = osmToPlace(el);
        const n = p.name ? normName(p.name) : '';
        if (!n || p.lat == null || seen.has(p.id)) continue;
        // Skip places already in the built-in list (including the campus canteens)
        if ([...known].some(k => k.length > 3 && n.length > 3 && (k.includes(n) || n.includes(k)))) continue;
        seen.add(p.id);
        result[area].push({ ...p, area, kind: 'meal' });
      }
    } catch { failed = true; }
  }
  $('#xmumRefresh').disabled = false;
  if (failed && !result.sunsuria.length && !result.warisan.length) {
    $('#xmumStatus').textContent = 'Could not load extra places from the map. Showing the built-in list.';
    return;
  }
  xmumLive = result;
  $('#xmumStatus').textContent = '';
  try { localStorage.setItem(XMUM_LIVE_KEY, JSON.stringify({ at: Date.now(), areas: result })); } catch { /* cache is optional */ }
  renderAll();
}

function renderXmum() {
  if (!state.settings.xmum) return;
  $$('#xmumAreaSeg button').forEach(b => b.classList.toggle('active', b.dataset.area === xmumView));
  const q = $('#xmumFilter').value.trim().toLowerCase();
  const openOnly = $('#xmumOpenOnly').checked;
  const places = allXmum().filter(p => p.area === xmumView &&
    (!q || [p.name, p.cuisine, p.address, p.notes].join(' ').toLowerCase().includes(q)) &&
    (!openOnly || isOpenNow(p.hours) !== false));
  const rank = p => ({ true: 0, null: 1, false: 2 })[String(isOpenNow(p.hours))];
  places.sort((a, b) => rank(a) - rank(b) || a.name.localeCompare(b.name));

  $('#xmumNote').textContent = xmumView === 'campus'
    ? 'Hours are from the cafeteria list updated 28 Sep 2026. Hours and off days may change.'
    : 'Places come from web listings and OpenStreetMap, so hours aren\'t checked. Missing a place? Add it in My places.';

  let html;
  if (!places.length) {
    html = '<li class="empty">Nothing matches.</li>';
  } else if (xmumView === 'campus') {
    const order = ['D6', 'LY3', 'B1', 'A3', 'IAEC', 'Music Island'];
    const blocks = [...new Set(places.map(p => p.block))].sort((a, b) => order.indexOf(a) - order.indexOf(b));
    html = blocks.map(bl => `<li class="history-day">${esc(blockLabel(bl))}</li>` +
      places.filter(p => p.block === bl).map(p => placeCard(p, { saved: false, showArea: false })).join('')).join('');
  } else {
    const loc = state.settings.location;
    if (loc) places.sort((a, b) => (distanceM(loc, a) ?? Infinity) - (distanceM(loc, b) ?? Infinity));
    html = places.map(p => placeCard(p, { saved: false, showArea: false })).join('');
  }
  $('#xmumList').innerHTML = html;
}

/* ---------- Tabs ---------- */

function showTab(name) {
  if (!['decide', 'nearby', 'xmum', 'favourites', 'history'].includes(name)) name = 'decide';
  $$('.panel').forEach(p => { p.hidden = p.id !== `tab-${name}`; });
  $$('.tab').forEach(t => {
    const on = t.dataset.tab === name;
    t.classList.toggle('active', on);
    t.setAttribute('aria-selected', on);
  });
  if (name === 'nearby' && map && !$('#nearbyMap').hidden) setTimeout(() => map.invalidateSize(), 0);
}

/* ---------- Events ---------- */

function bindEvents() {
  window.addEventListener('hashchange', () => showTab(location.hash.slice(1)));

  // Shared click handler for buttons inside cards, the result and map popups
  document.addEventListener('click', e => {
    const btn = e.target.closest('[data-action]');
    if (!btn) return;
    const id = btn.dataset.id;
    switch (btn.dataset.action) {
      case 'fav-toggle': toggleFavFromNearby(id); break;
      case 'edit-fav': openFavDialog(id); break;
      case 'pick-this': {
        const p = findPlace(id) || (currentPick && currentPick.id === id ? currentPick : null);
        if (p) { logMeal(p); currentPick = p; renderResult(p, true); $('#choices').hidden = true; }
        break;
      }
      case 'share': { const p = findPlace(id) || currentPick; if (p) sharePick(p); break; }
      case 'delete-history':
        state.history = state.history.filter(h => h.id !== id);
        save(); renderAll();
        break;
    }
  });

  $$('#sourceSeg button').forEach(b => b.onclick = () => {
    state.settings.source = b.dataset.source;
    save(); applyFiltersToUI(); updatePoolInfo();
  });
  ['#fCuisine', '#fList', '#fPrice', '#fDistance', '#fAvoid', '#fMeal', '#fOpen', '#fWeighted', '#fVeg', '#fHalal', '#fSnacks']
    .forEach(s => $(s).addEventListener('change', () => { readFilters(); updatePoolInfo(); }));
  $('#spinBtn').onclick = spin;
  $('#threeBtn').onclick = giveThree;

  // XMUM mode
  $('#xmumBtn').onclick = () => setXmumMode(!state.settings.xmum);
  $('#xmumToggle').onchange = e => setXmumMode(e.target.checked);
  $$('#areaChips button').forEach(b => b.onclick = () => {
    const areas = new Set(state.settings.xmumAreas);
    areas.has(b.dataset.area) ? areas.delete(b.dataset.area) : areas.add(b.dataset.area);
    state.settings.xmumAreas = [...areas];
    save(); applyFiltersToUI(); updatePoolInfo();
  });
  $$('#xmumAreaSeg button').forEach(b => b.onclick = () => { xmumView = b.dataset.area; renderXmum(); });
  $('#xmumFilter').oninput = renderXmum;
  $('#xmumOpenOnly').onchange = renderXmum;
  $('#xmumLocBtn').onclick = useMyLocation;
  $('#xmumRefresh').onclick = () => loadXmumLive(true);

  // Nearby
  $('#useLocBtn').onclick = useMyLocation;
  $('#placeSearch').onsubmit = e => { e.preventDefault(); const q = $('#placeQuery').value.trim(); if (q) searchArea(q); };
  $('#radius').onchange = () => { state.settings.radius = +$('#radius').value; save(); loadNearby(true); };
  $('#refreshNearby').onclick = () => loadNearby(true);
  $('#nearbyFilter').oninput = renderNearby;
  $$('#viewSeg button').forEach(b => b.onclick = () => {
    $$('#viewSeg button').forEach(x => x.classList.toggle('active', x === b));
    const isMap = b.dataset.view === 'map';
    $('#nearbyMap').hidden = !isMap;
    $('#nearbyList').hidden = isMap;
    if (isMap && ensureMap()) { map.invalidateSize(); renderMapMarkers(); }
  });
  $('#locChip').onclick = () => { location.hash = '#nearby'; };

  // Favourites
  $('#addFavBtn').onclick = () => openFavDialog(null);
  $('#favFilter').oninput = renderFavourites;
  $('#favListFilter').onchange = renderFavourites;
  $('#favSort').onchange = renderFavourites;
  $('#favForm').addEventListener('submit', e => {
    e.preventDefault();
    if (saveFavFromForm()) $('#favDialog').close();
  });
  $('#cancelFavBtn').onclick = () => $('#favDialog').close();
  $('#deleteFavBtn').onclick = () => { const id = editingId; $('#favDialog').close(); removeFav(id); };
  $('#pinHereBtn').onclick = () => {
    if (!navigator.geolocation) { toast('Location is not supported here.'); return; }
    $('#favCoords').textContent = 'Getting location…';
    navigator.geolocation.getCurrentPosition(
      pos => { editingCoords = { lat: pos.coords.latitude, lon: pos.coords.longitude }; renderCoords(); },
      () => { renderCoords(); toast('Could not get your location.'); },
      { enableHighAccuracy: true, timeout: 15000 });
  };
  $('#clearPinBtn').onclick = () => { editingCoords = null; renderCoords(); };

  // History
  $('#logMealBtn').onclick = () => {
    const form = $('#logForm');
    form.reset();
    const now = new Date();
    now.setMinutes(now.getMinutes() - now.getTimezoneOffset());
    form.when.value = now.toISOString().slice(0, 16);
    $('#allPlaceNames').innerHTML = [...new Set([...state.favourites, ...nearby, ...allXmum()].map(p => p.name))].map(n => `<option value="${esc(n)}">`).join('');
    $('#logDialog').showModal();
  };
  $('#cancelLogBtn').onclick = () => $('#logDialog').close();
  $('#logForm').addEventListener('submit', e => {
    e.preventDefault();
    const form = e.target;
    const name = form.name.value.trim();
    const at = new Date(form.when.value).getTime();
    if (!name || Number.isNaN(at)) return;
    const p = [...state.favourites, ...nearby, ...allXmum()].find(x => x.name === name);
    state.history.push({ id: 'h_' + uid(), placeId: p ? (p.osmId || p.id) : null, name, at });
    save(); renderAll();
    $('#logDialog').close();
    toast('Logged');
  });

  // Settings
  $('#settingsBtn').onclick = () => {
    $('#themeSel').value = state.settings.theme;
    $('#xmumToggle').checked = state.settings.xmum;
    $('#settingsDialog').showModal();
  };
  $('#themeSel').onchange = () => { state.settings.theme = $('#themeSel').value; save(); applyTheme(); };
  $('#exportBtn').onclick = exportData;
  $('#importFile').onchange = e => { if (e.target.files[0]) importFile(e.target.files[0]); e.target.value = ''; };
  $('#clearHistoryBtn').onclick = () => {
    if (confirm('Delete your whole meal history?')) { state.history = []; save(); renderAll(); toast('History cleared'); }
  };
  $('#resetBtn').onclick = () => {
    if (confirm('Erase all saved places, history and settings on this device? Export a backup first if you want to keep them.')) {
      localStorage.removeItem(KEY);
      localStorage.removeItem(NEARBY_CACHE_KEY);
      localStorage.removeItem(XMUM_LIVE_KEY);
      state = defaultState(); nearby = []; currentPick = null; skipped.clear();
      applyTheme(); applyFiltersToUI(); renderLocation(); applyMode();
      $('#result').hidden = true;
      $('#settingsDialog').close();
      toast('Everything erased');
    }
  };

  // Keyboard shortcut: Space / Enter on the Decide tab spins
  document.addEventListener('keydown', e => {
    if (e.key !== ' ' || $('#tab-decide').hidden || document.querySelector('dialog[open]')) return;
    if (['INPUT', 'SELECT', 'TEXTAREA', 'BUTTON', 'A', 'SUMMARY'].includes(document.activeElement.tagName)) return;
    e.preventDefault();
    if (!$('#spinBtn').disabled) spin();
  });
}

function applyTheme() {
  const t = state.settings.theme;
  if (t === 'auto') document.documentElement.removeAttribute('data-theme');
  else document.documentElement.setAttribute('data-theme', t);
}

function buildAreaChips() {
  $('#areaChips').innerHTML = Object.entries(XMUM_AREAS)
    .map(([k, a]) => `<button type="button" data-area="${k}">${a.icon} ${esc(a.short)}</button>`).join('') +
    '<button type="button" data-area="favourites">⭐ My places</button>';
  $('#xmumAreaSeg').innerHTML = Object.entries(XMUM_AREAS)
    .map(([k, a]) => `<button type="button" data-area="${k}">${a.icon} ${esc(a.short)}</button>`).join('');
}

/* ---------- Start ---------- */

function init() {
  applyTheme();
  buildAreaChips();
  applyFiltersToUI();
  renderLocation();
  bindEvents();
  applyMode();
  readFilters();
  showTab(location.hash.slice(1));
  if (state.settings.xmum) loadXmumLive(false);
  else loadNearby(false);

  if ('serviceWorker' in navigator && location.protocol.startsWith('http')) {
    navigator.serviceWorker.register('sw.js?v=3').catch(() => { /* offline support is optional */ });
    // When an update takes over from an older version, reload once so the new code runs
    const hadController = !!navigator.serviceWorker.controller;
    let reloaded = false;
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      if (hadController && !reloaded) { reloaded = true; location.reload(); }
    });
  }
}

init();
