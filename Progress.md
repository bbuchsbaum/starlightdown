# Progress

## Status log
- Initialized notes and ignored local refs (`altdoc/`, `pkgdown/`).
- Drafted Vision, Plan, and Architecture documents for the starlightdown package concept.
- Scaffolded package skeleton: DESCRIPTION, LICENSE, NAMESPACE, R helpers (`use_starlight_site()`, `build_site()`, `preview_site()`, sync/frontmatter helpers), and Starlight template under `inst/starlight-template/`.
- Added `.Rbuildignore` to exclude docs and local reference clones from builds.

## Checklist
- [x] Implement doc sync and frontmatter helpers.
- [x] Run `devtools::document()` to regenerate Rd/NAMESPACE.
- [x] Update `URL` and `BugReports` in `DESCRIPTION` to the real repository.
- [x] Add pkgdown-driven sidebar generator.
- [x] Smoke-test in a sample package (`use_starlight_site()`, `build_site()`, then `npm install && npm run dev` in `starlight/`).
- [x] Resolve on-repo build path conflict with local `altdoc/` clone (staging build to temp dir).
- [ ] Add a minimal test (e.g., `ensure_frontmatter()` injects title when missing).
- [x] Add helper to scaffold GitHub Actions (starlight build/deploy).
- [ ] Re-run smoke test after fixing cli message glue in `build_site()`.
