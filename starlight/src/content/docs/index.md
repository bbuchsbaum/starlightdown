---
title: 'starlightdown'
---

Experimental tooling to build documentation websites for R packages using Astro Starlight, piggy-backing on `{altdoc}` for Markdown rendering and `{pkgdown}` for navigation structure.

## Development
- Scaffold a Starlight site: `starlightdown::use_starlight_site()`
- Build/sync docs: `starlightdown::build_site(use_pkgdown_nav = TRUE)`
- Preview: run `npm run dev` inside the `starlight/` directory after building.
