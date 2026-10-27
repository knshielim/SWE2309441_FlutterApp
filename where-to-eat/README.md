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
