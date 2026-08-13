# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`starlightdown` is an R package that generates documentation websites for R packages using Astro Starlight. It combines:
- `{altdoc}` for rendering package docs (README, NEWS, vignettes, man pages) to Markdown
- `{pkgdown}` (optional) for navigation structure via `_pkgdown.yml`
- Astro Starlight for the final rendered site

## Build & Development Commands

```r
# Install dependencies
install.packages(c("altdoc", "desc", "fs", "cli"))

# Run tests
devtools::test()

# Run a single test file
testthat::test_file("tests/testthat/test-example.R")

# Check package
devtools::check()

# Document (regenerate NAMESPACE and Rd files)
devtools::document()
```

## Usage Workflow

```r
# 1. Scaffold Starlight site (one-time)
starlightdown::use_starlight_site()

# 2. Build/sync docs (repeatable)
starlightdown::build_site()

# 3. Preview (requires npm install in starlight/)
starlightdown::preview_site()
```

### Migrating from pkgdown

```r
# 1. Scaffold Starlight site
starlightdown::use_starlight_site()

# 2. Migrate pkgdown configuration (reads _pkgdown.yml)
starlightdown::migrate_from_pkgdown()

# 3. Build as usual
starlightdown::build_site()
```

The migration function:
- Converts article/reference sections to Starlight sidebar
- Migrates homepage title/description
- Generates URL redirects from old `.html` URLs
- Reports items needing manual attention (navbar dropdowns, custom CSS, analytics)

For the Starlight site:
```bash
cd starlight/
npm install
npm run dev    # development server
npm run build  # production build
```

## Architecture

### Data Flow
1. `build_site()` calls `altdoc::render_docs()` to populate `docs/`
2. `sync_docs_to_starlight()` copies Markdown to `starlight/src/content/docs/` with mapping:
   - `README.md` → `index.md`
   - `vignettes/*` → `articles/*`
   - `man/*` → `reference/*`
3. `add_frontmatter_to_tree()` ensures Starlight-required frontmatter (`title:`) on every page
4. Optional: `generate_pkgdown_sidebar()` creates sidebar from `_pkgdown.yml` metadata

### Key Files
- `R/build_site.R` - Main orchestration, `build_with_altdoc()` helper
- `R/helpers.R` - `sync_docs_to_starlight()`, `ensure_frontmatter()`, `generate_pkgdown_sidebar()`, `set_theme_css()`, MDX conversion functions
- `R/migrate_pkgdown.R` - `migrate_from_pkgdown()` for pkgdown-to-starlightdown migration
- `R/use_starlight_site.R` - Scaffolds `starlight/` from template
- `inst/starlight-template/` - Astro Starlight project template with placeholders (`PKG_TITLE`, `PKG_SLUG`)

### Themes
Two CSS themes available: `bauhaus` (default) and `ion`. Theme CSS files live in:
- `inst/starlight-template/src/styles/` (bauhaus, nova base)
- `inst/themes/ion/` (ion theme)

## Important Patterns

- The `altdoc/` and `pkgdown/` directories in the repo root are reference clones, not part of the package (ignored via `.gitignore`)
- `build_site()` detects if `altdoc/` is a settings folder vs a clone and stages builds in temp dir if needed
- All synced Markdown files get frontmatter injected automatically; first H1 becomes the title
- Sidebar defaults to Starlight autogenerate by directory; pkgdown-driven sidebar is opt-in via `use_pkgdown_nav = TRUE`
