# The R ↔ Astro contract

What R must produce for the Starlight frontend to render it. Everything here is
validated by an end-to-end build; the examples are taken verbatim from the
fixture site that build runs against.

Pinned versions: `astro` 7.2.1, `@astrojs/starlight` 0.41.7, `sharp` 0.35.3.
Starlight 0.41 requires `astro ^7.0.2` — the frontend cannot run on Astro 5.

---

## 1. Directory layout

```
starlight/
├── astro.config.mjs          user-owned, written once by use_starlight_site()
├── ec.config.mjs             user-owned, written once (3-line shim)
├── package.json              user-owned; R edits deps via jsonlite, never regex
├── package-lock.json         committed; `npm ci` in CI requires it
├── tsconfig.json             user-owned
├── public/                   R writes redirect stubs here (§6)
├── src/
│   ├── content.config.ts     user-owned
│   ├── styles/custom.css     user-owned, never rewritten
│   └── content/docs/         MACHINE-OWNED: replaced wholesale every build
└── .starlightdown/           MACHINE-OWNED: regenerated every build
    ├── plugin/               verbatim copy of inst/starlight-plugin/
    ├── site.json             the manifest
    ├── config.mjs            generated (§3)
    └── template-version      stamp used by sd_update_site()
```

`package.json` must contain `"starlightdown-starlight": "file:./.starlightdown/plugin"`.
npm symlinks it, so re-syncing `plugin/` takes effect without reinstalling.

**Ordering constraint:** `.starlightdown/plugin/` must exist before `npm ci`.
`build_site()` runs before the Node steps in CI, so it always does.

---

## 2. `site.json`

`schemaVersion: 1`. Deterministic: sorted keys, no timestamps.

```json
{
  "schemaVersion": 1,
  "generator": { "name": "starlightdown", "version": "0.1.0" },
  "site": {
    "url": "https://example.github.io",
    "base": "/testpkg",
    "theme": "default"
  },
  "package": {
    "name": "testpkg",
    "title": "Tools for Testing Things",
    "description": "Small arithmetic helpers used to exercise the renderer.",
    "version": "0.3.1",
    "license": "MIT + file LICENSE",
    "maintainer": { "name": "Ada Lovelace", "email": "ada@example.org" },
    "urls": {
      "homepage": "https://example.github.io/testpkg/",
      "repo": "https://github.com/example/testpkg",
      "bugs": "https://github.com/example/testpkg/issues",
      "cran": "https://cran.r-project.org/package=testpkg",
      "runiverse": "https://example.r-universe.dev/testpkg"
    }
  },
  "install": { "cran": "…", "runiverse": "…", "github": "…" },
  "citation": { "text": "…", "bibtex": "…" },
  "quickstart": "library(testpkg)\n\nx <- add_one(1:5)\ntimes_two(x)",
  "sidebar": [
    { "label": "Overview", "link": "/" },
    { "label": "Articles", "items": [{ "label": "Getting started", "link": "/articles/getting-started/" }] },
    { "label": "Reference", "items": [
      { "label": "Function index", "link": "/reference/" },
      { "label": "add_one", "link": "/reference/add_one/" }
    ] },
    { "label": "What's new", "link": "/news/" }
  ],
  "topics": {
    "add_one": {
      "name": "add_one",
      "route": "/reference/add_one/",
      "title": "add_one",
      "summary": "Add one to a numeric vector.",
      "lifecycle": "stable",
      "aliases": ["add_one", "add1"]
    }
  },
  "redirects": { "/reference/add_one.html": "/reference/add_one/" },
  "news": { "latest": "0.3.1", "route": "/news/" },
  "routes": [
    { "id": "reference/add_one", "route": "/reference/add_one/", "kind": "reference", "title": "add_one" }
  ]
}
```

### `site.url` and `site.base`

`url` is the **origin only** — scheme and host, no path. `base` is the path
prefix with a leading slash and no trailing slash (`"/"` when deployed at a
domain root). A pkgdown `url: https://user.github.io/pkg/` splits into
`url: "https://user.github.io"` and `base: "/pkg"`. Astro's sitemap composes
them; passing a path in `url` double-counts the base.

### `topics`

Keyed by topic name. `route` is base-less. `aliases` powers see-also resolution:
the frontend builds one name-or-alias → topic index at module scope, so R does
not need to emit a separate alias map.

### `install`, `citation`, `quickstart` — the homepage

Each is optional and each degrades to nothing rather than to an empty box.

`install` renders as synced tabs, **one tab per non-null entry**. A package not
yet on CRAN should have `"cran": null`, not an install line that fails —
verified: nulling `cran` and `github` leaves a single R-universe tab. Values are
the R code to run, verbatim:

| Key | Expected value |
| --- | --- |
| `cran` | `install.packages("pkg")` |
| `runiverse` | `install.packages("pkg", repos = c("https://user.r-universe.dev", getOption("repos")))` |
| `github` | `pak::pak("user/pkg")` |

`quickstart` is a plain R snippet — the first thing a reader should type. It is
rendered as a code block under the install tabs and **omitted entirely when
null**. R should take it from a `starlightdown: quickstart:` key in
`_pkgdown.yml`, or from the README's first R chunk after installation.

`citation` renders below the README: `text` as a hanging-indent reference,
`bibtex` folded into a `<details>` with an Expressive Code copy button.

### `site.theme`

`"default"` (or the older `"editorial-scientific"`) selects the bundled theme.
`"nova"` or `"ion"` select an external preset — see §11.

### `sidebar`

Starlight sidebar shape, as data. Apostrophes and unicode need no escaping —
verified: `"What's new"` renders as `What&#39;s new`. `link` values are
**base-less**; Starlight prefixes the base itself.

Lifecycle badges are **not** put here. The route middleware matches sidebar
links against `topics` and attaches a badge for `experimental`, `deprecated` and
`superseded`. An explicit `badge` on a sidebar entry wins.

---

## 3. `.starlightdown/config.mjs`

Generated verbatim in this shape. It reads `site.json` with `readFileSync`
rather than a JSON import assertion, which needs no Node flags and no
`with { type: 'json' }` support in the Astro config loader.

```js
// Generated by starlightdown 0.1.0. Do not edit — rewritten on every build.
import { readFileSync } from 'node:fs';
import starlightdown from 'starlightdown-starlight';

const manifest = JSON.parse(readFileSync(new URL('./site.json', import.meta.url), 'utf8'));

const social = [];
if (manifest.package.urls.repo?.includes('github.com')) {
	social.push({ icon: 'github', label: 'GitHub', href: manifest.package.urls.repo });
}

export const site = manifest.site.url;
export const base = manifest.site.base;

export const starlight = {
	title: manifest.package.title,
	description: manifest.package.description,
	favicon: '/favicon.svg',
	social,
	sidebar: manifest.sidebar,
	lastUpdated: false,
	customCss: ['./src/styles/custom.css'],
	plugins: [starlightdown({ manifest, theme: manifest.site.theme })],
};

export default { site, base, starlight, manifest };
```

With a theme preset, the only change is one extra import and one extra entry at
the *front* of `plugins` — see §11.

`customCss` here is the **user's** layer and is appended after the theme's, so
user rules win. Do not add theme CSS to it; the plugin injects its own.

---

## 4. Frontmatter

Validated by `sdSchema` through `docsSchema({ extend: sdSchema })`. A bad enum
or a mistyped key fails the build naming the file and the field.

**Division of labour: `sd:` carries only what markdown cannot express.** All
prose — description, details, argument descriptions, examples, references — is
plain GFM in the body.

```yaml
---
title: add_one
description: Add one to a numeric vector.
sd:
  kind: reference          # reference | reference-index | article | news | home
  name: add_one
  aliases: [add_one, add1] # include `name`; the header drops it from the chips
  usage: |
    add_one(x, na.rm = FALSE)

    add1(x, ...)
  lifecycle: stable        # experimental | stable | deprecated | superseded
  since: 0.2.0
  source: R/arith.R        # relative to the package root
  family: Arithmetic helpers
  seealso:
    - times_two                              # resolved against site.topics
    - name: sum                              # pre-resolved, e.g. from downlit
      package: base
      href: https://rdrr.io/r/base/sum.html
---
```

`kind` defaults to `article`. An unresolvable bare-string `seealso` renders as
plain text, never as a dead link.

`reference/index.md` carries the sections instead, and needs no body:

```yaml
sd:
  kind: reference-index
  groups:
    - title: Arithmetic
      desc: The functions you came for.
      topics:
        - name: add_one
          slug: /reference/add_one/    # base-less; falls back to site.topics
          summary: Add one to a numeric vector.
          lifecycle: stable
```

### Reference pages have no H1

The function name lives in `title`. Starlight renders it as the page H1, and the
plugin overrides `PageTitle` so reference pages get the mono name, alias chips,
lifecycle badge and source link in that slot — keeping Starlight's `id="_top"`
anchor and emitting exactly one H1. **Do not put a `# name` heading in the
body**; it would be a second H1.

For the same reason, strip the leading `# pkgname` from README when converting
it to `index.md`. CSS hides it as a fallback, but it still reaches the search
index.

### Home pages need no `hero:` block

`kind: home` is the whole signal. Starlight only renders its Hero slot when
`entry.data.hero` is set, so the route middleware sets it — R does not emit a
`hero:` block, and the frontmatter stays as it is above. The masthead's content
(name, tagline, version, license, links, install, quick start) all comes from
`site.json`.

### Changelog dates

Release dates are optional and travel in the markdown, not the manifest. R may
append a `<time>` element inside a version heading:

```markdown
## testpkg 0.3.1 <time datetime="2026-08-01">2026-08-01</time>
```

`news.css` styles it as small tracked caps beside the version chip. Omit it and
nothing breaks. This is markdown, not a manifest field, because a component
cannot reliably match a rendered heading back to a version string.

---

## 5. Links, paths and assets

| What | Convention |
| --- | --- |
| `site.json` routes, `sd.slug`, `sd.seealso[].href` | **base-less** (`/reference/add_one/`) — the frontend prefixes the base |
| Sidebar `link` | **base-less** — Starlight prefixes the base |
| Links in markdown **prose** | **base included** (`/testpkg/reference/add_one/`) |
| Images in markdown | **relative** (`figures/times_two-1.png`) |

The prose exception is forced by Astro 7: Starlight renders markdown with the
`satteri` processor, which does not run remark/rehype plugins, so there is no
supported hook to rewrite root-relative hrefs at build time. Setting
`markdown.processor: unified()` to get one back would change the whole markdown
pipeline for every site — too large a change to impose. R knows the base, so it
applies it.

Relative image paths are the right choice regardless: Astro's asset pipeline
resolves, optimizes and base-prefixes them. Verified — `figures/times_two-1.png`
became `/testpkg/_astro/times_two-1.CBUJYfeg_23OcGd.webp`. Quarto `_files/`
directories work the same way as long as the directory is copied next to the
`.md` that references it.

---

## 6. Redirects

**R writes static meta-refresh HTML into `starlight/public/`.** Astro's
`redirects` config is not usable here, on three counts, all observed:

1. With directory output, `redirects: { '/reference/add_one.html': … }` emits
   `dist/reference/add_one.html/index.html` — a *directory* named
   `add_one.html`, which no static host serves at `/reference/add_one.html`.
2. Astro does not apply the site base to the redirect target or the canonical
   URL, so both point outside the deployed site.
3. A key like `/news/index.html` collides with a real page's output path and
   fails the build outright with `EISDIR`.

`site.json.redirects` remains the data; R materializes it. Template:

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Redirecting to /testpkg/reference/add_one/</title>
<meta http-equiv="refresh" content="0; url=/testpkg/reference/add_one/">
<meta name="robots" content="noindex">
<link rel="canonical" href="https://example.github.io/testpkg/reference/add_one/">
</head>
<body>
<p>This page moved to <a href="/testpkg/reference/add_one/">/testpkg/reference/add_one/</a>.</p>
</body>
</html>
```

Targets and the canonical URL **include the base**. Escape `&`, `<` and `"`.

**Skip redirects whose source is already a valid route.** Under directory
output, `/reference/index.html` and `/news/index.html` are the new pages; a stub
there would overwrite them. This belongs in the validation gate: for every
redirect source, assert no generated route writes the same file.

---

## 7. Example cells

R emits a source block followed immediately by its output, using reserved info
strings. Blank lines between them are fine; other content between them is not —
the fusion is a CSS sibling selector.

````markdown
```r
add_one(c(1, NA, 3), na.rm = TRUE)
```

```r-message
Dropping 1 missing value.
```

```r-output
[1] 2 4
```
````

`r-output`, `r-message`, `r-warning`, `r-error`. The Expressive Code plugin
renders them unhighlighted and chrome-free, tags them `sd-output` /
`sd-output-<kind>`, marks them `data-pagefind-ignore="all"`, and hides the copy
button; CSS fuses each run onto the source block above it. Verified in the
built HTML:

```html
<div class="expressive-code">…source…</div>
<div class="expressive-code sd-output-block sd-output-message">
  <figure class="frame sd-output sd-output-message not-content" data-pagefind-ignore="all">
```

Figures follow as ordinary markdown images:
`![Doubled values plotted against their inputs.](figures/times_two-1.png)`

---

## 8. Expressive Code lives in `ec.config.mjs`

Not in the Starlight plugin. Astro serializes integration options to JSON so the
`<Code>` component can rebuild the renderer at runtime; a plugin object with
hook functions does not survive that, and every `<Code>` on the site fails with
*"Expressive Code options that are not serializable to JSON"*. The scaffold
ships a shim re-exporting `starlightdown-starlight/ec-config`. Options set there
are merged before Starlight's own preprocessor runs, so both the markdown
pipeline and `<Code>` see the same config.

---

## 9. Validation gates this contract implies

- Every `sd.seealso` bare string either resolves in `topics` or is intentionally
  plain text.
- Every markdown image target exists on disk relative to its `.md`.
- Every base-prefixed prose link matches a route in `routes` or a redirect
  source.
- No redirect source collides with a generated route's output path (§6).
- No reference body contains an H1.
- `routes` ↔ files in `src/content/docs/` is a bijection.

---

## 10. Notes for the Astro side

- Component overrides claimed: `Hero`, `PageTitle`, `MarkdownContent`,
  `PageSidebar`. All four are claimed unconditionally, and whatever held the
  slot before is rendered *inside* our markup via
  `virtual:starlightdown/inner/<Slot>`. Yielding a slot would drop the reference
  chrome and the `sd-kind` wrapper, so wrapping is the only composable option.
- `virtual:starlightdown/site` exposes the manifest to components; types in
  `virtual.d.ts`.
- `Astro.locals.starlightdown` = `{ kind, sd, topic }`, set by the route
  middleware, which also sets `entry.data.hero` on `kind: home` pages so
  Starlight reaches the Hero slot at all.
- All plugin JavaScript is `.mjs` with hand-written `.d.mts`/`.d.ts` alongside.
  Shipping `.ts` through a `file:` dependency risks Vite treating it as a
  pre-bundled dep; plain ESM removes the question.
- Expressive Code is **required**, not optional. If a theme preset or the user
  set `expressiveCode: false`, the plugin turns it back on: R's example cells
  are rendered by an EC plugin, and usage/install/citation are `<Code>`
  components that throw without it.
- Rebuilding after editing plugin source needs `astro build --force`: Astro's
  content layer caches rendered markdown and will otherwise reuse stale HTML.

---

## 11. Theme presets

`site.theme` selects the look. `"default"` ships the bundled Editorial
Scientific theme. Any other value names an external Starlight theme plugin.

**CSS split.** `styles/fallbacks.css` is always loaded first and defines every
`--sd-*` token in terms of Starlight's `--sl-*` variables. With the bundled
theme, `tokens.css` redefines them and wins. With a preset, the fallbacks stand
in, so the component CSS — fused code cells, argument tables, reference chrome,
changelog, homepage — keeps working against the preset's palette. Component CSS
must therefore never contain a literal colour or font stack; only `--sd-*` and
`--sl-*`.

Skipped under a preset: the @fontsource imports, `fonts.css`, `tokens.css`,
`base.css`. Kept: `fallbacks.css`, `code.css`, `tables.css`, `reference.css`,
`news.css`, `home.css`.

**What R must do for `theme: "nova"`:**

1. Add the package to `starlight/package.json` dependencies via jsonlite — never
   regex — and refresh the lockfile:
   `"starlight-theme-nova": "0.12.2"`.
2. Generate `config.mjs` with the preset imported and registered **before**
   `starlightdown()`:

```js
import starlightThemeNova from 'starlight-theme-nova';
import starlightdown from 'starlightdown-starlight';
// …
plugins: [starlightThemeNova(), starlightdown({ manifest, theme: manifest.site.theme })],
```

Order matters. Starlight applies plugins in array order; a preset registered
after starlightdown overwrites our override slots outright, whereas one
registered before is picked up and wrapped.

**Verified**: `theme: "nova"` builds clean. Nova's chrome, its `code-copy`
element and its `@layer nova` styles all render, wrapped by our `sd-kind-*`
containers; the reference header, fused output cells and install tabs are
intact; zero IBM Plex font files and zero Editorial Scientific palette literals
are emitted.

**`ion` is not currently usable.** `starlight-ion-theme@2.4.0` declares
`peerDependencies: { astro: "^6.0.0", "@astrojs/starlight": "^0.38" }` — it does
not support the Astro 7 / Starlight 0.41 stack this frontend requires. The
plugin handles `theme: "ion"` correctly (it skips the bundled theme CSS), but R
should not offer it until the package supports Astro 7.

---

## 12. Accessibility

Handled on the Astro side, no R involvement:

- Visible focus rings on every interactive element, drawn inside the element for
  the copy button and the tab strip, which clip their own overflow.
- Lifecycle badges carry a text label and a distinct dot *shape* per stage
  (diamond, filled disc, ring), so state survives greyscale and colour blindness.
  The compact index form pairs its dot with `.sr-only` text.
- All light/dark pairings are AA at body size; ratios are recorded at the top of
  `tokens.css`.
- Transitions are dropped under `prefers-reduced-motion: reduce`.
- Exactly one `<h1>` per page, keeping Starlight's `id="_top"` anchor so the skip
  link and table of contents stay correct.

**One note for R.** GFM tables emit `<th>` inside `<thead>` without a `scope`
attribute, and CSS cannot add one. Assistive technology treats a `thead` `th` as
a column header implicitly, so this is not a defect, and the argument-table
styling does not depend on `scope`. Emitting raw HTML tables purely to add
`scope="col"` would cost the markdown pipeline more than it gains — keep GFM
tables.
