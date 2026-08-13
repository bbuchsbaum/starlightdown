# starlightdown 0.1.0 (2026-08-13)

First release. `starlightdown` compiles an R package's documentation into an
[Astro Starlight](https://starlight.astro.build/) site.

## Building a site

* `use_starlight_site()` scaffolds the Astro project, vendors the Starlight
  plugin into `starlight/.starlightdown/plugin/`, pins exact dependency
  versions, and ships a lockfile so CI can run `npm ci` immediately.

* `build_site()` compiles the package: reference topics rendered from `Rd`
  with examples executed against the installed namespace and figures
  captured, vignettes executed by Quarto, and `README.md`, `NEWS.md` and
  `inst/CITATION` rendered into the home, changelog and citation pages.

* `preview_site()` runs the Astro dev server.

* `use_starlight_github_actions()` writes a workflow that builds the site and
  deploys it to GitHub Pages.

## Configuration

* `_pkgdown.yml` is read directly and never rewritten. `url:` sets the site
  origin and base path; `reference:` sections (including `starts_with()` and
  the other selectors) group the function index and order the sidebar;
  `articles:` orders the article sidebar; `redirects:` becomes redirect pages.

* `migrate_from_pkgdown()` scaffolds the site if needed and reports what
  carries over and what has no equivalent. It converts nothing, so both site
  generators can run side by side.

* starlightdown-specific settings live under a `starlightdown:` key in
  `_pkgdown.yml`, keeping one configuration file.

## Behaviour worth knowing

* Old pkgdown URLs keep working: every `/reference/foo.html` gets a redirect
  page. These are static pages, so they work on GitHub Pages.

* The content tree is staged, validated, then swapped into place. A build that
  fails validation leaves the published site untouched, and a page whose
  source was deleted cannot survive as a stale file.

* Builds are deterministic: building twice without changes produces
  byte-identical output, so a generated site is reviewable in a diff.

* Two themes: a bundled editorial default, and `nova` via the maintained
  `starlight-theme-nova` plugin.
