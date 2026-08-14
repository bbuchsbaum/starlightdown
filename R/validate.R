# Validation -----------------------------------------------------------------
#
# Everything here runs against the staging tree, before anything is committed.
# A build that fails these gates leaves the live site exactly as it was, which
# is the whole reason the content tree is staged in the first place.

#' Validate a staged build
#'
#' @param stage `list(content, public)` from `sd_new_stage()`.
#' @param routes Route records.
#' @param manifest The assembled manifest.
#' @return Invisibly `TRUE`; aborts with every failure listed otherwise.
#' @noRd
sd_validate_stage <- function(stage, routes, manifest, pkg, written_redirects = character()) {
  problems <- c(
    sd_check_frontmatter(stage$content),
    sd_check_no_reference_h1(stage$content),
    sd_check_index_groups(stage$content),
    sd_check_relative_targets(stage$content),
    sd_check_emittable_images(stage$content),
    sd_check_rendered_alerts(stage$content),
    sd_check_prose_links(stage$content, routes, manifest, pkg),
    sd_check_route_bijection(stage$content, routes),
    sd_check_redirect_collisions(routes, written_redirects)
  )

  problems <- sd_name_sources(problems, routes)
  if (length(problems)) {
    names(problems) <- rep("x", length(problems))
    cli::cli_abort(c(
      "The generated site failed {length(problems)} validation check{?s}; nothing was committed.",
      problems
    ))
  }
  invisible(TRUE)
}

# A validation failure is about something the *author* wrote, so the message
# has to name the file they would open, not the file we generated.
#' @noRd
sd_name_sources <- function(problems, routes) {
  if (!length(problems) || !length(routes)) {
    return(problems)
  }
  sources <- vapply(routes, function(r) r$source %||% NA_character_, character(1))
  files <- vapply(routes, function(r) r$file, character(1))
  known <- sources[!is.na(sources)]
  names(known) <- files[!is.na(sources)]

  vapply(problems, function(problem) {
    file <- sub(":.*$", "", problem)
    i <- match(file, names(known))
    if (is.na(i) || identical(unname(known[[i]]), file)) {
      return(problem)
    }
    sub(
      paste0("^", sd_fixed_prefix(file), ":"),
      paste0(file, " (from ", unname(known[[i]]), "):"),
      problem
    )
  }, character(1), USE.NAMES = FALSE)
}

#' @noRd
sd_fixed_prefix <- function(x) {
  gsub("([.\\\\|()\\[\\]{}^$*+?])", "\\\\\\1", x, perl = TRUE)
}

#' @noRd
sd_stage_pages <- function(content_dir) {
  fs::dir_ls(content_dir, recurse = TRUE, glob = "*.md", type = "file")
}

#' @noRd
sd_page_parts <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  marks <- which(lines == "---")
  if (length(marks) < 2L || marks[[1L]] != 1L) {
    return(NULL)
  }
  block <- paste0(lines[seq(marks[[1L]] + 1L, marks[[2L]] - 1L)], collapse = "\n")
  body <- if (marks[[2L]] >= length(lines)) {
    character()
  } else {
    lines[seq(marks[[2L]] + 1L, length(lines))]
  }
  frontmatter <- tryCatch(yaml::yaml.load(block), error = function(e) NULL)
  list(frontmatter = frontmatter, body = body)
}

# Gates ----------------------------------------------------------------------

#' @noRd
sd_check_frontmatter <- function(content_dir) {
  problems <- character()
  for (path in sd_stage_pages(content_dir)) {
    rel <- as.character(fs::path_rel(path, content_dir))
    parts <- sd_page_parts(path)
    if (is.null(parts)) {
      problems <- c(problems, paste0(rel, ": no frontmatter block."))
      next
    }
    if (is.null(parts$frontmatter)) {
      problems <- c(problems, paste0(rel, ": frontmatter is not valid YAML."))
      next
    }
    if (!sd_is_string(parts$frontmatter$title)) {
      problems <- c(problems, paste0(rel, ": frontmatter has no {.field title}."))
    }
    lifecycle <- parts$frontmatter$sd$lifecycle
    if (!is.null(lifecycle) && !lifecycle %in% sd_schema_lifecycles) {
      problems <- c(problems, paste0(
        rel, ": lifecycle '", lifecycle, "' is not one of ",
        paste0(sd_schema_lifecycles, collapse = "/"), "."
      ))
    }
  }
  problems
}

# The four the frontend schema accepts. Anything else fails Astro's content
# collection validation and takes the whole site build with it.
sd_schema_lifecycles <- c("experimental", "stable", "deprecated", "superseded")

# Starlight renders the frontmatter title as the page H1, so a second one in
# the body is both wrong and invisible in review (CONTRACT.md §4).
#' @noRd
sd_check_no_reference_h1 <- function(content_dir) {
  problems <- character()
  for (path in sd_stage_pages(content_dir)) {
    rel <- as.character(fs::path_rel(path, content_dir))
    parts <- sd_page_parts(path)
    if (is.null(parts)) {
      next
    }
    # The view blanks fenced blocks, code spans and HTML comments, so a `#`
    # inside any of them is not a heading.
    view <- sd_md_view(paste0(parts$body, collapse = "\n"))
    heading <- grep("^#[^#]", strsplit(view, "\n", fixed = TRUE)[[1L]], value = TRUE)
    if (length(heading)) {
      problems <- c(problems, paste0(rel, ": body contains an H1 ('", trimws(heading[[1L]]), "')."))
    }
  }
  problems
}

#' @noRd
sd_check_index_groups <- function(content_dir) {
  path <- fs::path(content_dir, "reference", "index.md")
  if (!fs::file_exists(path)) {
    return(character())
  }
  parts <- sd_page_parts(path)
  groups <- parts$frontmatter$sd$groups
  problems <- character()
  for (i in seq_along(groups)) {
    if (!sd_is_string(groups[[i]]$title)) {
      problems <- c(problems, paste0("reference/index.md: group ", i, " has no title."))
    }
    for (topic in groups[[i]]$topics) {
      if (!is.null(topic$slug) && !grepl("^/", topic$slug)) {
        problems <- c(problems, paste0(
          "reference/index.md: topic '", topic$name, "' has slug '", topic$slug,
          "', which is not a route."
        ))
      }
    }
  }
  problems
}

# Every relative image or link target must exist on disk next to the page that
# names it, or Astro's asset pipeline fails at build time.
#' @noRd
sd_check_relative_targets <- function(content_dir) {
  problems <- character()
  for (path in sd_stage_pages(content_dir)) {
    rel <- as.character(fs::path_rel(path, content_dir))
    body <- sd_read_utf8(path)
    for (target in sd_relative_targets(body)) {
      resolved <- fs::path(fs::path_dir(path), target)
      if (!fs::file_exists(resolved) && !fs::dir_exists(resolved)) {
        problems <- c(problems, paste0(rel, ": relative target '", target, "' does not exist."))
      }
    }
  }
  problems
}

# Existing on disk is not the same as reaching the built site. Astro routes
# only Markdown images through its asset pipeline: a raw <img> naming a local
# file is copied nowhere and 404s on a page that otherwise looks correct. The
# builders convert those to Markdown, so anything still here is a hole in that
# conversion, and a silent one -- hence a build failure rather than a warning.
#' @noRd
sd_check_emittable_images <- function(content_dir) {
  problems <- character()
  for (path in sd_stage_pages(content_dir)) {
    rel <- as.character(fs::path_rel(path, content_dir))
    for (src in sd_unemittable_images(sd_read_utf8(path))) {
      problems <- c(problems, paste0(
        rel, ": raw <img src='", src, "'> would not be emitted by Astro; ",
        "it must be a Markdown image."
      ))
    }
  }
  problems
}

# An alert marker only renders if something downstream understands it. The
# builders convert them all to asides, so one surviving here would reach the
# reader as literal text -- which is how `[!NONE]` shipped.
#' @noRd
sd_check_rendered_alerts <- function(content_dir) {
  problems <- character()
  for (path in sd_stage_pages(content_dir)) {
    rel <- as.character(fs::path_rel(path, content_dir))
    for (type in sd_unrenderable_alerts(sd_read_utf8(path))) {
      problems <- c(problems, paste0(
        rel, ": alert marker '[!", type, "]' would render as literal text; ",
        "it must be a Starlight aside."
      ))
    }
  }
  problems
}

# A base-prefixed prose link must land on a route we generated or a redirect we
# wrote; anything else is a dead link shipped to readers.
#' @noRd
sd_check_prose_links <- function(content_dir, routes, manifest, pkg) {
  known <- c(
    vapply(routes, function(r) sd_with_base(r$route, pkg$base), character(1)),
    vapply(names(manifest$redirects), function(x) sd_with_base(x, pkg$base), character(1))
  )
  known <- unique(c(known, sub("/$", "", known)))

  problems <- character()
  for (path in sd_stage_pages(content_dir)) {
    rel <- as.character(fs::path_rel(path, content_dir))
    for (href in sd_root_link_targets(sd_read_utf8(path))) {
      if (!href %in% known) {
        problems <- c(problems, paste0(rel, ": link '", href, "' matches no route."))
      }
    }
  }
  problems
}

# Routes and files must be the same set: a route with no file is a 404, a file
# with no route is an orphan the sidebar will never reach.
#' @noRd
sd_check_route_bijection <- function(content_dir, routes) {
  on_disk <- sort(as.character(fs::path_rel(sd_stage_pages(content_dir), content_dir)))
  declared <- sort(vapply(routes, function(r) r$file, character(1)))

  problems <- character()
  missing <- setdiff(declared, on_disk)
  if (length(missing)) {
    problems <- c(problems, paste0(
      "routes with no file: ", paste0(missing, collapse = ", "), "."
    ))
  }
  orphans <- setdiff(on_disk, declared)
  if (length(orphans)) {
    problems <- c(problems, paste0(
      "files with no route: ", paste0(orphans, collapse = ", "), "."
    ))
  }
  problems
}

# A redirect stub written at a real page's output path would overwrite it.
# `sd_write_redirects()` skips those; this proves it did.
#' @noRd
sd_check_redirect_collisions <- function(routes, written_redirects) {
  occupied <- vapply(routes, sd_route_output_path, character(1))
  problems <- character()
  for (from in written_redirects) {
    if (sd_redirect_output_path(from) %in% occupied) {
      problems <- c(problems, paste0(
        "redirect '", from, "' would overwrite a generated page."
      ))
    }
  }
  problems
}
