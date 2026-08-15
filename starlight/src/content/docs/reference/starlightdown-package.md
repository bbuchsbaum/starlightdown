---
title: starlightdown-package
description: 'starlightdown: Astro Starlight docs for R packages'
sd:
  kind: reference
  name: starlightdown-package
  aliases:
  - starlightdown
  - starlightdown-package
  source: man/starlightdown-package.Rd
---

`starlightdown` helps you build documentation websites for R packages
using the Astro [Starlight](https://starlight.astro.build/) theme.

## Details

Typical usage:

- [`use_starlight_site()`](/starlightdown/reference/use_starlight_site/) once, to scaffold a Starlight project.
- [`build_site()`](/starlightdown/reference/build_site/) whenever your package docs change.
- [`preview_site()`](/starlightdown/reference/preview_site/) during development, to run `npm run dev`.

Under the hood, `starlightdown` is a documentation compiler: it uses the
pkgdown package model for navigation and reference metadata, Quarto to
execute vignettes and articles, and renders Rd documentation directly to
Markdown with structured frontmatter consumed by a bundled Starlight
plugin.

## Author

**Maintainer**: Bradley R. Buchsbaum [brad.buchsbaum@gmail.com](mailto:brad.buchsbaum@gmail.com)

## See also

Useful links:

- <https://bbuchsbaum.github.io/starlightdown/>
- <https://github.com/bbuchsbaum/starlightdown>
- Report bugs at <https://github.com/bbuchsbaum/starlightdown/issues>
