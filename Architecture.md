# Architecture

## Components
- R package (`starlightdown`): orchestration helpers and templates.
- `{altdoc}`: renders README/NEWS/vignettes/man pages to Markdown in `docs/`.
- `{pkgdown}` (optional): supplies grouping/order via `_pkgdown.yml` (`as_pkgdown()` meta).
- Astro Starlight project: lives under `starlight/`; renders Markdown from `src/content/docs/`.

## Data flow
1. `build_site()` calls `altdoc::render_docs()` (initializing `altdoc/` if needed) to populate `docs/`.
2. `sync_docs_to_starlight()` copies Markdown into `starlight/src/content/docs/` with mapping:
   - `README.md -> index.md`
   - `vignettes/* -> articles/*`
   - `man/* -> reference/*`
   - other files copied relative to `docs/`.
3. `add_frontmatter_to_tree()` ensures Starlight-required frontmatter (`title:`) on every page.
4. Sidebar options:
   - Default: Starlight autogenerate by directory (articles/reference).
   - Future: generate sidebar from `pkgdown::as_pkgdown()` meta.
5. Optional: `npm run build`/`npm run dev` inside `starlight/` via helpers.

## Template (inst/starlight-template/)
- `astro.config.mjs` wires Starlight integration and imports `starlight.sidebar.mjs`.
- `starlight.sidebar.mjs` defaults to autogenerate Articles/Reference plus `index`.
- `src/content.config.ts` sets up Starlight docs collection.
- `src/content/docs/index.md` placeholder overwritten by README on first sync.
- `package.json` pins Astro/Starlight/sharp and runs `astro sync` postinstall.

## Design notes
- Prefer autogeneration with sane defaults, but allow pkgdown-driven ordering later.
- Keep Node footprint minimal; R side owns content and mapping.
- Ensure idempotent sync so repeated `build_site()` calls are safe.
