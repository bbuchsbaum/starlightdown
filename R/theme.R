# Themes ---------------------------------------------------------------------
#
# `site.theme` selects the look. `"default"` is the bundled Editorial
# Scientific theme; anything else names an external Starlight theme plugin,
# which has to be a real npm dependency and has to be registered *before*
# starlightdown in the plugin array (CONTRACT.md §11).

# Presets we can actually install. `ion` is deliberately absent:
# starlight-ion-theme@2.4.0 peers on astro ^6 / starlight ^0.38 and cannot
# resolve against the Astro 7 / Starlight 0.41 stack the frontend requires.
sd_theme_presets <- list(
  nova = list(package = "starlight-theme-nova", version = "0.12.2", import = "starlightThemeNova")
)

sd_themes <- c("default", names(sd_theme_presets))

#' Resolve the theme for a build
#'
#' @param pkg An `sd_pkg()` object.
#' @param theme Explicit choice; `NULL` reads `_pkgdown.yml`.
#' @noRd
sd_site_theme <- function(pkg, theme = NULL) {
  if (is.null(theme)) {
    theme <- pkg$meta$starlightdown$theme
  }
  if (!sd_is_string(theme)) {
    return("default")
  }

  theme <- tolower(trimws(theme))
  # The bundled theme's original name, still accepted.
  if (identical(theme, "editorial-scientific")) {
    return("default")
  }

  if (identical(theme, "ion")) {
    cli::cli_abort(c(
      "Theme {.val ion} cannot be used yet.",
      "x" = "{.pkg starlight-ion-theme} supports Astro 6 / Starlight 0.38; this
             frontend requires Astro 7 / Starlight 0.41.",
      "i" = "Available themes: {.val {sd_themes}}."
    ))
  }

  if (!theme %in% sd_themes) {
    cli::cli_abort(c(
      "Unknown theme {.val {theme}}.",
      "i" = "Available themes: {.val {sd_themes}}."
    ))
  }
  theme
}

#' Make `starlight/package.json` match the selected theme
#'
#' Edited through jsonlite rather than by rewriting text, and the lockfile is
#' refreshed so `npm ci` in CI installs what the config imports.
#' @noRd
sd_sync_theme_dependency <- function(site_path, theme, quiet = FALSE) {
  path <- fs::path(site_path, "package.json")
  if (!fs::file_exists(path)) {
    return(invisible(FALSE))
  }

  manifest <- jsonlite::read_json(path)
  deps <- manifest$dependencies %||% list()
  wanted <- sd_theme_presets[[theme]]

  before <- deps
  # Drop any preset that is not the one selected, so switching themes does not
  # leave a stale dependency behind.
  for (preset in sd_theme_presets) {
    if (is.null(wanted) || !identical(preset$package, wanted$package)) {
      deps[[preset$package]] <- NULL
    }
  }
  if (!is.null(wanted)) {
    deps[[wanted$package]] <- wanted$version
  }

  if (identical(before, deps)) {
    return(invisible(FALSE))
  }

  manifest$dependencies <- deps[order(names(deps), method = "radix")]
  sd_write_file(
    paste0(jsonlite::toJSON(manifest, auto_unbox = TRUE, pretty = TRUE), "\n"),
    path
  )

  if (!quiet) {
    cli::cli_inform("Updated {.file package.json} for theme {.val {theme}}.")
  }
  sd_refresh_lockfile(site_path)
  invisible(TRUE)
}

# A dependency change without a matching lockfile would break `npm ci`. A
# project that has never been installed has no lockfile to keep in sync -- the
# scaffold's `npm install` will produce one that already includes the change.
#' @noRd
sd_refresh_lockfile <- function(site_path) {
  if (!fs::file_exists(fs::path(site_path, "package-lock.json"))) {
    return(invisible(FALSE))
  }
  if (!nzchar(Sys.which("npm"))) {
    cli::cli_warn(c(
      "{.code npm} was not found, so {.file package-lock.json} was not refreshed.",
      "i" = "Run {.code npm install} in {.path {site_path}} before building the site."
    ))
    return(invisible(FALSE))
  }
  result <- tryCatch(
    sd_npm(c("install", "--package-lock-only"), wd = site_path, error_on_status = FALSE),
    error = function(e) NULL
  )
  invisible(!is.null(result) && identical(result$status, 0L))
}
