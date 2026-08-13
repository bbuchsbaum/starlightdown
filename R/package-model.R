# Package model -------------------------------------------------------------
#
# `sd_pkg()` is the single entry point every builder reads from. It wraps
# `pkgdown::as_pkgdown()` (the documented "write your own build_site()" API)
# and adds the pieces starlightdown needs on top: a resolved site URL, the
# Astro `base` path derived from it, and a `meta` list that is always
# populated -- packages without a `_pkgdown.yml` get a synthesised default
# model rather than a special case in every downstream builder.

#' Build the starlightdown package model
#'
#' @param path Package source directory.
#' @return An object of class `sd_pkg`.
#' @noRd
sd_pkg <- function(path = ".") {
  path <- as.character(fs::path_abs(path))
  if (!fs::file_exists(fs::path(path, "DESCRIPTION"))) {
    cli::cli_abort("No {.file DESCRIPTION} found in {.path {path}}.")
  }

  pd <- pkgdown::as_pkgdown(path)

  meta <- pd$meta
  if (!is.list(meta)) meta <- list()

  topics <- pd$topics
  vignettes <- pd$vignettes

  docs_url <- sd_site_url(meta, pd$desc)

  meta <- sd_complete_meta(meta, topics, vignettes)

  structure(
    list(
      package = pd$package,
      version = as.character(pd$version),
      desc = pd$desc,
      topics = topics,
      meta = meta,
      vignettes = vignettes,
      src_path = as.character(pd$src_path),
      # The contract splits the docs URL: `site_url` is the origin, `base` the
      # path prefix. Keeping the path in both would double-count the base.
      site_url = sd_site_origin(docs_url),
      base = sd_base_path(docs_url)
    ),
    class = "sd_pkg"
  )
}

#' @noRd
print.sd_pkg <- function(x, ...) {
  cli::cli_text("{.cls sd_pkg} {.pkg {x$package}} {x$version}")
  cli::cli_bullets(c(
    "*" = "source: {.path {x$src_path}}",
    "*" = "site url: {if (is.na(x$site_url)) '<none>' else x$site_url}",
    "*" = "base: {x$base}",
    "*" = "{nrow(x$topics)} topic{?s}, {nrow(x$vignettes)} vignette{?s}"
  ))
  invisible(x)
}

# Site URL ------------------------------------------------------------------

# Hosts that serve source repositories or package registries rather than
# documentation. A DESCRIPTION URL pointing at one of these says where the code
# lives, not where the site is, and treating it as the site would produce a
# nonsense base such as `/user/repo`. pkgdown makes the same distinction by
# refusing to infer a site URL from DESCRIPTION at all.
sd_forge_hosts <- c(
  "github.com", "www.github.com",
  "gitlab.com", "www.gitlab.com",
  "bitbucket.org",
  "codeberg.org",
  "git.sr.ht",
  "sourceforge.net",
  "r-forge.r-project.org",
  "cran.r-project.org", "cran.rstudio.com", "cloud.r-project.org"
)

#' Split a URL into scheme, host and path
#' @noRd
sd_parse_url <- function(url) {
  m <- regmatches(
    url,
    regexec("^([A-Za-z][A-Za-z0-9+.-]*)://([^/?#]+)([^?#]*)", url)
  )[[1L]]
  if (length(m) < 4L) {
    return(NULL)
  }
  list(scheme = m[[2L]], host = m[[3L]], path = sub("/+$", "", m[[4L]]))
}

# Could this URL plausibly be the package's documentation site?
#' @noRd
sd_is_docs_url <- function(url) {
  parts <- sd_parse_url(url)
  if (is.null(parts)) {
    return(FALSE)
  }
  !tolower(parts$host) %in% sd_forge_hosts
}

# `_pkgdown.yml`'s `url:` wins outright -- it is a declaration, not a guess.
# Falling back to DESCRIPTION only works for URLs that could actually be a docs
# site; a repository or CRAN link is not one. Returns NA when nothing qualifies.
#' @noRd
sd_site_url <- function(meta, desc) {
  url <- meta$url
  if (sd_is_string(url)) {
    return(sub("/+$", "", url))
  }

  urls <- tryCatch(desc$get_urls(), error = function(e) character())
  urls <- urls[!is.na(urls) & nzchar(urls)]
  if (!length(urls)) {
    return(NA_character_)
  }

  bug <- tryCatch(
    desc$get_field("BugReports", default = NA_character_),
    error = function(e) NA_character_
  )
  if (!is.na(bug)) {
    urls <- setdiff(urls, c(bug, sub("/+$", "", bug)))
  }
  urls <- urls[grepl("^https?://", urls)]
  urls <- urls[vapply(urls, sd_is_docs_url, logical(1))]
  if (!length(urls)) {
    return(NA_character_)
  }
  sub("/+$", "", urls[[1L]])
}

# The origin -- scheme and host, no path. This is what `site.json`'s `site.url`
# carries; Astro composes it with `base`, so a path here would be counted twice.
#' @noRd
sd_site_origin <- function(url) {
  if (length(url) != 1L || is.na(url) || !nzchar(url)) {
    return(NA_character_)
  }
  parts <- sd_parse_url(url)
  if (is.null(parts)) {
    return(NA_character_)
  }
  paste0(parts$scheme, "://", parts$host)
}

# Astro's `base` is the path component of the site URL: a project page served
# from `https://user.github.io/pkg` needs `/pkg`, a user/organisation page or a
# custom domain served from the root needs `/`.
#' @noRd
sd_base_path <- function(site_url) {
  if (length(site_url) != 1L || is.na(site_url) || !nzchar(site_url)) {
    return("/")
  }
  parts <- sd_parse_url(site_url)
  path <- if (is.null(parts)) "" else parts$path
  if (!nzchar(path)) "/" else path
}

# Default model -------------------------------------------------------------

# Fill in the parts of the pkgdown model that a package without a
# `_pkgdown.yml` (or with a partial one) leaves empty.
#' @noRd
sd_complete_meta <- function(meta, topics, vignettes) {
  if (!length(meta$reference)) {
    meta$reference <- sd_default_reference(topics)
  }
  if (!length(meta$articles)) {
    meta$articles <- sd_default_articles(vignettes)
  }
  meta
}

#' @noRd
sd_default_reference <- function(topics) {
  if (!nrow(topics)) {
    return(list())
  }
  keep <- !as.logical(topics$internal)
  names <- sort(unname(topics$name[keep]), method = "radix")
  if (!length(names)) {
    return(list())
  }
  list(list(
    title = "All functions",
    contents = as.list(names)
  ))
}

#' @noRd
sd_default_articles <- function(vignettes) {
  if (!nrow(vignettes)) {
    return(list())
  }
  list(list(
    title = "Articles",
    contents = as.list(unname(vignettes$name))
  ))
}
