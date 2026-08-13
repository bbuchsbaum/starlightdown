/**
 * starlightdown — Starlight plugin for R package documentation.
 *
 * The R side generates `.starlightdown/site.json` (the manifest) and
 * `.starlightdown/config.mjs`, which passes the parsed manifest to this plugin.
 * The plugin is responsible for everything the browser sees: the Editorial
 * Scientific theme, the reference-page chrome, the fused code/output cells, and
 * a `virtual:starlightdown/site` module carrying the manifest into components.
 *
 * R never emits JavaScript, CSS or MDX. It emits data; this file renders it.
 */

import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const PKG = 'starlightdown-starlight';

/**
 * `--sd-*` tokens aliased to Starlight's `--sl-*` variables. Always loaded, and
 * loaded first, so component CSS resolves every token it uses even when the
 * Editorial Scientific theme is replaced by an external preset.
 */
const FALLBACK_CSS = [`${PKG}/styles/fallbacks.css`];

/**
 * The Editorial Scientific theme: typefaces, palette, page rhythm. This is the
 * part an external preset replaces.
 */
const THEME_CSS = [
	'@fontsource/ibm-plex-serif/latin-400.css',
	'@fontsource/ibm-plex-serif/latin-ext-400.css',
	'@fontsource/ibm-plex-serif/latin-400-italic.css',
	'@fontsource/ibm-plex-serif/latin-600.css',
	'@fontsource/ibm-plex-serif/latin-ext-600.css',
	'@fontsource/ibm-plex-sans/latin-400.css',
	'@fontsource/ibm-plex-sans/latin-ext-400.css',
	'@fontsource/ibm-plex-sans/latin-500.css',
	'@fontsource/ibm-plex-sans/latin-600.css',
	'@fontsource/ibm-plex-sans/latin-ext-600.css',
	'@fontsource/ibm-plex-mono/latin-400.css',
	'@fontsource/ibm-plex-mono/latin-500.css',
	'@fontsource/ibm-plex-mono/latin-600.css',
	`${PKG}/styles/fonts.css`,
	`${PKG}/styles/tokens.css`,
	`${PKG}/styles/base.css`,
];

/**
 * Structural styles for the components this plugin injects: fused code cells,
 * argument tables, reference chrome, changelog, homepage. These reference only
 * `.sd-*` classes and `--sd-*`/`--sl-*` variables, never a literal colour, so
 * they layer onto any theme.
 */
const COMPONENT_CSS = [
	`${PKG}/styles/code.css`,
	`${PKG}/styles/tables.css`,
	`${PKG}/styles/reference.css`,
	`${PKG}/styles/news.css`,
	`${PKG}/styles/home.css`,
];

const OVERRIDES = {
	Hero: `${PKG}/components/overrides/Hero.astro`,
	PageTitle: `${PKG}/components/overrides/PageTitle.astro`,
	MarkdownContent: `${PKG}/components/overrides/MarkdownContent.astro`,
	PageSidebar: `${PKG}/components/overrides/PageSidebar.astro`,
};

/** What each claimed slot falls back to when nobody else has registered one. */
const SLOT_DEFAULTS = {
	Hero: '@astrojs/starlight/components/Hero.astro',
	PageTitle: '@astrojs/starlight/components/PageTitle.astro',
	MarkdownContent: '@astrojs/starlight/components/MarkdownContent.astro',
	PageSidebar: '@astrojs/starlight/components/PageSidebar.astro',
};

/** Theme values that mean "use the bundled Editorial Scientific theme". */
const BUNDLED_THEMES = new Set(['default', 'editorial-scientific']);

const VIRTUAL_ID = 'virtual:starlightdown/site';
const INNER_PREFIX = 'virtual:starlightdown/inner/';

/**
 * Astro integration exposing two kinds of virtual module:
 *
 *   `virtual:starlightdown/site`         the manifest, imported once per build
 *                                        instead of every page re-reading JSON.
 *   `virtual:starlightdown/inner/<Slot>` whatever component held that override
 *                                        slot before we claimed it.
 *
 * The second is what lets starlightdown compose with a theme preset. Our
 * overrides are structural — they inject the reference chrome and the `sd-kind`
 * wrapper — so yielding a slot to a theme would break reference pages outright.
 * Instead we always claim the slot and render the previous occupant inside our
 * own markup, so a preset's Hero or MarkdownContent still does its job.
 *
 * Entrypoint resolution mirrors Starlight's: bare specifiers pass through,
 * relative paths resolve against the project root.
 */
function starlightdownIntegration(manifest, inner, root) {
	const rootPath = fileURLToPath(root);
	const resolveEntrypoint = (id) => (id.startsWith('.') ? resolve(rootPath, id) : id);

	const modules = {
		[VIRTUAL_ID]: `export default ${JSON.stringify(manifest)};`,
	};
	for (const [slot, entrypoint] of Object.entries(inner)) {
		modules[INNER_PREFIX + slot] =
			`export { default } from ${JSON.stringify(resolveEntrypoint(entrypoint))};`;
	}

	const resolutions = new Map(Object.keys(modules).map((id) => [id, '\0' + id]));
	const bodies = new Map(Object.entries(modules).map(([id, body]) => ['\0' + id, body]));

	return {
		name: 'starlightdown-virtual-modules',
		hooks: {
			'astro:config:setup'({ updateConfig }) {
				updateConfig({
					vite: {
						plugins: [
							{
								name: 'vite-plugin-starlightdown',
								resolveId(id) {
									return resolutions.get(id);
								},
								load(id) {
									return bodies.get(id);
								},
							},
						],
					},
				});
			},
		},
	};
}

/** The empty manifest, so components can render before R has produced one. */
function normalizeManifest(manifest) {
	const m = manifest && typeof manifest === 'object' ? manifest : {};
	return {
		schemaVersion: 1,
		generator: { name: 'starlightdown', version: '0.0.0' },
		site: { url: '', base: '/', theme: 'default' },
		package: { name: '', title: '', version: '', urls: {} },
		install: {},
		citation: null,
		quickstart: null,
		sidebar: [],
		topics: {},
		redirects: {},
		news: null,
		...m,
	};
}

/**
 * @param {object} [options]
 * @param {object} [options.manifest] Parsed `site.json`.
 * @param {'default'|'editorial-scientific'|'nova'|'ion'|string} [options.theme]
 *   `'default'` ships the bundled Editorial Scientific theme. Any other value
 *   names an external Starlight theme plugin that the generated `config.mjs`
 *   registers *before* this one; the bundled fonts, palette and page rhythm are
 *   then skipped and only the structural component CSS is injected. Falls back
 *   to `manifest.site.theme`.
 */
export default function starlightdown(options = {}) {
	const manifest = normalizeManifest(options.manifest);
	const theme = options.theme ?? manifest.site?.theme ?? 'default';
	const bundledTheme = theme === true || theme == null || BUNDLED_THEMES.has(theme);

	return {
		name: 'starlightdown',
		hooks: {
			'config:setup'({ config, updateConfig, addIntegration, addRouteMiddleware, astroConfig }) {
				const css = bundledTheme
					? [...FALLBACK_CSS, ...THEME_CSS, ...COMPONENT_CSS]
					: [...FALLBACK_CSS, ...COMPONENT_CSS];

				/*
				 * Claim every slot, but remember who held it so we can render them
				 * inside our own markup. A theme preset registered before us keeps its
				 * Hero and MarkdownContent; we wrap rather than replace.
				 */
				const inner = {};
				const components = { ...config.components };
				for (const [slot, entrypoint] of Object.entries(OVERRIDES)) {
					inner[slot] = components[slot] ?? SLOT_DEFAULTS[slot];
					components[slot] = entrypoint;
				}

				/*
				 * Expressive Code is not optional here. R's example cells are rendered
				 * by an EC plugin, and the usage, install and citation blocks are
				 * `<Code>` components, which throw outright when the integration is
				 * missing. Some theme presets turn it off in favour of plain Shiki —
				 * starlight-theme-nova sets `expressiveCode: false` — so turn it back
				 * on. The options themselves live in the project's `ec.config.mjs`:
				 * Astro serializes integration options to JSON for `<Code>`, and our EC
				 * plugin object does not survive that trip.
				 */
				const ecDisabled = config.expressiveCode === false;

				updateConfig({
					components,
					// Ours first so the user's own `customCss` still has the last word.
					customCss: [...css, ...(config.customCss ?? [])],
					...(ecDisabled ? { expressiveCode: {} } : {}),
				});

				addRouteMiddleware({ entrypoint: `${PKG}/route-middleware` });
				addIntegration(starlightdownIntegration(manifest, inner, astroConfig.root));
			},
		},
	};
}
