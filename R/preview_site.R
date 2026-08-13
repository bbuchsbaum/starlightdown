#' Preview the Starlight site with a development server
#'
#' Runs `npm run dev` in the Starlight project directory. The server runs in
#' the foreground until interrupted. You must have run `npm install` in
#' `site_dir` first (or `use_starlight_site()` followed by `npm install`).
#'
#' @param path Package root directory.
#' @param site_dir Starlight project directory, relative to `path`.
#' @param npm_args Character vector of arguments passed to `npm`.
#'   Defaults to `c("run", "dev")`.
#'
#' @return Invisibly, the exit status of the npm command.
#' @export
preview_site <- function(path = ".",
                         site_dir = "starlight",
                         npm_args = c("run", "dev")) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  site_path <- file.path(path, site_dir)

  if (!dir.exists(site_path)) {
    cli::cli_abort("Starlight site directory {.path {site_dir}} does not exist.")
  }
  if (!dir.exists(file.path(site_path, "node_modules"))) {
    cli::cli_inform(c(
      "!" = "{.path {file.path(site_dir, 'node_modules')}} not found.",
      "i" = "Running {.code npm install} first."
    ))
    sd_npm("install", wd = site_path)
  }

  sd_npm_foreground(npm_args, wd = site_path)
}
