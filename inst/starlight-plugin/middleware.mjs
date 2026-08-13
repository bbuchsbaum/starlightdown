/**
 * Route middleware.
 *
 * Two jobs, both of which every page needs and no component should repeat:
 *   1. Normalize the `sd:` frontmatter once and hang it off `locals` so the
 *      component tree can branch on `kind` without defensive `??` chains.
 *   2. Decorate sidebar links with lifecycle badges, using the manifest's topic
 *      map. Doing it here rather than in R keeps the sidebar pure data.
 */

import { defineRouteMiddleware } from '@astrojs/starlight/route-data';
import site from 'virtual:starlightdown/site';

/** Lifecycle stages worth interrupting a reader for. `stable` is the default. */
const BADGES = {
	experimental: { variant: 'caution', text: 'experimental' },
	deprecated: { variant: 'danger', text: 'deprecated' },
	superseded: { variant: 'note', text: 'superseded' },
};

const BASE = normalizeBase(import.meta.env.BASE_URL);

function normalizeBase(base) {
	if (!base || base === '/') return '';
	return base.endsWith('/') ? base.slice(0, -1) : base;
}

/** Turn a rendered href back into a manifest route (base-less, trailing slash). */
function toRoute(href) {
	if (typeof href !== 'string' || !href.startsWith('/')) return null;
	let route = BASE && href.startsWith(BASE + '/') ? href.slice(BASE.length) : href;
	if (route === '') route = '/';
	if (!route.endsWith('/')) route += '/';
	return route;
}

/** route -> topic, built once per module instance rather than per page. */
const topicsByRoute = new Map();
for (const topic of Object.values(site.topics ?? {})) {
	if (topic && typeof topic.route === 'string') {
		const route = topic.route.endsWith('/') ? topic.route : topic.route + '/';
		topicsByRoute.set(route, topic);
	}
}

function badgeSidebar(entries) {
	for (const entry of entries) {
		if (entry.type === 'group') {
			badgeSidebar(entry.entries);
			continue;
		}
		if (entry.badge) continue; // An explicit badge from the manifest wins.
		const topic = topicsByRoute.get(toRoute(entry.href));
		const badge = topic && BADGES[topic.lifecycle];
		if (badge) entry.badge = { ...badge };
	}
}

export const onRequest = defineRouteMiddleware((context) => {
	const route = context.locals.starlightRoute;
	const sd = route.entry.data.sd ?? {};
	const kind = sd.kind ?? 'article';

	/*
	 * Starlight only renders the Hero component when `entry.data.hero` is set.
	 * Setting it here rather than asking R to emit a `hero:` block keeps the
	 * frontmatter contract unchanged: `kind: home` is the whole signal. The Hero
	 * override reads the real content from the manifest, so the values below only
	 * need to be a valid shape.
	 */
	if (kind === 'home' && !route.entry.data.hero) {
		route.entry.data.hero = {
			title: site.package?.name || route.entry.data.title,
			tagline: site.package?.title ?? '',
			actions: [],
		};
	}

	context.locals.starlightdown = {
		kind,
		sd: {
			aliases: [],
			seealso: [],
			badges: [],
			...sd,
		},
		topic: topicsByRoute.get(toRoute(new URL(context.request.url).pathname)) ?? null,
	};

	if (Array.isArray(route.sidebar)) badgeSidebar(route.sidebar);
});
