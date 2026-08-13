#' Set up a GitHub Actions workflow for Starlight docs
#'
#' Writes a workflow that installs the package, builds the site with
#' [build_site()], and deploys it to GitHub Pages. The workflow installs
#' Quarto (needed only if the package has vignettes) and uses `npm ci`, so
#' `<site_dir>/package-lock.json` must be committed — the scaffold ships one.
#'
#' @param path Package root directory.
#' @param branch Git branch to publish from.
#' @param site_dir Starlight project directory, relative to `path`. The built
#'   output is taken from `<site_dir>/dist`.
#' @param overwrite Whether to overwrite an existing workflow file.
#'
#' @return Invisibly, the path to the workflow file.
#' @export
#' @examples
#' \dontrun{
#' use_starlight_github_actions()
#' }
use_starlight_github_actions <- function(path = ".",
                                         branch = "main",
                                         site_dir = "starlight",
                                         overwrite = FALSE) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)

  workflow_src <- system.file("gha", "starlight.yml", package = "starlightdown")
  if (workflow_src == "") {
    cli::cli_abort(
      "Could not find the workflow template in the package ({.path inst/gha/starlight.yml})."
    )
  }

  gh_dir <- fs::path(path, ".github", "workflows")
  fs::dir_create(gh_dir, recurse = TRUE)
  workflow_dest <- fs::path(gh_dir, "starlight.yml")

  if (fs::file_exists(workflow_dest) && !isTRUE(overwrite)) {
    cli::cli_abort(c(
      "A workflow already exists at {.path {workflow_dest}}.",
      "i" = "Set {.code overwrite = TRUE} to replace it."
    ))
  }

  # `site_dir` is substituted everywhere the site is named, rather than only in
  # the artifact path: a workflow that builds one directory and publishes
  # another is worse than no workflow at all.
  lines <- readLines(workflow_src, warn = FALSE, encoding = "UTF-8")
  lines <- gsub("{{BRANCH}}", branch, lines, fixed = TRUE)
  lines <- gsub("{{SITE_DIR}}", site_dir, lines, fixed = TRUE)
  lines <- gsub(
    "{{BUILD_ARGS}}",
    if (identical(site_dir, "starlight")) "" else paste0('site_dir = "', site_dir, '"'),
    lines,
    fixed = TRUE
  )
  writeLines(lines, workflow_dest, useBytes = TRUE)

  cli::cli_inform(c(
    "v" = "Workflow written to {.path {fs::path_rel(workflow_dest, path)}}.",
    "i" = "Enable Pages for this repository with source {.strong GitHub Actions}."
  ))
  invisible(workflow_dest)
}
