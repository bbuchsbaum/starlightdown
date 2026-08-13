# Redirects ------------------------------------------------------------------
#
# Old pkgdown URLs are kept alive with static meta-refresh pages written into
# `public/`. Astro's own `redirects` config cannot do this job: with directory
# output it emits a *directory* named `add_one.html`, it does not apply the
# site base to the target or the canonical URL, and a key like
# `/news/index.html` collides with a real page and fails the build outright
# (CONTRACT.md §6).

#' Write redirect stubs into a staging directory
#'
#' @param redirects Named list, old path -> base-less route.
#' @param routes Route records, used to refuse collisions.
#' @param public_dir Directory to write into (becomes `starlight/public/`).
#' @return Invisibly, `list(written, skipped)`.
#' @noRd
sd_write_redirects <- function(redirects, routes, public_dir, pkg) {
  fs::dir_create(public_dir)

  occupied <- vapply(routes, sd_route_output_path, character(1))
  written <- character()
  files <- character()
  skipped <- character()

  for (from in names(redirects)) {
    target <- redirects[[from]]
    file <- sd_redirect_output_path(from)

    # A redirect source is a URL path, and it is going to become a filename.
    # `_pkgdown.yml` can put anything in it, so anything that escapes public/
    # is refused outright rather than written -- and later deleted -- outside.
    if (is.na(file)) {
      cli::cli_warn(
        "Ignoring redirect from {.val {from}}: it does not name a path inside the site."
      )
      skipped <- c(skipped, from)
      next
    }

    # A stub here would overwrite the page it is supposed to point at.
    if (file %in% occupied) {
      skipped <- c(skipped, from)
      next
    }

    path <- fs::path(public_dir, file)
    fs::dir_create(fs::path_dir(path))
    sd_write_file(sd_redirect_html(target, pkg), path)
    written <- c(written, from)
    files <- c(files, file)
  }

  sd_write_stub_inventory(public_dir, files)

  invisible(list(written = written, files = files, skipped = skipped))
}

# The inventory of stubs this build wrote, kept *next to the stubs*. It cannot
# live in site.json: `.starlightdown/` is generated and gitignored while
# `public/` is committed, so in CI -- which starts from a fresh checkout -- the
# manifest would be absent and stale stubs would survive forever.
sd_stub_inventory_file <- ".starlightdown-redirects.json"

#' @noRd
sd_write_stub_inventory <- function(public_dir, files) {
  path <- fs::path(public_dir, sd_stub_inventory_file)
  sd_write_file(
    paste0(jsonlite::toJSON(
      list(
        generator = "starlightdown",
        files = sort(files, method = "radix")
      ),
      auto_unbox = TRUE, pretty = TRUE
    ), "\n"),
    path
  )
  invisible(path)
}

#' @noRd
sd_read_stub_inventory <- function(public_dir) {
  path <- fs::path(public_dir, sd_stub_inventory_file)
  if (!fs::file_exists(path)) {
    return(character())
  }
  inventory <- tryCatch(jsonlite::read_json(path), error = function(e) NULL)
  files <- as.character(unlist(inventory$files, use.names = FALSE))
  files[!is.na(files) & nzchar(files)]
}

# Where a route's own HTML lands under directory output: `/reference/add_one/`
# is written as `reference/add_one/index.html`.
#' @noRd
sd_route_output_path <- function(route) {
  path <- sub("^/", "", route$route)
  paste0(path, "index.html")
}

# The file a redirect source maps to, relative to public/. Returns NA for
# anything that is not a plain path inside the site: an absolute filesystem
# path, a UNC or drive-letter path, a backslash form, or a `..` that climbs
# out. These are written to disk and later deleted, so a traversal here would
# reach the user's own files.
#' @noRd
sd_redirect_output_path <- function(from) {
  if (!sd_is_string(from) || grepl("\\\\", from) || grepl("^[A-Za-z]:", from)) {
    return(NA_character_)
  }
  if (grepl("^//", from) || grepl("^[A-Za-z][A-Za-z0-9+.-]*:", from)) {
    return(NA_character_)
  }

  path <- sub("^/+", "", sub("[?#].*$", "", from))
  if (!nzchar(path)) {
    return(NA_character_)
  }

  parts <- strsplit(path, "/", fixed = TRUE)[[1L]]
  parts <- parts[nzchar(parts) & parts != "."]
  resolved <- character()
  for (part in parts) {
    if (identical(part, "..")) {
      if (!length(resolved)) {
        return(NA_character_)
      }
      resolved <- resolved[-length(resolved)]
    } else {
      resolved <- c(resolved, part)
    }
  }
  if (!length(resolved)) {
    return(NA_character_)
  }
  paste0(resolved, collapse = "/")
}

#' The meta-refresh document itself
#' @noRd
sd_redirect_html <- function(route, pkg) {
  target <- sd_with_base(route, pkg$base)
  canonical <- if (is.na(pkg$site_url)) NULL else paste0(pkg$site_url, target)

  lines <- c(
    "<!doctype html>",
    "<html lang=\"en\">",
    "<head>",
    "<meta charset=\"utf-8\">",
    paste0("<title>Redirecting to ", sd_html_escape(target), "</title>"),
    paste0("<meta http-equiv=\"refresh\" content=\"0; url=", sd_html_escape(target), "\">"),
    "<meta name=\"robots\" content=\"noindex\">",
    if (!is.null(canonical)) {
      paste0("<link rel=\"canonical\" href=\"", sd_html_escape(canonical), "\">")
    },
    "</head>",
    "<body>",
    paste0(
      "<p>This page moved to <a href=\"", sd_html_escape(target), "\">",
      sd_html_escape(target), "</a>.</p>"
    ),
    "</body>",
    "</html>"
  )
  paste0(paste0(lines[!vapply(lines, is.null, logical(1))], collapse = "\n"), "\n")
}

#' @noRd
sd_with_base <- function(route, base) {
  # An absolute URL is already a destination; prefixing it produces nonsense
  # like `/pkghttps://elsewhere.example/`.
  if (grepl("^([A-Za-z][A-Za-z0-9+.-]*:|//)", route)) {
    return(route)
  }
  if (!sd_is_string(base) || identical(base, "/")) {
    return(route)
  }
  paste0(sub("/+$", "", base), route)
}

#' @noRd
sd_html_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  gsub("\"", "&quot;", x, fixed = TRUE)
}
