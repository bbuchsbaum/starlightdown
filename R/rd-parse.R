# Rd parsing ----------------------------------------------------------------
#
# We parse the .Rd sources directly rather than reading installed help, so a
# build reflects the working tree. Package-level Rd macros (`man/macros/`, and
# anything named in the DESCRIPTION `RdMacros` field) are loaded on top of the
# system macros, otherwise `\lifecycle{}`-style user macros would blow up.

#' Load the Rd macro set for a package
#'
#' @param pkg_path Package source directory, or `NULL` for system macros only.
#' @noRd
sd_rd_macros <- function(pkg_path = NULL) {
  system_macros <- file.path(R.home("share"), "Rd", "macros", "system.Rd")
  macros <- tools::loadRdMacros(system_macros)
  if (sd_is_string(pkg_path) && dir.exists(pkg_path)) {
    macros <- tryCatch(
      tools::loadPkgRdMacros(pkg_path, macros = macros),
      error = function(e) macros
    )
  }
  macros
}

#' Parse one Rd file
#'
#' @param file Path to an `.Rd` file.
#' @param pkg_path Package source directory (for `man/macros/`).
#' @param macros Pre-loaded macros; computed from `pkg_path` when missing.
#' @noRd
sd_rd_parse <- function(file, pkg_path = NULL, macros = NULL) {
  if (!file.exists(file)) {
    cli::cli_abort("Rd file {.path {file}} does not exist.")
  }
  if (is.null(macros)) {
    macros <- sd_rd_macros(pkg_path)
  }
  tools::parse_Rd(file, encoding = "UTF-8", macros = macros)
}

# Section splitting ---------------------------------------------------------

# Tags whose content is collected verbatim as a character vector rather than
# kept as an Rd fragment.
sd_rd_text_sections <- c("name", "docType", "encoding")

sd_rd_repeated_sections <- c("alias", "keyword", "concept")

#' Split a parsed Rd file into its top-level sections
#'
#' @param rd An object from `sd_rd_parse()`.
#' @return A named list. Fragment-valued entries keep their Rd structure so
#'   they can be handed to `sd_rd_to_md()`; `aliases`, `keywords`, `concepts`
#'   and `name` are plain character.
#' @noRd
sd_rd_sections <- function(rd) {
  out <- list(
    name = NA_character_,
    aliases = character(),
    keywords = character(),
    concepts = character(),
    docType = NA_character_,
    title = NULL,
    description = NULL,
    usage = NULL,
    arguments = NULL,
    value = NULL,
    details = NULL,
    note = NULL,
    seealso = NULL,
    examples = NULL,
    references = NULL,
    author = NULL,
    format = NULL,
    source = NULL,
    since = NULL,
    sections = list()
  )

  for (el in rd) {
    tag <- attr(el, "Rd_tag")
    if (is.null(tag) || !grepl("^\\\\", tag)) {
      next
    }
    key <- sub("^\\\\", "", tag)

    if (key == "section") {
      out$sections <- c(out$sections, list(list(
        title = el[[1L]],
        content = el[[2L]]
      )))
      next
    }

    if (key %in% sd_rd_text_sections) {
      out[[key]] <- trimws(sd_rd_flatten_text(el))
      next
    }

    if (key %in% sd_rd_repeated_sections) {
      target <- switch(key,
        alias = "aliases",
        keyword = "keywords",
        concept = "concepts"
      )
      out[[target]] <- c(out[[target]], trimws(sd_rd_flatten_text(el)))
      next
    }

    if (key %in% names(out)) {
      out[[key]] <- el
    }
  }

  out
}

# Flatten an Rd fragment to its raw text, ignoring markup. Used for
# metadata-ish sections (name, aliases, keywords) and for lifecycle sniffing.
#' @noRd
sd_rd_flatten_text <- function(x) {
  if (is.null(x)) {
    return("")
  }
  tag <- attr(x, "Rd_tag")
  if (!is.null(tag) && tag %in% c("COMMENT", "USERMACRO")) {
    return("")
  }
  if (is.character(x)) {
    return(sd_cat0(x))
  }
  if (!is.list(x)) {
    return("")
  }
  sd_cat0(vapply(x, sd_rd_flatten_text, character(1)))
}

# Raw source-ish text including tag names, so callers can look for markers
# such as `lifecycle-experimental.svg` regardless of how they were produced.
#' @noRd
sd_rd_raw_text <- function(x) {
  if (is.null(x)) {
    return("")
  }
  if (identical(attr(x, "Rd_tag"), "USERMACRO")) {
    return("")
  }
  if (is.character(x)) {
    return(sd_cat0(x))
  }
  if (!is.list(x)) {
    return("")
  }
  opt <- attr(x, "Rd_option")
  opt_text <- if (is.null(opt)) "" else sd_rd_raw_text(opt)
  paste0(opt_text, sd_cat0(vapply(x, sd_rd_raw_text, character(1))))
}
