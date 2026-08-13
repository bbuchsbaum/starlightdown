# Notes – starlightdown kickoff

## Vision and docs to create
- Target package name: starlightdown (confirmed; one earlier typo “startlightdown”).
- Project vision (for future `Vision.md`): make beautiful documentation websites for R packages by leveraging `{pkgdown}` for structure and `{altdoc}` for Markdown conversion, rendered via Astro Starlight.
- Planned doc files to author soon: `Plan.md`, `Architecture.md`, `Progress.md`, plus `Vision.md` with the above vision statement (altdoc repo: https://github.com/etiennebacher/altdoc).
- Local refs in CWD (ignore in Git): cloned `altdoc/` and `pkgdown/` for reference.
- Build ignores: `.gitignore` excludes `altdoc/`, `pkgdown/`; `.Rbuildignore` excludes docs and local clones from builds.

## Core concept
- “R (pkgdown + altdoc) = docs brain” and “Astro Starlight = docs face”.
- altdoc renders README/NEWS/vignettes/man pages to Markdown in `docs/`; pkgdown supplies structure/grouping via `_pkgdown.yml`; Starlight consumes Markdown from `src/content/docs/` and uses a sidebar config for navigation.

## Minimal glue workflow (current preferred approach)
1. In the R package root, run `altdoc::setup_docs(tool = "docsify"/"mkdocs"/"quarto_website")` then `altdoc::render_docs()` to produce Markdown in `docs/`.
2. Scaffold a Starlight site (separate dir, e.g. `starlight/`) via `npm create astro@latest -- --template starlight`.
3. Copy/symlink Markdown into `src/content/docs/` with layout mapping:
   - `README.md -> index.md`
   - `vignettes/* -> articles/*`
   - `man/* -> reference/*`
   - `NEWS -> changelog.md`, etc.
4. Ensure each `.md` has Starlight frontmatter (`title:`; optionally `description:`/`template: splash`). Add automatically if missing (use first H1 or filename as title).
5. (Optional) Generate sidebar config from pkgdown metadata via `pkgdown::as_pkgdown()` to mirror reference/article grouping; otherwise use Starlight’s autogenerate by directory.

## Pkgdown for navigation
- `_pkgdown.yml` defines `reference:` and `articles:`; `pkgdown::as_pkgdown()` exposes `pkg$meta$reference` and `pkg$meta$articles` for grouping/order.
- Sidebar in `astro.config.mjs` can be generated from that meta; Starlight supports explicit `sidebar: [{ slug: 'index' }, { label, items: [...] }, …]`.

## “Official” future direction
- Possibly add `tool = "starlight"` to altdoc: `setup_docs()` would drop Starlight-aware templates; `render_docs()` would expand `$ALTDOC_*` into Astro config and generate `src/content.config.ts`. More work but aligns with other altdoc tools.

## Proposed package skeleton (v0.0.1 draft)
- DESCRIPTION: MIT license, Title “Documentation Websites for R Packages with Astro Starlight”, Imports `{altdoc (>=0.7.0)`, `desc`, `fs`, `cli`}; Suggests `{pkgdown, usethis, testthat}`; Depends R >= 4.1.
- NAMESPACE via roxygen exporting `build_site`, `preview_site`, `use_starlight_site`; importing selected functions from altdoc/cli/desc/fs; pkgdown optional.
- `R/starlightdown-package.R`: package doc.
- `R/use_starlight_site.R`: scaffold `starlight/` from `inst/starlight-template`; read DESCRIPTION for pkg name/title; substitute placeholders in `astro.config.mjs` and `package.json`; optionally add build-ignore via usethis; overwrite guard.
- `R/build_site.R`: orchestrate build:
  - Validate DESCRIPTION and Astro config presence.
  - `build_with_altdoc()`: run `altdoc::setup_docs()` if needed, then `altdoc::render_docs()` to `docs/`.
  - `sync_docs_to_starlight()`: copy mapped Markdown into `starlight/src/content/docs/`.
  - `add_frontmatter_to_tree()`/`ensure_frontmatter()`: inject minimal frontmatter if missing.
  - Hooks for future pkgdown-based sidebar; optional `npm run build`.
- `R/helpers.R`: implements sync + frontmatter helpers (see above mappings; create directories; use first H1 or filename for title).
- `R/preview_site.R`: run `npm run dev` in `starlight/` (assumes deps installed).
- `.Rbuildignore` added to exclude docs and reference clones.

## Template contents (`inst/starlight-template/`)
- `astro.config.mjs`: uses Starlight integration, imports `starlight.sidebar.mjs`, sets site title placeholder `PKG_TITLE`.
- `starlight.sidebar.mjs`: default sidebar with `index` + autogenerate sections for `articles` and `reference`.
- `src/content.config.ts`: Starlight docs collection boilerplate (`docsLoader` + `docsSchema`).
- `src/content/docs/index.md`: placeholder frontmatter (`title: PKG_TITLE`, description) replaced by README on first build.
- `package.json`: minimal Astro/Starlight project (`@astrojs/starlight`, `astro`, `sharp`, `postinstall: astro sync`; name placeholder `PKG_SLUG-docs`).
- Optional additions later: `.gitignore`, `tsconfig.json`.

## Usage flow envisioned
- One-time: `starlightdown::use_starlight_site()` to scaffold `starlight/`.
- Repeat: `starlightdown::build_site()` to render docs via altdoc, sync into Starlight, add frontmatter, optionally `npm run build`.
- Dev: `starlightdown::preview_site()` to run Astro dev server.

## Open items / follow-ups
- Implement pkgdown-driven sidebar generation (from `pkgdown::as_pkgdown()`).
- Consider homepage splash frontmatter/template.
- Confirm package name spelling and finalize vision text in `Vision.md`.
