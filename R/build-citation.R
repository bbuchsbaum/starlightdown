# Citation -------------------------------------------------------------------
#
# `inst/CITATION` is R code, evaluated by `utils::readCitationFile()` against
# the package metadata. Packages without one still get a citation: R's own
# default for such a package is a Manual entry built from DESCRIPTION, and we
# synthesise the same thing rather than leaving the block empty.

#' Citation text and BibTeX for the manifest
#'
#' @return `list(text, bibtex)`, or `NULL` when neither source works.
#' @noRd
sd_build_citation <- function(pkg) {
  entry <- sd_citation_entry(pkg)
  if (is.null(entry)) {
    return(NULL)
  }

  text <- tryCatch(
    paste0(format(entry, style = "text"), collapse = "\n\n"),
    error = function(e) NULL
  )
  bibtex <- tryCatch(
    paste0(format(entry, style = "bibtex"), collapse = "\n\n"),
    error = function(e) NULL
  )

  out <- sd_compact(list(
    text = if (sd_is_string(text)) sd_clean_citation_text(text) else NULL,
    bibtex = if (sd_is_string(bibtex)) bibtex else NULL
  ))
  if (!length(out)) NULL else out
}

#' @noRd
sd_citation_entry <- function(pkg) {
  path <- fs::path(pkg$src_path, "inst", "CITATION")
  meta <- sd_citation_meta(pkg)

  if (fs::file_exists(path)) {
    entry <- tryCatch(
      utils::readCitationFile(path, meta = meta),
      error = function(e) {
        cli::cli_warn(c(
          "Could not read {.path inst/CITATION}: {conditionMessage(e)}",
          "i" = "Falling back to a citation built from DESCRIPTION."
        ))
        NULL
      }
    )
    if (!is.null(entry)) {
      return(entry)
    }
  }

  sd_default_citation(pkg, meta)
}

# `readCitationFile()` evaluates the file with `meta` in scope, so it needs the
# same shape `packageDescription()` returns.
#' @noRd
sd_citation_meta <- function(pkg) {
  fields <- tryCatch(pkg$desc$fields(), error = function(e) character())
  meta <- list()
  for (field in fields) {
    value <- tryCatch(pkg$desc$get_field(field, default = NA_character_), error = function(e) NA_character_)
    if (!is.na(value)) {
      meta[[field]] <- value
    }
  }
  meta$Package <- meta$Package %||% pkg$package
  meta$Version <- meta$Version %||% pkg$version
  meta
}

#' @noRd
sd_default_citation <- function(pkg, meta) {
  authors <- tryCatch(pkg$desc$get_authors(), error = function(e) NULL)
  if (is.null(authors)) {
    authors <- tryCatch(utils::person(sd_desc_field(pkg$desc, "Author", "Unknown")), error = function(e) NULL)
  }
  if (is.null(authors)) {
    return(NULL)
  }
  creators <- Filter(function(p) "aut" %in% p$role || "cre" %in% p$role, authors)
  if (!length(creators)) {
    creators <- authors
  }

  title <- sd_desc_field(pkg$desc, "Title", pkg$package)
  year <- sd_package_year(pkg)
  fields <- sd_compact(list(
    bibtype = "Manual",
    title = paste0(pkg$package, ": ", title),
    author = creators,
    year = year,
    note = paste0("R package version ", pkg$version)
  ))
  tryCatch(do.call(utils::bibentry, fields), error = function(e) NULL)
}

# The publication year, from DESCRIPTION. Never `Sys.Date()`: the manifest is
# meant to be byte-identical across builds, and a wall-clock year makes it
# change on the 1st of January for no reason.
#' @noRd
sd_package_year <- function(pkg) {
  for (field in c("Date", "Date/Publication", "Packaged")) {
    value <- sd_desc_field(pkg$desc, field, NULL)
    year <- if (is.null(value)) NULL else regmatches(value, regexpr("\\d{4}", value))
    if (length(year) && nzchar(year)) {
      return(year[[1L]])
    }
  }
  NULL
}

# `format(style = "text")` wraps to the console width, which would put a line
# break into the manifest at whatever width the build machine happened to use.
#' @noRd
sd_clean_citation_text <- function(text) {
  paragraphs <- strsplit(text, "\n\n", fixed = TRUE)[[1L]]
  paragraphs <- vapply(
    paragraphs,
    function(p) trimws(gsub("[[:space:]]+", " ", p)),
    character(1)
  )
  paste0(paragraphs[nzchar(paragraphs)], collapse = "\n\n")
}
