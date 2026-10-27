# Where2Eat

A small website that helps you decide where to eat. It is plain HTML, CSS and JavaScript, so there is no build step and no API key.

## Features

- **Random pick**: spin for a random place from nearby restaurants, your own places, or both. "Give me 3" shows three options to choose from instead.
- **Nearby**: use your location or search an area (e.g. your campus). Restaurants, cafés, fast food and food courts come from OpenStreetMap. You can see them as a list or on a map.
- **My places**: save nearby places with ☆, or add places that aren't on any map (the uni canteen stall, a pasar malam). Each one can have a cuisine, a list (e.g. "Uni canteen"), price, your rating, meals it's good for, veg/halal, opening hours, an optional map pin and notes.
- **Filters**: cuisine, list, max price, max distance, meal, open now, vegetarian, halal, and "skip places I ate at in the last N days". You can also favour higher-rated places.
- **Not today**: leaves a place out for this session and spins again.
- **History and stats**: tap "Eat here" to log a meal. You see meals this week, places tried and your go-to spot.
- **Directions and sharing**: open Google Maps directions, or share the pick to a group chat.
- **Backup**: export or import your data as JSON to move it between devices or swap lists with friends.
- **Installable and works offline** (a PWA), with a dark mode and a phone-friendly layout.

## 🎓 XMUM student mode

Tap **🎓 XMUM** at the top, or turn it on in Settings. The app then picks only from:

- **Campus canteens**: all the stalls in blocks D6, LY3 and B1, plus the A3 / IAEC / Music Island cafés. Opening hours and off days come from the *Cafeteria Operation Hours 2026* list (updated 28 Sep 2026), so "Open now" and the meal filter know about Saturday/Sunday off days and suppers.
- **Bell Suites & Sunsuria City** and **Kota Warisan**: a starter list from public web listings, plus restaurants that OpenStreetMap has around each area. These places have no checked hours.
- **My places**, if you leave that chip on.

The **XMUM food** tab lets you browse each area (campus is grouped by block). Drinks, dessert and convenience-store stalls are left out of random picks unless you tick *Include drinks, desserts & convenience stores*.

To update canteen hours or add places, edit `xmum-data.js`.

### Getting every Bell Suites / Kota Warisan place from Google Maps

The off-campus areas can use Google's full list, with ratings, price levels and real opening hours. A GitHub Action (`.github/workflows/pages.yml`) runs `scripts/fetch-google-places.mjs` every Monday and saves the result to `google-places.json`. Visitors never call Google, so the API key stays secret and usage stays the same however many people use the site (about 32 requests a week, well within Google's free monthly allowance).

Until it's set up, the site uses the starter list and OpenStreetMap instead.

1. **Get an API key.** In the [Google Cloud console](https://console.cloud.google.com/), create a project and enable **Places API (New)**. Google asks you to add a billing account (card), but this usage fits in the free tier. Then go to **APIs & Services → Credentials → Create credentials → API key**. Under **API restrictions**, restrict the key to **Places API (New)**.
2. **Optional: cap usage so you can never be charged.** Go to **APIs & Services → Places API (New) → Quotas** and set the daily limits for "SearchNearby" and "SearchText" requests to something like 100.
3. **Add the key to GitHub.** In this repo, go to **Settings → Secrets and variables → Actions → New repository secret**. Name it `GOOGLE_PLACES_API_KEY` and paste the key.
4. **Let the Action publish the site.** Go to **Settings → Pages → Build and deployment → Source** and choose **GitHub Actions**.
5. **Run it now.** Go to **Actions → Update places and deploy site → Run workflow**. When it turns green, open the site. The XMUM food tab should say "from Google Maps, updated …".

After that, it refreshes by itself every Monday.


Data is stored in your browser (`localStorage`). Nothing is sent anywhere except the map lookups to OpenStreetMap.

## Opening hours format

These use the OpenStreetMap style, for example `Mo-Fr 08:00-17:00; Sa 09:00-13:00`, `Mo,We 11:00-14:00,17:00-22:00`, `Su off`, `24/7`, or past midnight like `18:00-02:00`.

## Run it

Location only works on `https://` or `localhost`, so serve the folder rather than opening the file directly:

```sh
cd where-to-eat
python3 -m http.server 8000
# open http://localhost:8000
```

To put it online, upload this folder to any static host (GitHub Pages, Netlify, Vercel, Cloudflare Pages).
