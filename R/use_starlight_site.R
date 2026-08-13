#' Scaffold an Astro Starlight project for this package
#'
#' Creates `site_dir/` from the bundled template, vendors the Starlight plugin
#' into `site_dir/.starlightdown/`, and installs the Node dependencies if npm
#' is available. Everything outside `.starlightdown/` is yours to edit; that
#' directory is regenerated on every [build_site()].
#'
#' @param path Package root directory.
#' @param site_dir Subdirectory where the Starlight project will live.
#' @param overwrite Whether to overwrite an existing directory at `site_dir`.
#' @param npm_install Run `npm install` to create the lockfile?
#'
#' @return Invisibly, the path to `site_dir`.
#' @importFrom desc desc
#' @importFrom fs dir_exists dir_copy
#' @importFrom cli cli_inform
#' @export
use_starlight_site <- function(path = ".", site_dir = "starlight",
                               overwrite = FALSE, npm_install = TRUE) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  desc_path <- file.path(path, "DESCRIPTION")
  if (!file.exists(desc_path)) {
    stop("No DESCRIPTION found at ", desc_path, call. = FALSE)
  }

  d <- desc::desc(file = desc_path)
  # `get()` returns a *named* value; carrying the name into the replacement map
  # would rename its entries and silently skip every substitution.
  pkg_title <- unname(d$get("Title"))
  pkg_name <- unname(d$get("Package"))

  template <- system.file("starlight-template", package = "starlightdown")
  if (template == "") {
    stop("Could not find `inst/starlight-template` in the package.", call. = FALSE)
  }

  site_path <- file.path(path, site_dir)
  if (fs::dir_exists(site_path)) {
    if (!isTRUE(overwrite)) {
      stop(
        "Directory `", site_dir, "` already exists. ",
        "Set `overwrite = TRUE` to replace it.",
        call. = FALSE
      )
    }
    fs::dir_delete(site_path)
    if (fs::dir_exists(site_path)) {
      cli::cli_abort(
        "Could not remove existing {.path {site_dir}}. Please delete it manually and retry."
      )
    }
  }

  fs::dir_copy(template, site_path)
  sd_fill_placeholders(site_path, title = pkg_title, slug = pkg_name)

  # The plugin has to exist before npm resolves the `file:` dependency that
  # points at it.
  sd_sync_machine_dir(site_path)

  sd_add_buildignore(path, site_dir)

  cli::cli_inform("Starlight site scaffolded at {.path {site_dir}}.")

  if (isTRUE(npm_install)) {
    sd_scaffold_npm_install(site_path)
  }

  invisible(site_path)
}

#' @noRd
sd_fill_placeholders <- function(site_path, title, slug) {
  replacements <- c(PKG_TITLE = title, PKG_SLUG = slug)
  # index.md is the placeholder page a fresh scaffold serves until the first
  # build; leaving PKG_TITLE in it shows the literal token in `npm run dev`.
  # package-lock.json carries the placeholder name too. `npm ci` tolerates a
  # root-name mismatch, but keeping the two files consistent avoids a confusing
  # diff the first time anyone runs `npm install`.
  files <- c(
    "astro.config.mjs", "package.json", "package-lock.json",
    "src/content/docs/index.md"
  )
  for (file in files) {
    target <- file.path(site_path, file)
    if (!file.exists(target)) {
      next
    }
    text <- readLines(target, warn = FALSE, encoding = "UTF-8")
    for (key in names(replacements)) {
      text <- gsub(key, replacements[[key]], text, fixed = TRUE)
    }
    writeLines(text, target, useBytes = TRUE)
  }
  invisible(site_path)
}

#' @noRd
sd_add_buildignore <- function(path, site_dir) {
  buildignore <- file.path(path, ".Rbuildignore")
  patterns <- utils::glob2rx(site_dir)
  existing <- if (file.exists(buildignore)) {
    readLines(buildignore, warn = FALSE)
  } else {
    character()
  }
  missing <- setdiff(patterns, existing)
  if (length(missing)) {
    writeLines(c(existing, missing), buildignore)
  }
  invisible(buildignore)
}

# A missing npm is inconvenient, not fatal: the R side of the scaffold is done
# and the user can install dependencies whenever Node is available.
#' @noRd
sd_scaffold_npm_install <- function(site_path) {
  if (!nzchar(Sys.which("npm"))) {
    cli::cli_warn(c(
      "{.code npm} was not found, so Node dependencies were not installed.",
      "i" = "Install Node.js, then run {.code npm install} in {.path {site_path}}."
    ))
    return(invisible(FALSE))
  }

  cli::cli_inform("Installing Node dependencies with {.code npm install}.")
  result <- tryCatch(
    sd_npm("install", wd = site_path, error_on_status = FALSE),
    error = function(e) NULL
  )
  if (is.null(result) || !identical(result$status, 0L)) {
    cli::cli_warn(c(
      "{.code npm install} did not complete.",
      "i" = "Run it yourself in {.path {site_path}} before building the site."
    ))
    return(invisible(FALSE))
  }
  invisible(TRUE)
}
