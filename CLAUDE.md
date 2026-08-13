# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`starlightdown` is a documentation compiler for R packages targeting Astro Starlight. It reads the package the way pkgdown does, renders it to Markdown, and hands a typed manifest to a bundled Starlight plugin that does the presentation.

It does **not** wrap altdoc, and it is **not** a pkgdown fork. `_pkgdown.yml` stays canonical: the same `url:`, `reference:`, `articles:` and `redirects:` keys drive the new site, and nothing is ever rewritten.

## Commands

```r
devtools::test()                                   # full suite
testthat::test_file("tests/testthat/test-sync.R")  # one file
devtools::check()
devtools::document()
```

```bash
cd starlight && npm ci && npm run build   # the Astro side
```

## Architecture

Pipeline, in `build_site()`: **model → render → manifest → validate → commit**.

1. `sd_pkg()` wraps `pkgdown::as_pkgdown()` into the package model (topics, meta, vignettes, site URL, base). Synthesizes a default model when there is no `_pkgdown.yml`.
2. Reference pages come from a walker over `tools::parse_Rd`. Examples execute against the *installed* namespace with figures captured.
3. Articles are executed by the Quarto CLI to GFM; the `<name>_files/` directory is harvested alongside the Markdown.
4. README/NEWS/CITATION get adapters.
5. Everything is written to a staging directory, validated, then swapped into place atomically.

### The contract with the frontend

`inst/starlight-plugin/CONTRACT.md` is authoritative — read it before changing anything that crosses the boundary. Load-bearing invariants:

- **R emits no JavaScript and no MDX.** Structured data travels as `sd:` YAML frontmatter and `site.json`. This is deliberate: generating JS/JSX from R by string manipulation is what sank the previous implementation.
- `site.url` is **origin only**; `base` is separate. Putting a path in `url` double-counts the base in the sitemap.
- **Prose links carry the base; `site.json` routes, index slugs, and images do not.** `sd_apply_base_to_links()` is the single place the base is applied.
- Reference bodies contain **no H1** — the title comes from frontmatter and Starlight renders it.
- Every reference-index group needs a `title`, and every `lifecycle` value must be one of the schema's four. Both are validated in R because a violation surfaces only as a failed Astro build.
- Redirect stubs are static meta-refresh pages in `public/` (GitHub Pages ignores a Netlify `_redirects` file), and must skip any source colliding with a generated route.

### Key files

| Path | Role |
| --- | --- |
| `R/build_site.R` | pipeline orchestration |
| `R/package-model.R`, `R/topics-select.R` | pkgdown model, `contents:` selector resolution |
| `R/rd-parse.R`, `R/rd-render.R`, `R/rd-examples.R`, `R/links.R` | Rd → Markdown |
| `R/build-articles.R`, `R/quarto.R` | Quarto pipeline |
| `R/markdown-scan.R` | **fence-aware scanner** — every markdown regex must go through it |
| `R/manifest.R`, `R/sidebar.R`, `R/redirects.R` | `site.json` and what derives from it |
| `R/sync.R`, `R/validate.R` | staging, validation gates, atomic commit |
| `R/machine-dir.R`, `R/theme.R` | `.starlightdown/` generation, theme presets |
| `inst/starlight-plugin/` | the npm package vendored into each site |
| `inst/starlight-template/` | the scaffold (user-owned after copying) |

### Ownership inside a generated site

`starlight/.starlightdown/` is machine-owned and regenerated every build. Everything else — `astro.config.mjs`, `src/styles/custom.css`, `package.json` — belongs to the user. Edit `package.json` structurally via jsonlite, never as text.

### Themes

One bundled default (editorial/scientific: IBM Plex, paper-and-ink palette, fused code/output cells) plus `nova` via the maintained `starlight-theme-nova` plugin. `ion` is deliberately unavailable: `starlight-ion-theme` peers on Astro 6 / Starlight 0.38 and cannot run this stack.

Versions are pinned exactly — **Starlight 0.41.7 requires Astro 7**, not 5. The template ships `package-lock.json` because CI runs `npm ci`.

## Gotchas

- Set `STARLIGHTDOWN_CACHE_DIR` in anything that builds articles, or test runs pollute the real user cache.
- Iterating on plugin source needs `astro build --force`; Astro's content layer otherwise serves stale HTML.
- `R CMD build` copies the whole tree before `.Rbuildignore` applies, so a large `starlight/node_modules` slows every check.
- Fixtures live in `tests/testthat/fixtures/`: `testpkg.minimal` (no `_pkgdown.yml`) and `testpkg.full` (selectors, unicode and apostrophes in titles, `\tabular`/`\eqn`/`\Sexpr`, macros, vignettes, NEWS, CITATION). `testpkg.full` is installed into a temp library because examples need the namespace.
