# npm / subprocess helpers ----------------------------------------------------

#' Run an npm command in a directory
#'
#' Wraps [processx::run()] so the working directory is set correctly
#' (`system2()` has no `cwd` argument). Streams output to the console.
#'
#' @param args Character vector of arguments passed to `npm`.
#' @param wd Directory in which to run the command.
#' @param error_on_status Abort if the command exits non-zero?
#' @return Invisibly, the [processx::run()] result list.
#' @keywords internal
#' @noRd
sd_npm <- function(args, wd, error_on_status = TRUE) {
  npm <- Sys.which("npm")
  if (!nzchar(npm)) {
    cli::cli_abort(c(
      "{.code npm} was not found on the {.envvar PATH}.",
      "i" = "Install Node.js (which bundles npm) from {.url https://nodejs.org} or via your package manager."
    ))
  }
  res <- processx::run(
    npm,
    args = args,
    wd = wd,
    echo = TRUE,
    error_on_status = FALSE
  )
  if (error_on_status && !identical(res$status, 0L)) {
    cli::cli_abort(c(
      "{.code npm {paste(args, collapse = ' ')}} failed with exit status {res$status} in {.path {wd}}.",
      "i" = "Run {.code npm install} in {.path {wd}} if dependencies are missing."
    ))
  }
  invisible(res)
}

#' Run a long-lived npm command (e.g. a dev server) in the foreground
#'
#' Unlike `sd_npm()`, the exit status is returned rather than treated as an
#' error, because dev servers exit non-zero when interrupted.
#'
#' @inheritParams sd_npm
#' @return Invisibly, the exit status.
#' @keywords internal
#' @noRd
sd_npm_foreground <- function(args, wd) {
  res <- sd_npm(args, wd, error_on_status = FALSE)
  invisible(res$status)
}
