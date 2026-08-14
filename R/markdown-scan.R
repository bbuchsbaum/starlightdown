# Markdown scanning ----------------------------------------------------------
#
# Every part of the build that reads or rewrites links goes through here. The
# old codebase's defining bug was regex over raw Markdown with no idea where
# code begins: a package documenting Markdown had its examples rewritten and
# its build aborted by its own code samples. So the rule is one scanner, and it
# knows about fenced blocks, inline code spans and HTML comments.
#
# The scanner works on a *view*: the document with every non-prose character
# replaced by a space, newlines kept. Offsets therefore match the original
# exactly, so a match found in the view can be rewritten in place.

#' Which characters of a Markdown document are prose?
#'
#' @return A logical vector, one element per character.
#' @noRd
sd_md_mask <- function(text) {
  n <- nchar(text)
  mask <- rep(TRUE, n)
  if (n == 0L) {
    return(mask)
  }

  lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  starts <- cumsum(c(1L, nchar(lines) + 1L))[seq_along(lines)]

  fence <- NA_character_
  for (i in seq_along(lines)) {
    line <- lines[[i]]
    from <- starts[[i]]
    to <- from + nchar(line) - 1L

    if (!is.na(fence)) {
      if (to >= from) mask[from:to] <- FALSE
      if (grepl(paste0("^[ \t]*", fence, "[ \t]*$"), line)) {
        fence <- NA_character_
      }
      next
    }

    opener <- regmatches(line, regexpr("^[ \t]*(`{3,}|~{3,})", line))
    if (length(opener) && nzchar(opener)) {
      fence <- sub("^[ \t]*", "", opener)
      if (to >= from) mask[from:to] <- FALSE
    }
  }

  # Inline code spans and HTML comments, which may straddle lines.
  for (pattern in c("(`+)[\\s\\S]*?\\1", "(?s)<!--.*?-->")) {
    found <- gregexpr(pattern, text, perl = TRUE)[[1L]]
    if (found[[1L]] == -1L) {
      next
    }
    lengths <- attr(found, "match.length")
    for (k in seq_along(found)) {
      mask[found[[k]]:(found[[k]] + lengths[[k]] - 1L)] <- FALSE
    }
  }

  mask
}

#' The document with non-prose blanked out, offsets preserved
#' @noRd
sd_md_view <- function(text) {
  mask <- sd_md_mask(text)
  if (all(mask)) {
    return(text)
  }
  chars <- strsplit(text, "", fixed = TRUE)[[1L]]
  blank <- !mask & chars != "\n"
  chars[blank] <- " "
  paste0(chars, collapse = "")
}

# Regex matches with capture-group offsets, as a plain data frame.
#' @noRd
sd_md_matches <- function(view, pattern, groups) {
  found <- gregexpr(pattern, view, perl = TRUE)[[1L]]
  if (found[[1L]] == -1L) {
    return(NULL)
  }
  starts <- attr(found, "capture.start")
  lengths <- attr(found, "capture.length")
  names <- attr(found, "capture.names")

  out <- list()
  for (g in groups) {
    idx <- match(g, names)
    out[[paste0(g, "_start")]] <- starts[, idx]
    out[[paste0(g, "_len")]] <- lengths[, idx]
  }
  as.data.frame(out, stringsAsFactors = FALSE)
}

#' @noRd
sd_md_slice <- function(text, start, len) {
  # substring(), not substr(): vectorised over the offsets.
  out <- substring(text, start, start + len - 1L)
  out[len <= 0L] <- ""
  out
}

# Link forms -----------------------------------------------------------------

# Inline links and images, with an optional title. Code spans are already
# blanked in the view, so brackets inside them cannot confuse the label.
sd_md_inline_pattern <- paste0(
  "(?<bang>!?)\\[[^\\]\n]*\\]\\(\\s*",
  "(?<target><[^>\n]*>|[^()\\s]+)",
  "(?:\\s+(?:\"[^\"]*\"|'[^']*'|\\([^)]*\\)))?\\s*\\)"
)

# `[id]: /route/ "Title"` -- the definition is where a reference-style link's
# target actually lives, so validating and rewriting it covers every use.
sd_md_reference_pattern <- "(?m)^[ \t]{0,3}\\[[^\\]\n]+\\]:[ \t]*(?<target><[^>\n]*>|\\S+)"

# Raw HTML, which Markdown passes straight through to the page.
sd_md_html_href_pattern <-
  "<a\\b[^>]*?\\bhref\\s*=\\s*(?<target>\"[^\"]*\"|'[^']*'|[^\\s>]+)"
sd_md_html_src_pattern <-
  "<img\\b[^>]*?\\bsrc\\s*=\\s*(?<target>\"[^\"]*\"|'[^']*'|[^\\s>]+)"

#' Every link and image target in a document
#'
#' @return A data frame with `target`, `start`, `len` (offsets into `text`) and
#'   `image` (logical). Targets keep their original spelling; use
#'   `sd_md_decode_target()` before touching the filesystem.
#' @noRd
sd_md_targets <- function(text) {
  view <- sd_md_view(text)
  rows <- list()

  inline <- sd_md_matches(view, sd_md_inline_pattern, c("bang", "target"))
  if (!is.null(inline)) {
    rows[[length(rows) + 1L]] <- data.frame(
      start = inline$target_start,
      len = inline$target_len,
      image = sd_md_slice(view, inline$bang_start, inline$bang_len) == "!" &
        inline$bang_len > 0L,
      stringsAsFactors = FALSE
    )
  }

  for (spec in list(
    list(pattern = sd_md_reference_pattern, image = FALSE),
    list(pattern = sd_md_html_href_pattern, image = FALSE),
    list(pattern = sd_md_html_src_pattern, image = TRUE)
  )) {
    found <- sd_md_matches(view, spec$pattern, "target")
    if (is.null(found)) {
      next
    }
    rows[[length(rows) + 1L]] <- data.frame(
      start = found$target_start,
      len = found$target_len,
      image = spec$image,
      stringsAsFactors = FALSE
    )
  }

  if (!length(rows)) {
    return(data.frame(
      target = character(), start = integer(), len = integer(),
      image = logical(), stringsAsFactors = FALSE
    ))
  }

  out <- do.call(rbind, rows)
  out <- out[out$len > 0L, , drop = FALSE]
  out$target <- vapply(
    seq_len(nrow(out)),
    function(i) sd_md_unwrap_target(sd_md_slice(text, out$start[[i]], out$len[[i]])),
    character(1)
  )
  out[order(out$start, method = "radix"), , drop = FALSE]
}

# `<path with spaces>` and quoted HTML attributes both wrap the real target.
#' @noRd
sd_md_unwrap_target <- function(target) {
  target <- trimws(target)
  if (grepl("^<.*>$", target)) {
    return(substr(target, 2L, nchar(target) - 1L))
  }
  if (grepl('^".*"$', target) || grepl("^'.*'$", target)) {
    return(substr(target, 2L, nchar(target) - 1L))
  }
  target
}

# A target names a file on disk, so percent-encoding has to come off before we
# look for it -- `my%20logo.png` is `my logo.png`.
#' @noRd
sd_md_decode_target <- function(target) {
  target <- sub("[#?].*$", "", target)
  decoded <- tryCatch(utils::URLdecode(target), error = function(e) target)
  if (is.na(decoded)) target else decoded
}

# Whole `<img ...>` tags, so one can be replaced rather than just its src.
sd_md_html_img_tag_pattern <- "<img\\b[^>]*?/?>"

#' Offsets of whole matches, for rewrites that replace more than a capture group
#' @noRd
sd_md_whole_matches <- function(view, pattern) {
  found <- gregexpr(pattern, view, perl = TRUE)[[1L]]
  if (found[[1L]] == -1L) {
    return(NULL)
  }
  data.frame(
    start = as.integer(found),
    len = attr(found, "match.length"),
    stringsAsFactors = FALSE
  )
}

#' Rewrite raw `<img>` tags with a local source as Markdown images
#'
#' Quarto emits raw HTML for any chunk that sets `fig-align` or `out.width`.
#' Astro only routes *Markdown* image syntax through its asset pipeline, so a
#' raw tag is passed through verbatim and the file it names -- which lives
#' under `src/content/` -- is never emitted to the build. The image then 404s
#' on a page that otherwise looks fine. Converting to `![alt](src)` puts these
#' figures through the same pipeline as every other image.
#'
#' Absolute, protocol-relative and root-absolute sources are left alone: those
#' resolve without help, and a root-absolute one is already a `public/` asset.
#'
#' @noRd
sd_html_images_to_markdown <- function(text) {
  view <- sd_md_view(text)
  tags <- sd_md_whole_matches(view, sd_md_html_img_tag_pattern)
  if (is.null(tags)) {
    return(text)
  }

  # Back to front, so earlier offsets stay valid as we splice.
  ord <- order(tags$start, method = "radix", decreasing = TRUE)
  for (i in ord) {
    tag <- sd_md_slice(text, tags$start[[i]], tags$len[[i]])
    src <- sd_html_attr(tag, "src")
    if (!sd_is_string(src) || !sd_md_is_relative(src)) {
      next
    }
    alt <- sd_html_attr(tag, "alt")
    replacement <- paste0("![", if (sd_is_string(alt)) alt else "", "](", src, ")")
    text <- paste0(
      substr(text, 1L, tags$start[[i]] - 1L),
      replacement,
      substr(text, tags$start[[i]] + tags$len[[i]], nchar(text))
    )
  }
  text
}

#' A single HTML attribute value, unquoted
#' @noRd
sd_html_attr <- function(tag, name) {
  pattern <- paste0(
    "\\b", name, "\\s*=\\s*(\"([^\"]*)\"|'([^']*)'|([^\\s>]+))"
  )
  m <- regmatches(tag, regexec(pattern, tag, perl = TRUE))[[1L]]
  if (!length(m)) {
    return(NA_character_)
  }
  value <- m[[3L]]
  if (!nzchar(value)) value <- m[[4L]]
  if (!nzchar(value)) value <- m[[5L]]
  value
}

#' Raw `<img>` tags that still name a local file
#'
#' Anything left here after conversion would silently 404, so the validator
#' treats it as a build failure rather than shipping a broken figure.
#' @noRd
sd_unemittable_images <- function(text) {
  view <- sd_md_view(text)
  tags <- sd_md_whole_matches(view, sd_md_html_img_tag_pattern)
  if (is.null(tags)) {
    return(character())
  }
  srcs <- vapply(
    seq_len(nrow(tags)),
    function(i) sd_html_attr(sd_md_slice(text, tags$start[[i]], tags$len[[i]]), "src"),
    character(1)
  )
  srcs <- srcs[!is.na(srcs)]
  unique(srcs[sd_md_is_relative(srcs)])
}

#' Is this target a local relative path?
#' @noRd
sd_md_is_relative <- function(target) {
  nzchar(target) &
    !grepl("^([A-Za-z][A-Za-z0-9+.-]*:|//|/|#)", target)
}

#' Relative link and image targets, decoded and de-duplicated
#' @noRd
sd_relative_targets <- function(text) {
  targets <- sd_md_targets(text)
  if (!nrow(targets)) {
    return(character())
  }
  decoded <- vapply(targets$target, sd_md_decode_target, character(1), USE.NAMES = FALSE)
  decoded <- decoded[sd_md_is_relative(decoded)]
  unique(decoded[nzchar(decoded)])
}

#' Root-relative link targets (the ones a base must be applied to)
#' @noRd
sd_root_link_targets <- function(text) {
  targets <- sd_md_targets(text)
  if (!nrow(targets)) {
    return(character())
  }
  hrefs <- sub("[#?].*$", "", targets$target[!targets$image])
  unique(grep("^/(?!/)", hrefs, value = TRUE, perl = TRUE))
}

# Rewriting ------------------------------------------------------------------

#' Rewrite link targets in prose, leaving code and images untouched
#'
#' @param fn Given a target, returns its replacement (or the target unchanged).
#' @noRd
sd_md_rewrite_targets <- function(text, fn, images = FALSE) {
  targets <- sd_md_targets(text)
  if (!nrow(targets)) {
    return(text)
  }
  if (!images) {
    targets <- targets[!targets$image, , drop = FALSE]
  }
  if (!nrow(targets)) {
    return(text)
  }

  # Back to front, so earlier offsets stay valid as we splice.
  targets <- targets[order(targets$start, method = "radix", decreasing = TRUE), , drop = FALSE]
  for (i in seq_len(nrow(targets))) {
    original <- sd_md_slice(text, targets$start[[i]], targets$len[[i]])
    replacement <- fn(targets$target[[i]])
    if (identical(replacement, targets$target[[i]])) {
      next
    }
    # Preserve whatever wrapper the author used.
    if (grepl("^<.*>$", trimws(original))) {
      replacement <- paste0("<", replacement, ">")
    } else if (grepl('^".*"$', trimws(original))) {
      replacement <- paste0('"', replacement, '"')
    } else if (grepl("^'.*'$", trimws(original))) {
      replacement <- paste0("'", replacement, "'")
    }
    text <- paste0(
      substr(text, 1L, targets$start[[i]] - 1L),
      replacement,
      substr(text, targets$start[[i]] + targets$len[[i]], nchar(text))
    )
  }
  text
}
