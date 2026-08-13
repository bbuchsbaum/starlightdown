`%||%` <- function(x, y) if (is.null(x)) y else x

# Drop NULL / zero-length entries from a list, keeping names.
#' @noRd
sd_compact <- function(x) {
  x[!vapply(x, function(el) is.null(el) || length(el) == 0L, logical(1))]
}

# Is `x` a usable length-1 character value?
#' @noRd
sd_is_string <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
}

# Collapse a character vector into one string.
#' @noRd
sd_cat0 <- function(x) paste0(x, collapse = "")

# Normalise generated Markdown: strip trailing whitespace and collapse runs of
# blank lines. Fenced code blocks are copied through untouched -- inside a
# fence, trailing spaces and blank lines are content.
#' @noRd
sd_tidy_md <- function(x) {
  if (!length(x)) {
    return("")
  }
  text <- gsub("\r\n", "\n", sd_cat0(x), fixed = TRUE)
  if (!nzchar(text)) {
    return("")
  }

  lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  out <- character(length(lines))
  n <- 0L
  fence <- NA_character_
  blank_run <- 0L

  for (line in lines) {
    if (!is.na(fence)) {
      n <- n + 1L
      out[[n]] <- line
      if (grepl(paste0("^[ \t]*", fence, "[ \t]*$"), line)) {
        fence <- NA_character_
      }
      next
    }

    opener <- regmatches(line, regexpr("^[ \t]*(`{3,}|~{3,})", line))
    if (length(opener) && nzchar(opener)) {
      fence <- sub("^[ \t]*", "", opener)
      n <- n + 1L
      out[[n]] <- sub("[ \t]+$", "", line)
      blank_run <- 0L
      next
    }

    line <- sub("[ \t]+$", "", line)
    if (!nzchar(line)) {
      blank_run <- blank_run + 1L
      if (blank_run > 1L) {
        next
      }
    } else {
      blank_run <- 0L
    }
    n <- n + 1L
    out[[n]] <- line
  }

  trimws(paste0(out[seq_len(n)], collapse = "\n"))
}

# Slug for a topic: pkgdown's `file_out` without the .html extension.
#' @noRd
sd_slug <- function(file_out) sub("\\.html$", "", file_out)

# Serialise to YAML. Always via yaml::as.yaml so that quoting and escaping are
# the serialiser's problem, never ours -- and always with YAML 1.2 booleans,
# because both Quarto and Astro reject the `yes`/`no` spelling that R's yaml
# package emits by default.
#' @noRd
sd_as_yaml <- function(x) {
  yaml::as.yaml(
    x,
    indent = 2L,
    line.sep = "\n",
    handlers = list(logical = yaml::verbatim_logical)
  )
}

# Render a list as a YAML frontmatter block.
#' @noRd
sd_frontmatter <- function(x) {
  paste0("---\n", sd_as_yaml(x), "---\n")
}

# Write a character vector to `path`, creating parent directories.
#' @noRd
sd_write_file <- function(text, path) {
  fs::dir_create(fs::path_dir(path))
  con <- file(path, open = "wb", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  writeLines(enc2utf8(sd_cat0(text)), con, sep = "", useBytes = TRUE)
  invisible(path)
}

# Warn at most once per (context, key) pair.
#' @noRd
sd_warn_once <- function(ctx, key, message, .envir = parent.frame()) {
  store <- ctx$warned
  if (is.environment(store)) {
    if (!is.null(store[[key]])) {
      return(invisible(FALSE))
    }
    assign(key, TRUE, envir = store)
  }
  cli::cli_warn(message, .envir = .envir)
  invisible(TRUE)
}
