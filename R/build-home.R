# Home page ------------------------------------------------------------------
#
# README.md becomes the site's index. The title and description come from
# DESCRIPTION rather than from the README, so the page header matches the rest
# of the site; the README's own `# pkgname` heading is dropped because
# Starlight renders the frontmatter title as the page H1 and a second one would
# break the contract's no-duplicate-H1 rule.

#' Render README.md into the staging directory as `index.md`
#'
#' @return Invisibly, a route record, or `NULL` when there is no README.
#' @noRd
sd_build_home <- function(pkg, stage_dir) {
  readme <- sd_find_readme(pkg$src_path)

  title <- sd_desc_field(pkg$desc, "Title", pkg$package)
  description <- sd_desc_field(pkg$desc, "Description", NULL)

  body <- ""
  badges <- list()
  assets <- character()

  if (!is.null(readme)) {
    body <- sd_read_utf8(readme)

    # Badges usually sit *above* the title, so they have to come off first or
    # the H1 is no longer the leading block and survives into the page.
    extracted <- sd_extract_badges(body)
    badges <- extracted$badges
    body <- extracted$body

    body <- sd_strip_leading_h1(body)
    # Anything the author still wrote as `#` moves down: the frontmatter title
    # is the page H1.
    body <- paste0(
      sd_demote_headings(strsplit(body, "\n", fixed = TRUE)[[1L]]),
      collapse = "\n"
    )

    # READMEs commonly place the package logo with a raw <img>; Astro emits
    # only Markdown images, so normalise before anything is relocated.
    body <- sd_html_images_to_markdown(body)
    # READMEs on GitHub commonly use alert blockquotes.
    body <- sd_alerts_to_asides(body)

    moved <- sd_relocate_local_images(body, pkg, stage_dir)
    body <- moved$body
    assets <- moved$assets

    body <- sd_resolve_readme_links(body, pkg)
    body <- sd_apply_base_to_links(body, pkg$base)
  }

  frontmatter <- sd_compact(list(
    title = title,
    description = description,
    sd = sd_compact(list(
      kind = "home",
      badges = if (length(badges)) badges else NULL
    ))
  ))

  path <- fs::path(stage_dir, "index.md")
  sd_write_file(paste0(sd_frontmatter(frontmatter), "\n", trimws(body), "\n"), path)

  invisible(list(
    name = "index",
    slug = "index",
    kind = "home",
    title = title,
    route = "/",
    file = "index.md",
    source = if (is.null(readme)) NULL else fs::path_file(readme),
    assets = assets
  ))
}

# Quickstart -----------------------------------------------------------------

# The first thing a reader should type, rendered under the install tabs and
# omitted entirely when NULL. An explicit `starlightdown: quickstart:` in
# _pkgdown.yml wins; otherwise take the README's first R chunk after the
# install section, which is where that snippet conventionally lives.
#' @noRd
sd_quickstart <- function(pkg) {
  declared <- pkg$meta$starlightdown$quickstart
  if (sd_is_string(declared)) {
    return(trimws(declared))
  }

  readme <- sd_find_readme(pkg$src_path)
  if (is.null(readme)) {
    return(NULL)
  }
  sd_readme_quickstart(readLines(readme, warn = FALSE, encoding = "UTF-8"))
}

#' @noRd
sd_readme_quickstart <- function(lines) {
  chunks <- sd_r_chunks(lines)
  if (!length(chunks)) {
    return(NULL)
  }

  install_heading <- grep("^#{1,6}\\s+install", lines, ignore.case = TRUE)
  after <- if (length(install_heading)) {
    Filter(function(ch) ch$start > install_heading[[1L]], chunks)
  } else {
    list()
  }

  # An install heading with a chunk under it: the quickstart is the *next* one,
  # since the first is the install command itself.
  candidates <- if (length(after) >= 2L) after[-1L] else if (!length(after)) chunks else list()
  if (!length(candidates)) {
    return(NULL)
  }

  code <- trimws(paste0(candidates[[1L]]$code, collapse = "\n"))
  if (!nzchar(code) || grepl("^(install\\.packages|remotes::|pak::|devtools::)", code)) {
    return(NULL)
  }
  code
}

# Fenced R chunks, as start line plus body.
#' @noRd
sd_r_chunks <- function(lines) {
  chunks <- list()
  fence <- NA_character_
  start <- NA_integer_
  body <- character()

  for (i in seq_along(lines)) {
    line <- lines[[i]]
    if (is.na(fence)) {
      opener <- regmatches(line, regexec("^[ \t]*(`{3,}|~{3,})[ \t]*\\{?([A-Za-z]*)", line))[[1L]]
      if (length(opener) >= 3L && tolower(opener[[3L]]) %in% c("r", "rr")) {
        fence <- opener[[2L]]
        start <- i
        body <- character()
      }
      next
    }
    if (grepl(paste0("^[ \t]*", fence, "[ \t]*$"), line)) {
      chunks[[length(chunks) + 1L]] <- list(start = start, code = body)
      fence <- NA_character_
      next
    }
    body <- c(body, line)
  }
  chunks
}

#' @noRd
sd_find_readme <- function(src_path) {
  candidates <- fs::path(src_path, c("README.md", "README.Rmd", "readme.md"))
  found <- candidates[fs::file_exists(candidates)]
  # A README.Rmd is a source document; without a rendered README.md there is
  # nothing to show, and executing it is Quarto's job, not ours.
  found <- found[grepl("\\.md$", found, ignore.case = TRUE)]
  if (length(found)) found[[1L]] else NULL
}

#' @noRd
sd_desc_field <- function(desc, field, default = NULL) {
  value <- tryCatch(desc$get_field(field, default = NA_character_), error = function(e) NA_character_)
  if (!sd_is_string(value)) {
    return(default)
  }
  trimws(gsub("[[:space:]]+", " ", value))
}

# Badges ---------------------------------------------------------------------

# A README badge is a linked image, usually in a run of them just under the
# title. They become structured `sd.badges` data so the frontend can lay them
# out, rather than a wall of images in the prose.
#' @noRd
sd_extract_badges <- function(body) {
  body <- sd_normalise_setext(body)
  lines <- strsplit(gsub("\r\n", "\n", body), "\n", fixed = TRUE)[[1L]]
  badge_line <- "^\\s*(\\[!\\[[^\\]]*\\]\\([^)]*\\)\\]\\([^)]*\\)\\s*)+$"

  badges <- list()
  keep <- rep(TRUE, length(lines))
  seen_title <- FALSE
  # Only a leading run counts: a badge deep in the prose is being used as
  # illustration, not as page chrome. READMEs put the run either side of the
  # title, so one heading is allowed to interrupt it.
  for (i in seq_along(lines)) {
    if (!nzchar(trimws(lines[[i]]))) {
      next
    }
    if (!grepl(badge_line, lines[[i]], perl = TRUE)) {
      if (!seen_title && grepl("^#\\s+\\S", lines[[i]])) {
        seen_title <- TRUE
        next
      }
      break
    }
    keep[[i]] <- FALSE
    pieces <- regmatches(
      lines[[i]],
      gregexpr("\\[!\\[[^\\]]*\\]\\([^)]*\\)\\]\\([^)]*\\)", lines[[i]], perl = TRUE)
    )[[1L]]
    for (piece in pieces) {
      parts <- regmatches(
        piece,
        regexec("\\[!\\[([^\\]]*)\\]\\(([^)]*)\\)\\]\\(([^)]*)\\)", piece, perl = TRUE)
      )[[1L]]
      if (length(parts) < 4L) {
        next
      }
      badges[[length(badges) + 1L]] <- sd_compact(list(
        text = if (nzchar(parts[[2L]])) parts[[2L]] else "badge",
        href = if (nzchar(parts[[4L]])) parts[[4L]] else NULL
      ))
    }
  }

  list(badges = badges, body = paste0(lines[keep], collapse = "\n"))
}

# Assets ---------------------------------------------------------------------

# A README points at files in the package -- `man/figures/`, but also `tools/`,
# `README_files/` or anywhere else -- none of which exist in the built site.
# Any relative target that resolves inside the package is copied next to
# index.md and the reference repointed at the copy.
#' @noRd
# A README is written for the repository, so its links point at files there:
# NEWS.md, a vignette source, CONTRIBUTING.md. On the site those paths mean
# nothing. The ones the build itself publishes become links to the page; the
# rest become links into the repository, where the file actually is. Leaving
# them relative would only fail validation, which helps nobody.
#' @noRd
sd_resolve_readme_links <- function(body, pkg) {
  blob <- sd_repo_blob_url(pkg)

  sd_md_rewrite_targets(body, which = "links", fn = function(target) {
    decoded <- sd_md_decode_target(target)
    if (!sd_md_is_relative(decoded) || !nzchar(decoded)) {
      return(target)
    }
    anchor <- regmatches(target, regexpr("[#?].*$", target))
    anchor <- if (length(anchor)) anchor else ""

    route <- sd_readme_route(decoded, pkg)
    if (!is.na(route)) {
      return(paste0(route, anchor))
    }
    if (!is.na(blob) && fs::file_exists(fs::path(pkg$src_path, decoded))) {
      return(paste0(blob, decoded, anchor))
    }
    target
  })
}

# Which page, if any, does a repository path end up as?
#' @noRd
sd_readme_route <- function(path, pkg) {
  path <- sub("^\\./", "", path)
  if (identical(tolower(path), "news.md")) {
    return("/news/")
  }
  vignette <- regmatches(path, regexec("^vignettes/(.+)\\.(Rmd|rmd|qmd|md)$", path))[[1L]]
  if (length(vignette)) {
    return(sd_article_route(vignette[[2L]]))
  }
  NA_character_
}

# `https://github.com/o/r` -> `https://github.com/o/r/blob/HEAD/`
#' @noRd
sd_repo_blob_url <- function(pkg) {
  urls <- sd_package_urls(pkg)
  repo <- urls$repo
  if (!sd_is_string(repo)) {
    return(NA_character_)
  }
  paste0(sub("/$", "", repo), "/blob/HEAD/")
}

sd_relocate_local_images <- function(body, pkg, stage_dir) {
  dest_dir <- fs::path(stage_dir, "figures")
  assets <- character()
  taken <- character()

  body <- sd_md_rewrite_targets(
    body,
    which = "images",
    fn = function(target) {
      decoded <- sd_md_decode_target(target)
      if (!sd_md_is_relative(decoded) || !nzchar(decoded)) {
        return(target)
      }
      from <- fs::path(pkg$src_path, decoded)
      if (!fs::file_exists(from)) {
        return(target)
      }

      # Two files with the same basename would otherwise collide.
      name <- fs::path_file(decoded)
      if (name %in% taken) {
        stem <- fs::path_ext_remove(name)
        ext <- fs::path_ext(name)
        name <- paste0(stem, "-", length(taken), if (nzchar(ext)) paste0(".", ext) else "")
      }
      taken <<- c(taken, name)

      fs::dir_create(dest_dir)
      fs::file_copy(from, fs::path(dest_dir, name), overwrite = TRUE)
      replacement <- paste0("figures/", name)
      assets <<- c(assets, replacement)
      replacement
    }
  )

  list(body = body, assets = unique(assets))
}
