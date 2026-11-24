// Two jobs:
// - Keeps the Godot engine (index.wasm, index.js and its audio worklets) on the
//   phone between deploys, so opening the game after an update doesn't download
//   the 10 MB engine again. Those files only change with the Godot version,
//   which the page passes as ?v= when it registers this worker (the deploy
//   workflow stamps it in); a new version gets a fresh cache and drops the old one.
// - Lets the installed app (manifest.webmanifest) open offline: the page, the
//   game data and the icons always come from the network when there is one (so
//   a deploy shows up at once, never an old build) and are kept as a copy that
//   is used only when the network fails.
const VERSION = new URL(self.location).searchParams.get('v') || '0';
const CACHE = 'nd-engine-' + VERSION;
const OFFLINE = 'nd-offline';
const ENGINE = /\/index\.(wasm|js|audio\.worklet\.js|audio\.position\.worklet\.js)$/;
const GAME = /\/(index\.html|index\.pck|index\.png|index\.icon\.png|index\.apple-touch-icon\.png|manifest\.webmanifest|icon-\d+\.png)?$/;

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
	event.waitUntil((async () => {
		for (const key of await caches.keys()) {
			if (key.startsWith('nd-engine-') && key !== CACHE) {
				await caches.delete(key);
			}
		}
		await self.clients.claim();
	})());
});

self.addEventListener('fetch', (event) => {
	const request = event.request;
	if (request.method !== 'GET') {
		return;
	}
	const url = new URL(request.url);
	if (url.origin !== self.location.origin) {
		return;
	}
	if (!url.search && ENGINE.test(url.pathname)) {
		event.respondWith(engineFile(request, url));
	} else if (request.mode === 'navigate' || GAME.test(url.pathname)) {
		event.respondWith(networkFirst(request, url));
	}
});

// Cache first: the engine never changes within a Godot version.
async function engineFile(request, url) {
	try {
		const cache = await caches.open(CACHE);
		const hit = await cache.match(url.pathname);
		if (hit) {
			return hit;
		}
		const response = await fetch(request);
		if (response.ok) {
			await cache.put(url.pathname, response.clone());
		}
		return response;
	} catch (error) {
		return fetch(request);
	}
}

// Network first, the saved copy only when offline. The page is saved under its
// path without the query (?v=...), so any link to it works offline.
async function networkFirst(request, url) {
	const key = url.pathname;
	try {
		const response = await fetch(request, {cache: 'no-cache'});
		if (response.ok) {
			const copy = response.clone();
			caches.open(OFFLINE).then((cache) => cache.put(key, copy)).catch(() => {});
		}
		return response;
	} catch (error) {
		const cache = await caches.open(OFFLINE);
		const hit = await cache.match(key) || (request.mode === 'navigate' ? await cache.match(new URL('./', self.registration.scope).pathname) : null);
		if (hit) {
			return hit;
		}
		throw error;
	}
}
