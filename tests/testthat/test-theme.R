meta_pkg <- function(...) list(meta = list(starlightdown = list(...)))

test_that("the theme defaults to the bundled one and accepts its old name", {
  expect_identical(sd_site_theme(meta_pkg(), NULL), "default")
  expect_identical(sd_site_theme(meta_pkg(), "editorial-scientific"), "default")
  expect_identical(sd_site_theme(meta_pkg(), "DEFAULT"), "default")
})

test_that("_pkgdown.yml can select the theme, and an argument overrides it", {
  expect_identical(sd_site_theme(meta_pkg(theme = "nova"), NULL), "nova")
  expect_identical(sd_site_theme(meta_pkg(theme = "nova"), "default"), "default")
})

test_that("ion is refused with the reason, and unknown themes are refused", {
  # starlight-ion-theme@2.4.0 peers on astro ^6 / starlight ^0.38; this
  # frontend needs Astro 7 / Starlight 0.41.
  expect_error(sd_site_theme(meta_pkg(), "ion"), "cannot be used yet")
  expect_error(sd_site_theme(meta_pkg(), "ion"), "Astro 7")
  expect_error(sd_site_theme(meta_pkg(), "dracula"), "Unknown theme")
  expect_error(sd_site_theme(meta_pkg(), "dracula"), "default")
})

test_that("the generated config passes the theme to the plugin", {
  machine <- withr::local_tempdir()
  sd_write_astro_config(machine, "default")
  config <- sd_read_utf8(file.path(machine, "config.mjs"))

  expect_match(
    config,
    "plugins: [starlightdown({ manifest, theme: manifest.site.theme })]",
    fixed = TRUE
  )
  expect_no_match(config, "starlight-theme", fixed = TRUE)
  expect_match(config, "readFileSync(new URL('./site.json'", fixed = TRUE)
})

test_that("a preset is imported and registered before starlightdown", {
  # Starlight applies plugins in order; a preset after starlightdown would
  # overwrite the same override slots outright (CONTRACT.md §11).
  machine <- withr::local_tempdir()
  sd_write_astro_config(machine, "nova")
  config <- sd_read_utf8(file.path(machine, "config.mjs"))

  expect_match(config, "import starlightThemeNova from 'starlight-theme-nova';", fixed = TRUE)
  expect_match(
    config,
    "plugins: [starlightThemeNova(), starlightdown({ manifest, theme: manifest.site.theme })]",
    fixed = TRUE
  )
  expect_lt(
    regexpr("starlightThemeNova()", config, fixed = TRUE),
    regexpr("starlightdown({ manifest", config, fixed = TRUE)
  )
})

test_that("selecting a preset adds its npm dependency, and dropping it removes it", {
  site <- withr::local_tempdir()
  jsonlite::write_json(
    list(name = "docs", dependencies = list(astro = "7.2.1")),
    file.path(site, "package.json"),
    auto_unbox = TRUE
  )
  # There is no lockfile here, so nothing calls npm.
  sd_sync_theme_dependency(site, "nova", quiet = TRUE)

  deps <- jsonlite::read_json(file.path(site, "package.json"))$dependencies
  expect_identical(deps$`starlight-theme-nova`, "0.12.2")
  expect_identical(deps$astro, "7.2.1")

  sd_sync_theme_dependency(site, "default", quiet = TRUE)
  deps <- jsonlite::read_json(file.path(site, "package.json"))$dependencies
  expect_null(deps$`starlight-theme-nova`)
  expect_identical(deps$astro, "7.2.1")
})

test_that("the manifest carries the resolved theme", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.full"))
  manifest <- sd_manifest(pkg, fake_routes(), theme = "nova")
  expect_identical(manifest$site$theme, "nova")

  manifest <- sd_manifest(pkg, fake_routes())
  expect_identical(manifest$site$theme, "default")
})

# Quickstart -----------------------------------------------------------------

test_that("the quickstart comes from the README's first post-install chunk", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.full"))
  expect_identical(
    sd_quickstart(pkg),
    "library(testpkg.full)\nfull_add(1, 2)"
  )
})

test_that("an explicit _pkgdown.yml quickstart wins", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.full"))
  pkg$meta$starlightdown <- list(quickstart = "full_plot(3)")
  expect_identical(sd_quickstart(pkg), "full_plot(3)")
})

test_that("an install-only README yields no quickstart", {
  # Better nothing than a code block telling the reader to install again.
  lines <- c("# pkg", "", "## Installation", "", "```r", "install.packages(\"pkg\")", "```")
  expect_null(sd_readme_quickstart(lines))
})

test_that("a README with no install section still offers its first chunk", {
  lines <- c("# pkg", "", "```r", "library(pkg)", "do_thing()", "```")
  expect_identical(sd_readme_quickstart(lines), "library(pkg)\ndo_thing()")
})

test_that("the quickstart is null in the manifest when there is none", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.minimal"))
  manifest <- sd_manifest(pkg, fake_routes(), quickstart = sd_quickstart(pkg))
  expect_null(manifest$quickstart)
})

# Release dates ---------------------------------------------------------------

test_that("a dated release heading carries a machine-readable time element", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.full"))
  stage <- withr::local_tempdir()
  news <- sd_build_news(pkg, stage)
  body <- read_body(file.path(stage, "news.md"))

  expect_match(
    body,
    "## testpkg.full 0.2.1 <time datetime=\"2026-08-13\">2026-08-13</time>",
    fixed = TRUE
  )
  # The undated release is left alone.
  expect_match(body, "## testpkg.full 0.2.0", fixed = TRUE)
  expect_identical(news$versions[[1L]]$date, "2026-08-13")
  expect_null(news$versions[[2L]]$date)
})

test_that("a release date is never mistaken for the version", {
  expect_identical(sd_extract_version("pkg 1.2.0 (2026-08-01)"), "1.2.0")
  expect_identical(sd_extract_version("pkg 1.2.0 2026-08-01"), "1.2.0")
  expect_identical(sd_extract_date("pkg 1.2.0 (2026-08-01)"), "2026-08-01")
  expect_null(sd_extract_date("pkg 1.2.0"))
})
