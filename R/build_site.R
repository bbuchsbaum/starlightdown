#' Build the Starlight documentation site for a package
#'
#' Compiles package documentation (reference topics, articles, README, NEWS,
#' citation) into the Starlight content collection at
#' `<site_dir>/src/content/docs/`, along with a typed `site.json` manifest
#' consumed by the bundled Starlight plugin. Output is staged, validated, and
#' committed atomically: a failed build never touches the live site, and
#' removed source pages cannot survive as stale output.
#'
#' @param path Package root directory.
#' @param site_dir Starlight project directory, relative to `path`.
#' @param articles Build vignettes/articles (requires Quarto)?
#' @param examples Run examples in reference topics?
#' @param run_dont_run Run `\dontrun{}` example blocks?
#' @param lazy Reuse cached article renders when sources are unchanged?
#' @param theme Site theme: `"default"` for the bundled Editorial Scientific
#'   theme, or `"nova"` for that preset. `NULL` reads
#'   `starlightdown: theme:` from `_pkgdown.yml`.
#' @param npm_build If `TRUE`, run `npm run build` after generating content.
#' @param quiet Suppress progress messages?
#'
#' @return Invisibly, the path to `site_dir`.
#' @export
#' @examples
#' \dontrun{
#' build_site()
#' }
build_site <- function(path = ".",
                       site_dir = "starlight",
                       articles = TRUE,
                       examples = TRUE,
                       run_dont_run = FALSE,
                       lazy = TRUE,
                       theme = NULL,
                       npm_build = FALSE,
                       quiet = FALSE) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)

  desc_path <- file.path(path, "DESCRIPTION")
  if (!file.exists(desc_path)) {
    cli::cli_abort("No DESCRIPTION found at {.path {desc_path}}.")
  }

  site_path <- file.path(path, site_dir)
  astro_file <- file.path(site_path, "astro.config.mjs")
  if (!file.exists(astro_file)) {
    cli::cli_abort(c(
      "No Astro config found at {.path {astro_file}}.",
      "i" = "Run {.fn use_starlight_site} first."
    ))
  }

  say <- function(...) if (!isTRUE(quiet)) cli::cli_inform(...)

  pkg <- sd_pkg(path)
  theme <- sd_site_theme(pkg, theme)
  if (is.na(pkg$site_url)) {
    cli::cli_warn(c(
      "No documentation URL found, so the site will be built without one.",
      "i" = "Sitemaps and canonical links need it.",
      "i" = "Set {.field url} in {.file _pkgdown.yml}, or add a documentation
             URL to {.field URL} in DESCRIPTION."
    ))
  }
  say("Building {.pkg {pkg$package}} {pkg$version} into {.path {site_dir}}.")

  # Whatever the previous build put in public/ has to be cleaned up after this
  # one succeeds, and the previous manifest is the record of it.
  previous_stubs <- sd_read_stub_inventory(file.path(site_path, "public"))

  stage <- sd_new_stage(site_path)
  on.exit(sd_discard_stage(stage$root), add = TRUE)

  routes <- list()

  reference <- sd_build_reference(
    pkg, stage$content,
    examples = examples, run_dont_run = run_dont_run
  )
  routes <- c(routes, reference$topics, list(reference$index))
  say("Rendered {length(reference$topics)} reference topic{?s}.")

  if (isTRUE(articles)) {
    article_routes <- sd_build_articles(pkg, stage$content, lazy = lazy, quiet = quiet)
    routes <- c(routes, article_routes)
  }

  home <- sd_build_home(pkg, stage$content)
  routes <- c(routes, list(home))

  news <- sd_build_news(pkg, stage$content)
  if (!is.null(news)) {
    routes <- c(routes, list(news))
  }

  citation <- sd_build_citation(pkg)

  manifest <- sd_manifest(
    pkg, routes,
    news = news,
    citation = citation,
    theme = theme,
    quickstart = sd_quickstart(pkg)
  )
  stubs <- sd_write_redirects(manifest$redirects, routes, stage$public, pkg)

  sd_validate_stage(stage, routes, manifest, pkg, written_redirects = stubs$written)
  say("Validated {length(routes)} route{?s}.")

  sd_sync_theme_dependency(site_path, theme, quiet = quiet)
  sd_sync_machine_dir(site_path, theme)
  sd_commit_dir(stage$content, file.path(site_path, "src", "content", "docs"))
  sd_commit_public(stage$public, file.path(site_path, "public"), previous = previous_stubs)
  # Written last: a manifest describing pages that failed to commit would ship
  # a sidebar and index full of links to nothing.
  sd_write_manifest(manifest, sd_manifest_path(site_path))

  say("Committed {length(routes)} page{?s} and {length(stubs$written)} redirect{?s}.")

  if (isTRUE(npm_build)) {
    sd_npm(c("run", "build"), wd = site_path)
  }

  invisible(site_path)
}
