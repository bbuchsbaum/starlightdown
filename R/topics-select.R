# Reference selector resolution ---------------------------------------------
#
# `_pkgdown.yml` reference sections address topics with a small selector
# language. pkgdown's own resolver is unexported, so starlightdown ships its
# own. Selector strings are *parsed*, never evaluated: we accept a call to a
# known selector with a single string literal and nothing else, so a
# `_pkgdown.yml` can never smuggle code into the build.

sd_selectors <- c(
  "starts_with",
  "ends_with",
  "matches",
  "contains",
  "has_concept",
  "has_keyword",
  "everything"
)

#' Resolve a `contents:` vector to topic names
#'
#' @param contents Character vector or list of selector strings.
#' @param topics The `topics` tibble from `sd_pkg()`.
#' @param section Optional section title, used in diagnostics.
#' @return A character vector of topic names, in selection order.
#' @noRd
sd_select_topics <- function(contents, topics, section = NULL) {
  entries <- sd_selector_entries(contents, section = section)
  if (!length(entries) || !nrow(topics)) {
    return(character())
  }

  selected <- character()
  unmatched <- character()
  labels <- sd_topic_labels(topics)

  for (entry in entries) {
    sel <- sd_parse_selector(entry, labels)
    if (is.null(sel)) {
      where <- sd_in_section(section)
      cli::cli_warn(c(
        "Ignoring unsupported reference selector {.val {entry}}{where}.",
        "i" = "Supported: literal topic names and {.code {paste0(sd_selectors, '()')}}."
      ))
      next
    }

    names <- sd_match_selector(sel, topics)
    if (sel$kind == "literal" && !length(names)) {
      unmatched <- c(unmatched, sel$value)
      next
    }

    selected <- if (sel$negate) setdiff(selected, names) else union(selected, names)
  }

  if (length(unmatched)) {
    where <- sd_in_section(section)
    noun <- if (length(unmatched) == 1L) "topic" else "topics"
    cli::cli_warn(c(
      "Can't find reference {noun}{where}: {.val {unmatched}}.",
      "i" = "Selectors match topic names and aliases."
    ))
  }

  selected
}

#' @noRd
sd_in_section <- function(section) {
  if (sd_is_string(section)) paste0(" in reference section '", section, "'") else ""
}

# Flatten a yaml-derived `contents:` into character entries.
#' @noRd
sd_selector_entries <- function(contents, section = NULL) {
  if (is.null(contents) || !length(contents)) {
    return(character())
  }
  if (is.character(contents)) {
    return(contents[!is.na(contents) & nzchar(trimws(contents))])
  }
  if (!is.list(contents)) {
    return(character())
  }

  ok <- vapply(contents, function(x) is.character(x) && length(x) == 1L, logical(1))
  if (any(!ok)) {
    n <- sum(!ok)
    where <- sd_in_section(section)
    noun <- if (n == 1L) "entry" else "entries"
    cli::cli_warn("Ignoring {n} non-string {.field contents} {noun}{where}.")
  }
  entries <- as.character(unlist(contents[ok], use.names = FALSE))
  entries[!is.na(entries) & nzchar(trimws(entries))]
}

# Every name a literal selector may address.
#' @noRd
sd_topic_labels <- function(topics) {
  if (!nrow(topics)) {
    return(character())
  }
  unique(c(unname(topics$name), unlist(topics$alias, use.names = FALSE)))
}

# Parse one selector string. Returns NULL for anything we don't recognise.
#
# Existing topic names win over every syntactic reading, because operator
# methods make perfectly good topic names: `-.difftime` is a topic, not a
# negated `.difftime`, and `+.myclass` parses as a call to `+` rather than as
# the name it plainly is.
#' @noRd
sd_parse_selector <- function(entry, labels = character()) {
  entry <- trimws(entry)
  if (!nzchar(entry)) {
    return(NULL)
  }
  if (entry %in% labels) {
    return(list(kind = "literal", value = entry, negate = FALSE))
  }

  negate <- FALSE
  rest <- entry
  if (grepl("^-", entry)) {
    negate <- TRUE
    rest <- trimws(sub("^-[[:space:]]*", "", entry))
    if (!nzchar(rest)) {
      return(NULL)
    }
    if (rest %in% labels) {
      return(list(kind = "literal", value = rest, negate = TRUE))
    }
  }

  # Only something shaped like `name(...)` is treated as a selector call, so an
  # operator name can never be mistaken for one.
  if (grepl("^[A-Za-z._][A-Za-z0-9._]*\\(", rest)) {
    expr <- tryCatch(str2lang(rest), error = function(e) NULL)
    if (!is.call(expr) || !is.symbol(expr[[1L]])) {
      return(NULL)
    }
    fn <- as.character(expr[[1L]])
    if (!fn %in% sd_selectors) {
      return(NULL)
    }
    args <- as.list(expr)[-1L]
    if (fn == "everything") {
      if (length(args)) {
        return(NULL)
      }
      return(list(kind = "everything", value = NA_character_, negate = negate))
    }
    if (length(args) != 1L || !is.character(args[[1L]]) || length(args[[1L]]) != 1L) {
      return(NULL)
    }
    return(list(kind = fn, value = args[[1L]], negate = negate))
  }

  quoted <- tryCatch(str2lang(rest), error = function(e) NULL)
  value <- if (is.character(quoted) && length(quoted) == 1L) quoted else rest
  list(kind = "literal", value = value, negate = negate)
}

# `matches()` takes a user-written regular expression; an invalid one would
# otherwise surface as a raw PCRE error, once per topic, with no hint of where
# it came from. Check it once, against a string it cannot match.
#' @noRd
sd_validate_pattern <- function(pattern) {
  problem <- withCallingHandlers(
    tryCatch(
      {
        grepl(pattern, "", perl = TRUE)
        NULL
      },
      error = function(e) conditionMessage(e)
    ),
    warning = function(w) invokeRestart("muffleWarning")
  )
  if (!is.null(problem)) {
    cli::cli_abort(c(
      "Invalid regular expression in {.code matches(\"{pattern}\")}.",
      "x" = problem,
      "i" = "Fix the pattern in the {.field reference} section of {.file _pkgdown.yml}."
    ))
  }
  invisible(TRUE)
}

# Which topics does a parsed selector match?
#' @noRd
sd_match_selector <- function(sel, topics) {
  n <- nrow(topics)
  labels <- lapply(seq_len(n), function(i) unique(c(topics$name[[i]], topics$alias[[i]])))

  hit <- switch(sel$kind,
    literal = vapply(labels, function(x) sel$value %in% x, logical(1)),
    starts_with = vapply(labels, function(x) any(startsWith(x, sel$value)), logical(1)),
    ends_with = vapply(labels, function(x) any(endsWith(x, sel$value)), logical(1)),
    contains = vapply(
      labels,
      function(x) any(grepl(sel$value, x, fixed = TRUE)),
      logical(1)
    ),
    matches = {
      sd_validate_pattern(sel$value)
      vapply(labels, function(x) any(grepl(sel$value, x, perl = TRUE)), logical(1))
    },
    has_concept = vapply(
      seq_len(n),
      function(i) sel$value %in% topics$concepts[[i]],
      logical(1)
    ),
    has_keyword = vapply(
      seq_len(n),
      function(i) sel$value %in% topics$keywords[[i]],
      logical(1)
    ),
    everything = rep(TRUE, n),
    rep(FALSE, n)
  )

  # Wildcard selectors never sweep internal topics in; naming a topic outright
  # (or asking for the internal keyword) still does.
  wants_internal <- sel$kind == "literal" ||
    (sel$kind == "has_keyword" && identical(sel$value, "internal"))
  if (!wants_internal) {
    hit <- hit & !as.logical(topics$internal)
  }

  unname(topics$name[hit])
}
