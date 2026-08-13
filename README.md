# starlightdown

A documentation compiler for R packages targeting [Astro Starlight](https://starlight.astro.build/).

- **pkgdown-compatible**: `_pkgdown.yml` stays your canonical configuration — reference sections, article groupings, and redirects carry over.
- **Quarto-powered**: vignettes and articles are executed by Quarto to Markdown with figures, citations, and math intact.
- **Rd, rendered properly**: reference topics are compiled from Rd with executed examples, captured plots, and cross-package autolinking.
- **A genuinely first-class frontend**: a bundled Starlight plugin with an editorial, scientific default theme — typography-driven, restrained color, fused code/output cells.

> **Status**: under active reconstruction. The compiler pipeline described above is being rebuilt; APIs will change.

## Usage

```r
starlightdown::use_starlight_site()   # scaffold (once)
starlightdown::build_site()           # compile docs
starlightdown::preview_site()         # dev server (requires Node.js)
```

## Migrating from pkgdown

```r
starlightdown::migrate_from_pkgdown()
```

Old pkgdown `.html` URLs are preserved via generated redirect pages that work on GitHub Pages.
