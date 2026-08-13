# Migration ------------------------------------------------------------------
#
# There is very little to migrate, and that is the point. `_pkgdown.yml` stays
# canonical: starlightdown reads the same `reference:`, `articles:`,
# `redirects:` and `url:` keys pkgdown does, so a package that already has one
# needs no conversion at all. What this function does is scaffold the site if
# it is missing and then tell the author, honestly, which parts of their
# pkgdown configuration carry over and which have no equivalent yet.

#' Migrate a pkgdown site to starlightdown
#'
#' Scaffolds the Starlight project if it is not there yet and reports what
#' your `_pkgdown.yml` means for the new site. **Nothing is rewritten**: your
#' `_pkgdown.yml` stays exactly as it is and remains the source of truth for
#' navigation, so you can run both site generators side by side.
#'
#' @param path Package root directory.
#' @param site_dir Starlight project directory, relative to `path`.
#' @param scaffold Create the Starlight project if it is missing?
#' @param quiet Suppress the printed report?
#'
#' @return Invisibly, a list with `carried` (settings that apply as-is),
#'   `manual` (settings needing attention) and `site_dir`.
#'
#' @seealso [build_site()], which does the actual work afterwards.
#' @export
#' @examples
#' \dontrun{
#' migrate_from_pkgdown()
#' build_site()
#' }
migrate_from_pkgdown <- function(path = ".",
                                 site_dir = "starlight",
                                 scaffold = TRUE,
                                 quiet = FALSE) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  if (!file.exists(file.path(path, "DESCRIPTION"))) {
    cli::cli_abort("No DESCRIPTION found at {.path {path}}.")
  }

  config_path <- sd_find_pkgdown_config(path)
  config <- if (is.null(config_path)) list() else sd_read_pkgdown_config(config_path)

  site_path <- file.path(path, site_dir)
  scaffolded <- FALSE
  if (!dir.exists(site_path) && isTRUE(scaffold)) {
    use_starlight_site(path = path, site_dir = site_dir, npm_install = FALSE)
    scaffolded <- TRUE
  }

  results <- list(
    config = config_path,
    site_dir = site_dir,
    scaffolded = scaffolded,
    carried = sd_migration_carried(config),
    manual = sd_migration_manual(config)
  )

  if (!isTRUE(quiet)) {
    sd_print_migration_report(results)
  }
  invisible(results)
}

#' @noRd
sd_find_pkgdown_config <- function(path) {
  candidates <- file.path(path, c("_pkgdown.yml", "_pkgdown.yaml", "pkgdown/_pkgdown.yml"))
  found <- candidates[file.exists(candidates)]
  if (length(found)) found[[1L]] else NULL
}

#' @noRd
sd_read_pkgdown_config <- function(config_path) {
  config <- tryCatch(yaml::read_yaml(config_path), error = function(e) {
    cli::cli_warn("Could not parse {.path {config_path}}: {conditionMessage(e)}")
    NULL
  })
  if (is.list(config)) config else list()
}

# What carries over -----------------------------------------------------------

# Everything here is read directly by the build; nothing has to be converted.
#' @noRd
sd_migration_carried <- function(config) {
  carried <- character()

  if (sd_is_string(config$url)) {
    carried <- c(carried, paste0(
      "{.field url} (", config$url, ") sets the site origin and base path"
    ))
  }
  # The counts are interpolated here rather than left as cli plural markers:
  # each bullet is glued on its own, so a `{?s}` would have no quantity in
  # scope by the time cli formats it.
  if (length(config$reference)) {
    n <- length(config$reference)
    carried <- c(carried, paste0(
      n, " {.field reference} ", if (n == 1L) "section becomes" else "sections become",
      " the function index and the sidebar order"
    ))
  }
  if (length(config$articles)) {
    n <- length(config$articles)
    carried <- c(carried, paste0(
      n, " {.field articles} ", if (n == 1L) "section orders" else "sections order",
      " the article sidebar"
    ))
  }
  if (length(config$redirects)) {
    n <- length(config$redirects)
    carried <- c(carried, paste0(
      n, " {.field redirects} ", if (n == 1L) "entry becomes" else "entries become",
      " redirect pages"
    ))
  }
  if (sd_is_string(config$home$title) || sd_is_string(config$home$description)) {
    carried <- c(carried, paste0(
      "{.field home} title/description are taken from DESCRIPTION instead; ",
      "set them there"
    ))
  }
  carried
}

# What does not ---------------------------------------------------------------

# The genuinely useful half of the old migration: pkgdown settings that have no
# equivalent, said plainly rather than silently dropped.
#' @noRd
sd_migration_manual <- function(config) {
  manual <- character()

  navbar <- config$navbar
  if (!is.null(navbar)) {
    if (!is.null(navbar$components) || !is.null(navbar$structure)) {
      manual <- c(manual, paste0(
        "Navbar components and dropdowns have no equivalent: Starlight's ",
        "sidebar is generated from {.field reference} and {.field articles}. ",
        "Add extra links in {.file astro.config.mjs}."
      ))
    }
    if (!is.null(navbar$structure$right) || !is.null(navbar$right)) {
      manual <- c(manual, paste0(
        "Right-side navbar items are placed by the theme; a repository link is ",
        "added automatically from the DESCRIPTION URL."
      ))
    }
  }

  template <- config$template
  if (!is.null(template)) {
    if (sd_is_string(template$package) && !identical(template$package, "pkgdown")) {
      manual <- c(manual, paste0(
        "Custom pkgdown theme {.pkg ", template$package, "} does not apply. ",
        "Choose a starlightdown theme, or add CSS to {.file src/styles/custom.css}."
      ))
    }
    if (!is.null(template$includes)) {
      manual <- c(manual, paste0(
        "Custom HTML includes (analytics, scripts) need to move into ",
        "{.file astro.config.mjs} or a Starlight component override."
      ))
    }
    if (!is.null(template$bootstrap) || !is.null(template$bslib)) {
      manual <- c(manual, "Bootstrap/bslib theming has no equivalent; the frontend is not Bootstrap.")
    }
    if (!is.null(template$params$ganalytics) || !is.null(config$analytics)) {
      manual <- c(manual, "Analytics need re-adding as a Starlight/Astro integration.")
    }
  }

  if (!is.null(config$development) && !identical(config$development$mode, "release")) {
    manual <- c(manual, paste0(
      "{.field development} mode is not implemented: every build writes one ",
      "site. Deploy dev docs to a separate base path instead."
    ))
  }

  if (!is.null(config$footer)) {
    manual <- c(manual, "Footer customisation is a Starlight component override.")
  }

  if (!is.null(config$search) || !is.null(config$template$params$docsearch)) {
    manual <- c(manual, paste0(
      "Search is built in (Pagefind) and needs no configuration; ",
      "any DocSearch keys can be dropped."
    ))
  }

  manual
}

# Report ----------------------------------------------------------------------

#' @noRd
sd_print_migration_report <- function(results) {
  if (is.null(results$config)) {
    cli::cli_inform(c(
      "i" = "No {.file _pkgdown.yml} found.",
      " " = "Nothing to migrate: the reference index will list every exported
             function, and articles will follow {.path vignettes/}."
    ))
  } else {
    cli::cli_inform(c(
      "v" = "Read {.path {results$config}}.",
      " " = "It stays canonical: starlightdown reads it directly, and this
             function changes nothing in it."
    ))
  }

  if (isTRUE(results$scaffolded)) {
    cli::cli_inform(c("v" = "Scaffolded {.path {results$site_dir}}."))
  }

  if (length(results$carried)) {
    cli::cli_inform("Carried over automatically:")
    cli::cli_bullets(stats::setNames(results$carried, rep("*", length(results$carried))))
  }

  if (length(results$manual)) {
    cli::cli_inform("Needs your attention:")
    cli::cli_bullets(stats::setNames(results$manual, rep("!", length(results$manual))))
  } else if (!is.null(results$config)) {
    cli::cli_inform(c("v" = "Nothing in this configuration needs manual work."))
  }

  cli::cli_inform(c("i" = "Next: run {.run starlightdown::build_site()}."))
  invisible(results)
}
