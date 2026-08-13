# News -----------------------------------------------------------------------
#
# NEWS.md conventionally opens each release with a top-level `# pkg 1.2.3`
# heading. Starlight already renders the frontmatter title as the page H1, so
# every heading is demoted one level: the releases become H2s and their
# subsections H3s, leaving exactly one H1 on the page.

#' Render NEWS.md into the staging directory
#'
#' @return Invisibly, `list(route, versions)`, or `NULL` when there is no NEWS.
#' @noRd
sd_build_news <- function(pkg, stage_dir) {
  path <- sd_find_news(pkg$src_path)
  if (is.null(path)) {
    return(invisible(NULL))
  }

  source_lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  level <- sd_news_top_level(source_lines)
  versions <- sd_news_versions(source_lines, level = level)
  # Only a file that starts at `#` needs demoting; one already written with
  # `##` releases has no H1 to collide with the page title.
  body <- if (level <= 1L) sd_demote_headings(source_lines) else source_lines
  body <- sd_mark_release_dates(body)
  body <- sd_apply_base_to_links(paste0(body, collapse = "\n"), pkg$base)

  frontmatter <- list(
    title = "Changelog",
    description = paste0("Release notes for ", pkg$package, "."),
    sd = list(kind = "news")
  )

  file <- fs::path(stage_dir, "news.md")
  sd_write_file(paste0(sd_frontmatter(frontmatter), "\n", trimws(body), "\n"), file)

  invisible(list(
    name = "news",
    slug = "news",
    kind = "news",
    title = "Changelog",
    route = "/news/",
    file = "news.md",
    source = fs::path_file(path),
    versions = versions,
    latest = if (length(versions)) versions[[1L]]$version else NULL
  ))
}

#' @noRd
sd_find_news <- function(src_path) {
  candidates <- fs::path(src_path, c("NEWS.md", "inst/NEWS.md"))
  found <- candidates[fs::file_exists(candidates)]
  if (length(found)) found[[1L]] else NULL
}

# Release headings, in file order (newest first by convention). The version is
# the last whitespace-separated token that looks like one, so both
# "# pkg 1.2.3" and "# 1.2.3" work.
#' @noRd
sd_news_versions <- function(lines, level = 1L) {
  headings <- grep(paste0("^#{", level, "}\\s+\\S"), lines, value = TRUE)
  out <- list()
  for (heading in headings) {
    text <- trimws(sub("^#+\\s*", "", heading))
    version <- sd_extract_version(text)
    out[[length(out) + 1L]] <- sd_compact(list(
      version = version,
      date = sd_extract_date(text),
      title = text,
      # Anchors are the ids Starlight derives from the heading text; the
      # heading is demoted, but its text -- and so its id -- is unchanged.
      anchor = sd_heading_anchor(text)
    ))
  }
  out
}

# A release date written into the heading, as `# pkg 1.2.0 (2026-08-01)`.
# The shallowest heading level in the file is the one releases use.
#' @noRd
sd_news_top_level <- function(lines) {
  fence <- NA_character_
  levels <- integer()
  for (line in lines) {
    if (!is.na(fence)) {
      if (grepl(paste0("^[ \t]*", fence, "[ \t]*$"), line)) fence <- NA_character_
      next
    }
    opener <- regmatches(line, regexpr("^[ \t]*(`{3,}|~{3,})", line))
    if (length(opener) && nzchar(opener)) {
      fence <- sub("^[ \t]*", "", opener)
      next
    }
    hashes <- regmatches(line, regexpr("^#{1,6}(?=\\s+\\S)", line, perl = TRUE))
    if (length(hashes) && nzchar(hashes)) {
      levels <- c(levels, nchar(hashes))
    }
  }
  if (!length(levels)) 1L else min(levels)
}

#' @noRd
sd_extract_date <- function(text) {
  m <- regmatches(text, regexec("(\\d{4}-\\d{2}-\\d{2})", text))[[1L]]
  if (length(m) >= 2L) m[[2L]] else NULL
}

# Dates travel with their heading rather than through the manifest, so the
# frontend can render one next to the version it belongs to. The heading has
# already been demoted by the time this runs.
#' @noRd
sd_mark_release_dates <- function(lines) {
  for (i in seq_along(lines)) {
    if (!grepl("^##\\s+\\S", lines[[i]]) || grepl("<time", lines[[i]], fixed = TRUE)) {
      next
    }
    date <- sd_extract_date(lines[[i]])
    if (is.null(date)) {
      next
    }
    stamp <- paste0("<time datetime=\"", date, "\">", date, "</time>")
    lines[[i]] <- sub(
      paste0("\\(?", date, "\\)?"),
      stamp,
      lines[[i]]
    )
  }
  lines
}

#' @noRd
sd_extract_version <- function(text) {
  tokens <- strsplit(text, "[[:space:]]+")[[1L]]
  # A bare release date is not a version number.
  tokens <- tokens[!grepl("^\\(?\\d{4}-\\d{2}-\\d{2}\\)?[,.]?$", tokens)]
  numeric <- grep("^v?[0-9]+([.-][0-9]+)*", tokens, value = TRUE)
  if (length(numeric)) sub("^v", "", numeric[[length(numeric)]]) else text
}

# GitHub's heading-slug rules, which is what Starlight's autolink headings use:
# lowercase, drop everything that is not a word character, space or hyphen,
# then spaces to hyphens.
#' @noRd
sd_heading_anchor <- function(text) {
  slug <- tolower(text)
  slug <- gsub("[^[:alnum:][:space:]_-]", "", slug)
  slug <- gsub("[[:space:]]+", "-", trimws(slug))
  gsub("-+", "-", slug)
}

# Demote every ATX heading by one level, leaving fenced code untouched: a `#`
# inside a code block is a comment, not a heading.
#' @noRd
sd_demote_headings <- function(lines) {
  fence <- NA_character_
  for (i in seq_along(lines)) {
    line <- lines[[i]]
    if (!is.na(fence)) {
      if (grepl(paste0("^[ \t]*", fence, "[ \t]*$"), line)) {
        fence <- NA_character_
      }
      next
    }
    opener <- regmatches(line, regexpr("^[ \t]*(`{3,}|~{3,})", line))
    if (length(opener) && nzchar(opener)) {
      fence <- sub("^[ \t]*", "", opener)
      next
    }
    if (grepl("^#{1,5}\\s", line)) {
      lines[[i]] <- paste0("#", line)
    }
  }
  lines
}
