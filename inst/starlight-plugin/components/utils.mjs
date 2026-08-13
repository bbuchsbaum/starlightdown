/**
 * Shared helpers for the starlightdown components.
 *
 * Link convention: every internal path in `site.json` and in `sd:` frontmatter
 * is root-relative and carries NO site base — `/reference/add_one/`. The base is
 * applied here, once, at render time. R therefore never has to know whether the
 * site is deployed at a domain root or under a project-pages prefix.
 */

const BASE = (import.meta.env?.BASE_URL ?? '/').replace(/\/$/, '');

export function isExternal(href) {
	return typeof href === 'string' && /^(?:[a-z+]+:)?\/\//i.test(href);
}

/** Prefix an internal path with the site base. External URLs pass through. */
export function withBase(path) {
	if (typeof path !== 'string' || path === '') return path;
	if (isExternal(path) || path.startsWith('#') || path.startsWith('mailto:')) return path;
	return BASE + (path.startsWith('/') ? path : '/' + path);
}

/** Build a topic lookup that answers to a topic's name or any of its aliases. */
export function topicIndex(site) {
	const index = new Map();
	for (const [key, topic] of Object.entries(site.topics ?? {})) {
		index.set(key, topic);
		for (const alias of topic.aliases ?? []) {
			if (!index.has(alias)) index.set(alias, topic);
		}
	}
	return index;
}

/**
 * Resolve one `sd.seealso` entry to something renderable.
 * Unresolvable entries render as plain text rather than as a dead link.
 */
export function resolveSeeAlso(item, index) {
	if (typeof item === 'string') {
		const topic = index.get(item);
		return topic
			? { label: item, href: withBase(topic.route), external: false }
			: { label: item, href: null, external: false };
	}
	if (!item || typeof item !== 'object' || !item.name) return null;
	if (item.href) {
		return { label: item.name, href: withBase(item.href), external: isExternal(item.href) };
	}
	const topic = index.get(item.name);
	return topic
		? { label: item.name, href: withBase(topic.route), external: false }
		: { label: item.name, href: null, external: false };
}

/**
 * Where a topic's source lives. `package.urls.source` wins when R supplies it
 * (it knows the forge); otherwise guess from the repository URL.
 */
export function sourceUrl(site, source) {
	if (!source) return null;
	if (isExternal(source)) return source;
	const urls = site.package?.urls ?? {};
	const path = source.replace(/^\//, '');
	if (urls.source) return urls.source.replace(/\/$/, '') + '/' + path;
	const repo = urls.repo?.replace(/\/+$/, '');
	if (!repo) return null;
	if (/gitlab/i.test(repo)) return `${repo}/-/blob/HEAD/${path}`;
	return `${repo}/blob/HEAD/${path}`;
}

export const LIFECYCLE_LABELS = {
	experimental: 'Experimental',
	stable: 'Stable',
	deprecated: 'Deprecated',
	superseded: 'Superseded',
};

export const LIFECYCLE_DESCRIPTIONS = {
	experimental: 'The interface may change without a deprecation cycle.',
	stable: 'The interface is settled and changes will follow a deprecation cycle.',
	deprecated: 'Scheduled for removal; prefer the documented replacement.',
	superseded: 'Still maintained, but a preferred alternative exists.',
};
