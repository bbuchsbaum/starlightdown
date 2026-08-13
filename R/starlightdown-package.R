#' starlightdown: Astro Starlight docs for R packages
#'
#' `starlightdown` helps you build documentation websites for R packages
#' using the Astro [Starlight](https://starlight.astro.build/) theme.
#'
#' Typical usage:
#' - [use_starlight_site()] once, to scaffold a Starlight project.
#' - [build_site()] whenever your package docs change.
#' - [preview_site()] during development, to run `npm run dev`.
#'
#' Under the hood, `starlightdown` is a documentation compiler: it uses the
#' pkgdown package model for navigation and reference metadata, Quarto to
#' execute vignettes and articles, and renders Rd documentation directly to
#' Markdown with structured frontmatter consumed by a bundled Starlight
#' plugin.
#'
#' @keywords internal
"_PACKAGE"
