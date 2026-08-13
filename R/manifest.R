# Manifest -------------------------------------------------------------------
#
# `site.json` is the single structured hand-off to the Astro side: everything
# the frontend needs that is not prose. It is written deterministically -- keys
# in a fixed order, no timestamps -- so two builds of unchanged sources produce
# an identical file.

sd_schema_version <- 1L

#' Assemble the site manifest
#'
#' @param pkg An `sd_pkg()` object.
#' @param routes Route records from every builder.
#' @param news The record from `sd_build_news()`, or `NULL`.
#' @param citation The list from `sd_build_citation()`, or `NULL`.
#' @return A list, ready for `sd_write_manifest()`.
#' @noRd
sd_manifest <- function(pkg,
                        routes,
                        news = NULL,
                        citation = NULL,
                        theme = "default",
                        quickstart = NULL) {
  urls <- sd_package_urls(pkg)

  list(
    schemaVersion = sd_schema_version,
    generator = list(
      name = "starlightdown",
      version = as.character(utils::packageVersion("starlightdown"))
    ),
    # Origin only; `base` carries the path. Astro composes them, so a path in
    # `url` would be counted twice. The key is *omitted* rather than null when
    # there is no URL: Astro's `site` must be a string or absent, and a JSON
    # null arrives as an object and aborts the build.
    site = sd_compact(list(
      url = if (is.na(pkg$site_url)) NULL else pkg$site_url,
      base = pkg$base,
      theme = theme
    )),
    package = list(
      name = pkg$package,
      title = sd_desc_field(pkg$desc, "Title", pkg$package),
      description = sd_desc_field(pkg$desc, "Description", NULL),
      version = pkg$version,
      license = sd_desc_field(pkg$desc, "License", NULL),
      maintainer = sd_maintainer(pkg$desc),
      urls = urls
    ),
    install = sd_install_snippets(pkg, urls),
    citation = citation,
    # Each of install/citation/quickstart is optional and degrades to nothing
    # rather than to an empty box, so NULL is the right absent value.
    quickstart = if (sd_is_string(quickstart)) quickstart else NULL,
    sidebar = sd_sidebar(pkg, routes),
    topics = sd_manifest_topics(routes),
    redirects = sd_redirect_map(pkg, routes),
    news = sd_manifest_news(news),
    routes = sd_manifest_routes(routes)
  )
}

#' Write the manifest deterministically
#' @noRd
sd_write_manifest <- function(manifest, path) {
  json <- jsonlite::toJSON(
    manifest,
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null",
    na = "null"
  )
  sd_write_file(paste0(json, "\n"), path)
}

# Package metadata -----------------------------------------------------------

#' @noRd
sd_maintainer <- function(desc) {
  raw <- tryCatch(desc$get_maintainer(), error = function(e) NA_character_)
  if (!sd_is_string(raw)) {
    return(NULL)
  }
  email <- regmatches(raw, regexec("<([^>]+)>", raw))[[1L]]
  sd_compact(list(
    name = trimws(sub("<[^>]*>", "", raw)),
    email = if (length(email) >= 2L) email[[2L]] else NULL
  ))
}

#' @noRd
sd_package_urls <- function(pkg) {
  urls <- tryCatch(pkg$desc$get_urls(), error = function(e) character())
  urls <- urls[!is.na(urls) & nzchar(urls)]
  bugs <- tryCatch(
    pkg$desc$get_field("BugReports", default = NA_character_),
    error = function(e) NA_character_
  )

  homepage <- NULL
  if (!is.na(pkg$site_url)) {
    homepage <- paste0(pkg$site_url, if (identical(pkg$base, "/")) "/" else paste0(pkg$base, "/"))
  }

  sd_compact(list(
    homepage = homepage,
    repo = sd_first_match(urls, "^https?://(www\\.)?(github|gitlab|codeberg|bitbucket)\\."),
    bugs = if (is.na(bugs)) NULL else bugs,
    cran = sd_first_match(urls, "^https?://cran\\..*package="),
    runiverse = sd_first_match(urls, "r-universe\\.dev")
  ))
}

#' @noRd
sd_first_match <- function(x, pattern) {
  hit <- grep(pattern, x, value = TRUE, ignore.case = TRUE)
  if (length(hit)) sub("/+$", "", hit[[1L]]) else NULL
}

# Installation snippets. `cran` is only offered when DESCRIPTION actually
# points at CRAN: telling someone to `install.packages()` a package that was
# never published there is worse than saying nothing.
#' @noRd
sd_install_snippets <- function(pkg, urls) {
  runiverse <- NULL
  if (!is.null(urls$runiverse)) {
    owner <- regmatches(
      urls$runiverse,
      regexec("^(https?://[^/]*r-universe\\.dev)", urls$runiverse)
    )[[1L]]
    if (length(owner) >= 2L) {
      runiverse <- paste0(
        "install.packages(\"", pkg$package, "\", repos = c(\"",
        owner[[2L]], "\", getOption(\"repos\")))"
      )
    }
  }

  github <- NULL
  if (!is.null(urls$repo) && grepl("github\\.com", urls$repo)) {
    slug <- sub("^https?://(www\\.)?github\\.com/", "", urls$repo)
    slug <- sub("\\.git$", "", slug)
    if (nzchar(slug)) {
      github <- paste0("pak::pak(\"", slug, "\")")
    }
  }

  list(
    cran = if (is.null(urls$cran)) NULL else paste0("install.packages(\"", pkg$package, "\")"),
    runiverse = runiverse,
    github = github
  )
}

# Routes and topics ----------------------------------------------------------

#' @noRd
sd_manifest_routes <- function(routes) {
  ordered <- routes[order(vapply(routes, function(r) r$route, character(1)), method = "radix")]
  unname(lapply(ordered, function(r) {
    sd_compact(list(
      id = sub("\\.md$", "", r$file),
      route = r$route,
      kind = r$kind,
      title = r$title
    ))
  }))
}

#' @noRd
sd_manifest_topics <- function(routes) {
  topics <- sd_routes_of_kind(routes, "reference")
  if (!length(topics)) {
    return(structure(list(), names = character()))
  }
  names(topics) <- vapply(topics, function(r) r$name, character(1))
  topics <- topics[order(names(topics), method = "radix")]

  lapply(topics, function(r) {
    sd_compact(list(
      name = r$name,
      route = r$route,
      title = r$name,
      summary = r$title,
      lifecycle = r$lifecycle,
      aliases = as.list(r$aliases)
    ))
  })
}

#' @noRd
sd_manifest_news <- function(news) {
  if (is.null(news)) {
    return(NULL)
  }
  sd_compact(list(
    latest = news$latest,
    route = news$route,
    versions = if (length(news$versions)) news$versions else NULL
  ))
}

# Redirects ------------------------------------------------------------------

# pkgdown's URLs all ended in .html; a site that used to be a pkgdown site has
# those addresses in the wild. Every generated route gets a stub at its old
# address, plus whatever `redirects:` in _pkgdown.yml asks for.
#' @noRd
sd_redirect_map <- function(pkg, routes) {
  map <- list()

  add <- function(from, to) {
    if (sd_is_string(from) && sd_is_string(to) && is.null(map[[from]])) {
      map[[from]] <<- to
    }
  }

  for (r in routes) {
    old <- switch(r$kind,
      home = "/index.html",
      news = "/news/index.html",
      `reference-index` = "/reference/index.html",
      reference = paste0("/reference/", r$slug, ".html"),
      article = paste0("/articles/", r$slug, ".html"),
      NULL
    )
    add(old, r$route)
  }

  for (entry in pkg$meta$redirects) {
    pair <- as.character(unlist(entry, use.names = FALSE))
    if (length(pair) == 2L) {
      add(pair[[1L]], pair[[2L]])
    }
  }

  map[order(names(map), method = "radix")]
}
