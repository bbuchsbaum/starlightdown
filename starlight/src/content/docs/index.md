---
title: Documentation Websites for R Packages with Astro Starlight
description: A documentation compiler for R packages targeting the 'Astro' 'Starlight'
  framework. Uses the 'pkgdown' package model for navigation and reference metadata,
  'Quarto' for executing vignettes and articles, and renders 'Rd' documentation directly
  to Markdown with structured frontmatter consumed by a bundled Starlight plugin.
  Configuration stays compatible with '_pkgdown.yml'.
sd:
  kind: home
---

starlightdown is a documentation-site generator for R packages that compiles your
`man/`, `vignettes/`, `README.md` and `NEWS.md` into an
[Astro Starlight](https://starlight.astro.build/) site. Use it as an alternative
to pkgdown when you want a faster, better-looking site without rewriting any
configuration: `_pkgdown.yml` stays canonical and is never modified.

> **Status:** 0.1.0, source-only. The pipeline is tested end to end, but the API
> may still change.

### Quick start

```r
# install.packages("pak")
pak::pak("bbuchsbaum/starlightdown")

starlightdown::use_starlight_site()   # scaffold starlight/, once
starlightdown::build_site()           # compile the docs
starlightdown::preview_site()         # serve at localhost:4321
```

`use_starlight_site()` writes an Astro project into `starlight/` with the
frontend plugin vendored in and dependency versions pinned, then runs
`npm install`. `build_site()` compiles the package into it: every `man/*.Rd`
topic becomes a page with its examples executed and plots captured, every
vignette is executed by Quarto, and your README, NEWS and CITATION become the
home, changelog and citation pages.

### Requirements

- **R** ≥ 4.1, and the package you are documenting **installed** — examples and
  vignettes are executed against the installed namespace, exactly as
  `example()` and `R CMD check` do.
- **Node.js** ≥ 22.12, for the Astro build.
- **Quarto**, only if the package has vignettes. `build_site(articles = FALSE)`
  and reference-only packages need no Quarto at all.

### What you get

- **Reference pages** compiled from Rd: executed examples with captured plots,
  argument tables, alias and lifecycle badges, and links resolved across
  packages via downlit.
- **Articles** executed by Quarto, with figures, math and citations intact and
  a freeze cache so unchanged vignettes are not re-run.
- **Navigation from `_pkgdown.yml`** — `reference:` sections (including
  `starts_with()` and the other selectors) group the function index and order
  the sidebar; `articles:` orders the article sidebar.
- **Working old URLs**: every `/reference/foo.html` gets a redirect page, as
  static HTML, so it works on GitHub Pages.
- **Search, dark mode and a deploy workflow** — search is built in via
  Pagefind, and `use_starlight_github_actions()` writes a GitHub Pages workflow.

### How a build behaves

The content tree is written to a staging directory, validated, and only then
swapped into place. Two consequences, both deliberate:

- A build that fails validation leaves the published site untouched, so you
  never ship a half-written tree.
- A page whose source you deleted cannot survive as a stale file, because the
  directory is replaced rather than written over.

Builds are deterministic: building twice without changes produces
byte-identical output, so a generated site is reviewable in a diff.

### Migrating from pkgdown

```r
starlightdown::migrate_from_pkgdown()
```

There is nothing to convert. This scaffolds the site if needed and reports what
your `_pkgdown.yml` means for the new site — what carries over, and what has no
equivalent, such as navbar dropdowns, pkgdown themes and HTML includes. Your
configuration is not rewritten, so both generators can run side by side.

### Fit and boundaries

A good fit for a package that already has a `_pkgdown.yml`, or none at all, and
wants a modern documentation site with executed examples and vignettes.

Current boundaries:

- Two themes: the bundled editorial default, and `nova` via
  [starlight-theme-nova](https://github.com/ocavue/starlight-theme-nova). The
  Ion theme cannot be offered yet — it requires Astro 6, and this stack is on
  Astro 7.
- pkgdown's multi-version `development` modes are not implemented; each build
  writes one site.
- Custom pkgdown templates, navbar components and HTML includes have no
  automatic equivalent. Astro integrations and
  `starlight/src/styles/custom.css` are where those go.
- Not on CRAN.

### Documentation

- [Getting started](/starlightdown/articles/getting-started/) — the full workflow,
  configuration, and what is machine-owned versus yours to edit.
- [Theming and authoring](/starlightdown/articles/authoring/) — changing colors, type and
  code style, which Starlight features a vignette can actually reach through
  Quarto, and how the same vignette renders on CRAN.
- [Deploying to GitHub Pages](/starlightdown/articles/deploying/) — what has to be true
  for the site to appear, and what to check when it does not.
- [Frontend contract](https://github.com/bbuchsbaum/starlightdown/blob/HEAD/inst/starlight-plugin/CONTRACT.md) — the manifest,
  frontmatter and component data shapes, for anyone extending the frontend.
- [Changelog](/starlightdown/news/)

### License

MIT © Bradley R. Buchsbaum
