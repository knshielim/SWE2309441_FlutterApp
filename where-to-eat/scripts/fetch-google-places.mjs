// Fetches restaurants and cafés around the off-campus XMUM areas from the
// Google Places API (New) and writes them to google-places.json for the site.
//
// Run by .github/workflows/pages.yml with the GOOGLE_PLACES_API_KEY secret.
// To run it yourself: GOOGLE_PLACES_API_KEY=... node scripts/fetch-google-places.mjs
//
// Each run makes about 32 requests (1 text search + 15 nearby searches per
// area), so a weekly run stays well inside Google's free monthly allowance.

import { writeFile } from 'node:fs/promises';

const KEY = process.env.GOOGLE_PLACES_API_KEY;

const AREAS = {
  sunsuria: { query: 'Bell Suites, Sunsuria City, Sepang, Selangor', radius: 1000 },
  warisan: { query: 'Kota Warisan, Sepang, Selangor', radius: 1800 },
};

// Nearby Search returns at most 20 places per request, so search a few
// smaller circles inside each area for each group of place types.
const TYPE_GROUPS = [
  ['restaurant'],
  ['fast_food_restaurant', 'meal_takeaway', 'food_court'],
  ['cafe', 'coffee_shop', 'bakery', 'dessert_shop', 'ice_cream_shop'],
];

const SNACK_TYPES = new Set(['coffee_shop', 'dessert_shop', 'ice_cream_shop', 'juice_shop', 'tea_house', 'confectionery']);

const FIELDS = [
  'id', 'displayName', 'location', 'shortFormattedAddress', 'formattedAddress', 'primaryType',
  'primaryTypeDisplayName', 'types', 'rating', 'userRatingCount', 'priceLevel', 'regularOpeningHours',
  'businessStatus', 'googleMapsUri', 'servesVegetarianFood',
].map(f => 'places.' + f).join(',');

async function call(endpoint, body, fieldMask) {
  const res = await fetch(`https://places.googleapis.com/v1/places:${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Goog-Api-Key': KEY, 'X-Goog-FieldMask': fieldMask },
    body: JSON.stringify(body),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`${endpoint} ${res.status}: ${json.error?.message || res.statusText}`);
  return json.places || [];
}

async function findCentre(query) {
  const [place] = await call('searchText', { textQuery: query, regionCode: 'MY', maxResultCount: 1 }, 'places.location');
  if (!place) throw new Error(`Could not find "${query}"`);
  return { lat: place.location.latitude, lon: place.location.longitude };
}

// Centre circle plus four overlapping circles to the north, east, south and west
function circlesFor({ lat, lon }, radius) {
  const dLat = (radius / 2) / 111320;
  const dLon = dLat / Math.cos(lat * Math.PI / 180);
  return [
    { lat, lon, radius },
    { lat: lat + dLat, lon, radius: radius * 0.6 },
    { lat: lat - dLat, lon, radius: radius * 0.6 },
    { lat, lon: lon + dLon, radius: radius * 0.6 },
    { lat, lon: lon - dLon, radius: radius * 0.6 },
  ];
}

const DAYS = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
const hhmm = (h, m) => `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;

// Google periods -> the opening_hours format the site understands,
// e.g. "Mo-Fr 08:00-17:00; Sa 09:00-13:00; Su off"
export function toHoursSpec(opening) {
  const periods = opening?.periods;
  if (!periods || !periods.length) return '';
  if (periods.length === 1 && !periods[0].close) return '24/7';
  const byDay = DAYS.map(() => []);
  for (const { open, close } of periods) {
    if (!open || !close) continue;
    const day = (open.day + 6) % 7; // Google: 0 = Sunday
    const end = close.day !== open.day && close.hour === 0 && close.minute === 0 ? '24:00' : hhmm(close.hour, close.minute);
    byDay[day].push(`${hhmm(open.hour, open.minute)}-${end}`);
  }
  const rules = [];
  for (let i = 0; i < 7;) {
    const ranges = byDay[i].join(',') || 'off';
    let j = i;
    while (j + 1 < 7 && (byDay[j + 1].join(',') || 'off') === ranges) j++;
    rules.push(`${i === j ? DAYS[i] : `${DAYS[i]}-${DAYS[j]}`} ${ranges}`);
    i = j + 1;
  }
  if (rules.length === 1 && rules[0].startsWith('Mo-Su ')) return rules[0].slice(6);
  return rules.join('; ');
}

const PRICE = { PRICE_LEVEL_INEXPENSIVE: 1, PRICE_LEVEL_MODERATE: 2, PRICE_LEVEL_EXPENSIVE: 3, PRICE_LEVEL_VERY_EXPENSIVE: 3 };

function toPlace(p) {
  return {
    id: 'g:' + p.id,
    name: p.displayName?.text || '',
    cuisine: p.primaryTypeDisplayName?.text || '',
    lat: p.location.latitude,
    lon: p.location.longitude,
    address: p.shortFormattedAddress || p.formattedAddress || '',
    hours: toHoursSpec(p.regularOpeningHours),
    googleRating: p.rating || 0,
    ratingCount: p.userRatingCount || 0,
    price: PRICE[p.priceLevel] || 0,
    veg: !!p.servesVegetarianFood,
    mapsUrl: p.googleMapsUri || '',
    closedTemporarily: p.businessStatus === 'CLOSED_TEMPORARILY',
    kind: SNACK_TYPES.has(p.primaryType) ? 'snack' : 'meal',
  };
}

// Google rejects the whole request if one type is unknown, so drop that type and retry
const badTypes = new Set();
async function searchNearby(types, c) {
  const included = types.filter(t => !badTypes.has(t));
  if (!included.length) return [];
  try {
    return await call('searchNearby', {
      includedTypes: included,
      maxResultCount: 20,
      rankPreference: 'POPULARITY',
      languageCode: 'en',
      regionCode: 'MY',
      locationRestriction: { circle: { center: { latitude: c.lat, longitude: c.lon }, radius: c.radius } },
    }, FIELDS);
  } catch (e) {
    const bad = included.find(t => e.message.includes(t));
    if (!/ 400:/.test(e.message) || !bad) throw e;
    console.warn(`  Google doesn't know the type "${bad}", leaving it out`);
    badTypes.add(bad);
    return searchNearby(types, c);
  }
}

async function main() {
  if (!KEY) throw new Error('GOOGLE_PLACES_API_KEY is not set.');
  const seen = new Set();
  const out = { generatedAt: new Date().toISOString(), areas: {} };
  let requests = 0, failures = 0;

  for (const [area, cfg] of Object.entries(AREAS)) {
    const centre = await findCentre(cfg.query);
    requests++;
    const places = [];
    for (const c of circlesFor(centre, cfg.radius)) {
      for (const types of TYPE_GROUPS) {
        requests++;
        let found;
        try {
          found = await searchNearby(types, c);
        } catch (e) {
          failures++;
          console.warn(`  skipped ${types.join('/')}: ${e.message}`);
          continue;
        }
        for (const p of found) {
          if (seen.has(p.id) || p.businessStatus === 'CLOSED_PERMANENTLY' || !p.location) continue;
          // The campus canteens already come from the cafeteria list
          if (/xiamen university|xmum/i.test(p.formattedAddress || '')) continue;
          seen.add(p.id);
          places.push(toPlace(p));
        }
      }
    }
    places.sort((a, b) => a.name.localeCompare(b.name));
    out.areas[area] = { centre, places };
    console.log(`${area}: ${places.length} places`);
  }

  if (failures === requests - Object.keys(AREAS).length) throw new Error('Every nearby search failed; keeping the old file.');
  await writeFile(new URL('../google-places.json', import.meta.url), JSON.stringify(out, null, 1) + '\n');
  console.log(`Wrote google-places.json (${requests} requests)`);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch(e => { console.error(e.message); process.exit(1); });
}
