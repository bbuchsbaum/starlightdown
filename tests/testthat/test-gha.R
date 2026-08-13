test_that("the workflow substitutes every placeholder", {
  pkg <- local_fixture_pkg()
  dest <- use_starlight_github_actions(path = pkg)

  yml <- paste(readLines(dest, warn = FALSE), collapse = "\n")
  # Ours are `{{NAME}}`; GitHub's own `${{ ... }}` expressions must survive.
  expect_no_match(yml, "(?<!\\$)\\{\\{[A-Z_]+\\}\\}", perl = TRUE)
  expect_match(yml, "${{ secrets.GITHUB_TOKEN }}", fixed = TRUE)
  expect_match(yml, "branches: [main]", fixed = TRUE)
  expect_match(yml, "path: starlight/dist", fixed = TRUE)
  expect_match(yml, "starlightdown::build_site()", fixed = TRUE)
})

test_that("a custom site_dir is substituted everywhere the site is named", {
  # A workflow that builds one directory and publishes another is worse than
  # no workflow: it deploys a stale site and reports success.
  pkg <- local_fixture_pkg()
  dest <- use_starlight_github_actions(path = pkg, site_dir = "docs-site")

  lines <- readLines(dest, warn = FALSE)
  expect_false(any(grepl("starlight/", lines, fixed = TRUE)))

  yml <- paste(lines, collapse = "\n")
  expect_match(yml, "npm ci --prefix docs-site", fixed = TRUE)
  expect_match(yml, "npm run build --prefix docs-site", fixed = TRUE)
  expect_match(yml, "cache-dependency-path: docs-site/package-lock.json", fixed = TRUE)
  expect_match(yml, "path: docs-site/dist", fixed = TRUE)
  expect_match(yml, "docs-site/package-lock.json is missing", fixed = TRUE)
  # The build step has to target the same directory the Node steps use.
  expect_match(yml, 'build_site(site_dir = "docs-site")', fixed = TRUE)
})

test_that("use_starlight_github_actions() refuses to clobber a workflow", {
  pkg <- local_fixture_pkg()
  use_starlight_github_actions(path = pkg)

  expect_error(use_starlight_github_actions(path = pkg), "already exists")
  expect_no_error(use_starlight_github_actions(path = pkg, overwrite = TRUE))
})

test_that("the workflow deploys the same branch it is triggered on", {
  pkg <- local_fixture_pkg()
  dest <- use_starlight_github_actions(path = pkg, branch = "trunk")
  expect_match(
    paste(readLines(dest, warn = FALSE), collapse = "\n"),
    "branches: [trunk]",
    fixed = TRUE
  )
})
