// Keeps the Godot engine (index.wasm, index.js and its audio worklets) on the
// phone between deploys, so opening the game after an update doesn't download
// the 10 MB engine again. Those files only change with the Godot version,
// which the page passes as ?v= when it registers this worker (the deploy
// workflow stamps it in); a new version gets a fresh cache and drops the old
// one. Everything else (the page, the game data) always comes from the network.
const VERSION = new URL(self.location).searchParams.get('v') || '0';
const CACHE = 'nd-engine-' + VERSION;
const ENGINE = /\/index\.(wasm|js|audio\.worklet\.js|audio\.position\.worklet\.js)$/;

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
	if (url.origin !== self.location.origin || url.search || !ENGINE.test(url.pathname)) {
		return;
	}
	event.respondWith((async () => {
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
	})());
});
