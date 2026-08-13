# Quarto ---------------------------------------------------------------------
#
# Articles are executed by Quarto rather than by us: it owns the R session, the
# freeze cache, the figure directories and the GFM writer. We only locate the
# binary, generate a project file and read the results back.

#' Locate the Quarto binary
#'
#' Looks at `QUARTO_PATH`, then `PATH`, then the copy RStudio bundles -- which
#' is often the only one a user has.
#'
#' @return Path to the binary, or `NA_character_` when there is none.
#' @noRd
sd_quarto_bin <- function() {
  from_env <- Sys.getenv("QUARTO_PATH", unset = "")
  if (nzchar(from_env) && file.exists(from_env)) {
    return(from_env)
  }

  on_path <- unname(Sys.which("quarto"))
  if (nzchar(on_path)) {
    return(on_path)
  }

  bundled <- c(
    "/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto",
    "/usr/lib/rstudio/resources/app/quarto/bin/quarto",
    "/usr/lib/rstudio-server/resources/app/quarto/bin/quarto",
    file.path(
      Sys.getenv("ProgramFiles", unset = "C:/Program Files"),
      "RStudio/resources/app/quarto/bin/quarto.exe"
    )
  )
  found <- bundled[file.exists(bundled)]
  if (length(found)) {
    return(found[[1L]])
  }

  NA_character_
}

#' @noRd
sd_quarto_version <- function(bin = sd_quarto_bin()) {
  if (!sd_is_string(bin)) {
    return(NA_character_)
  }
  out <- tryCatch(
    processx::run(bin, "--version", error_on_status = FALSE),
    error = function(e) NULL
  )
  if (is.null(out) || out$status != 0L) {
    return(NA_character_)
  }
  trimws(out$stdout)
}

#' Abort unless Quarto is usable
#'
#' Reference-only builds never call this, so a package without vignettes can be
#' built with no Quarto installed at all.
#' @noRd
sd_require_quarto <- function(bin = sd_quarto_bin()) {
  if (sd_is_string(bin)) {
    return(invisible(bin))
  }
  cli::cli_abort(c(
    "Quarto is required to build articles, and no {.code quarto} binary was found.",
    "i" = "Install it from {.url https://quarto.org/docs/get-started/}.",
    "i" = "Or set {.envvar QUARTO_PATH} to an existing installation.",
    "i" = "Or build without articles: {.code build_site(articles = FALSE)}."
  ))
}

#' Render a Quarto project
#'
#' @param wd Project directory; Quarto is run with this as its cwd so all its
#'   relative paths, caches and `_files/` directories land inside it.
#' @param targets Files to render, relative to `wd`. Empty renders the project.
#' @noRd
sd_quarto_render <- function(wd,
                             targets = character(),
                             to = "gfm",
                             bin = sd_quarto_bin(),
                             quiet = TRUE) {
  sd_require_quarto(bin)

  args <- c("render", targets, "--to", to)
  result <- processx::run(
    bin,
    args,
    wd = wd,
    env = sd_quarto_env(),
    error_on_status = FALSE,
    stderr_to_stdout = TRUE,
    echo = !quiet
  )

  if (result$status != 0L) {
    cli::cli_abort(c(
      "Quarto failed to render the package's articles.",
      "i" = "Ran {.code quarto {paste(args, collapse = ' ')}} in {.path {wd}}.",
      "x" = "{sd_last_lines(result$stdout, 25)}"
    ))
  }

  invisible(result)
}

# Quarto starts its own R session, which would otherwise see only the default
# library. Vignettes call `library(<pkg>)`, so the child has to search exactly
# the libraries this session searches -- including a temporary one holding the
# package under test.
#' @noRd
sd_quarto_env <- function() {
  c(
    "current",
    R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep),
    R_LIBS_USER = paste(.libPaths(), collapse = .Platform$path.sep)
  )
}

# The tail of a subprocess log, which is where its error actually is.
#' @noRd
sd_last_lines <- function(text, n = 20L) {
  lines <- strsplit(gsub("\r\n", "\n", text %||% ""), "\n", fixed = TRUE)[[1L]]
  lines <- lines[nzchar(trimws(lines))]
  if (!length(lines)) {
    return("(no output)")
  }
  paste0(utils::tail(lines, n), collapse = "\n")
}

# Cache ----------------------------------------------------------------------

#' Persistent cache root
#'
#' Article builds happen in a copy of the package kept here, so Quarto's freeze
#' cache survives between builds and an unchanged vignette is not re-executed.
#' @noRd
sd_cache_dir <- function() {
  root <- Sys.getenv("STARLIGHTDOWN_CACHE_DIR", unset = "")
  if (!nzchar(root)) {
    root <- tools::R_user_dir("starlightdown", "cache")
  }
  root
}

#' @noRd
sd_cache_build_dir <- function(pkg) {
  key <- substr(
    sd_hash(paste0(pkg$package, "\n", as.character(fs::path_abs(pkg$src_path)))),
    1L, 10L
  )
  fs::path(sd_cache_dir(), "articles", paste0(pkg$package, "-", key))
}

#' A stable short hash, without pulling in a hashing dependency
#' @noRd
sd_hash <- function(x) {
  path <- tempfile()
  on.exit(unlink(path), add = TRUE)
  writeLines(enc2utf8(x), path, useBytes = TRUE)
  unname(tools::md5sum(path))
}
