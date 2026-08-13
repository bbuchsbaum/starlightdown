test_that("sd_pkg() synthesises a default model when there is no _pkgdown.yml", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.minimal"))

  expect_s3_class(pkg, "sd_pkg")
  expect_identical(pkg$package, "testpkg.minimal")
  expect_identical(pkg$version, "0.1.0")
  expect_true(is.na(pkg$site_url))
  expect_identical(pkg$base, "/")

  expect_length(pkg$meta$reference, 1L)
  expect_identical(pkg$meta$reference[[1L]]$title, "All functions")
  expect_identical(
    unlist(pkg$meta$reference[[1L]]$contents),
    c("add_one", "times_two")
  )
  expect_identical(pkg$meta$articles, list())
})

test_that("sd_pkg() keeps the _pkgdown.yml reference model", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.full"))

  expect_identical(pkg$package, "testpkg.full")
  expect_length(pkg$meta$reference, 2L)
  expect_identical(pkg$meta$reference[[1L]]$title, "Core, one's favourites")
  expect_identical(pkg$meta$articles[[1L]]$title, "Guides")

  # The contract splits the docs URL into an origin and a base.
  expect_identical(pkg$site_url, "https://testuser.github.io")
  expect_identical(pkg$base, "/testpkg.full")

  expect_setequal(
    pkg$topics$name,
    c(
      "full_add", "full_config", "full_describe", "full_experimental",
      "full_internal", "+.fullclass", "full_plot", "full_quotes"
    )
  )
  expect_true(pkg$topics$internal[pkg$topics$name == "full_internal"])
})

fake_desc <- function(urls, bugs = NA_character_) {
  list(
    get_urls = function() urls,
    get_field = function(key, default = NULL) if (key == "BugReports") bugs else default
  )
}

test_that("the site URL prefers _pkgdown.yml, then DESCRIPTION, never the bug tracker", {
  expect_identical(
    sd_site_url(list(url = "https://example.com/pkg/"), fake_desc(character())),
    "https://example.com/pkg"
  )
  expect_identical(
    sd_site_url(
      list(),
      fake_desc(
        c("https://github.com/u/p/issues", "https://u.github.io/p"),
        "https://github.com/u/p/issues"
      )
    ),
    "https://u.github.io/p"
  )
  expect_true(is.na(sd_site_url(list(), fake_desc(character()))))
})

test_that("a repository or registry URL is never mistaken for the docs site", {
  # Otherwise the base becomes /user/repo and every prose link points nowhere.
  expect_true(is.na(sd_site_url(list(), fake_desc("https://github.com/u/p"))))
  expect_true(is.na(sd_site_url(list(), fake_desc("https://gitlab.com/g/s/p"))))
  expect_true(is.na(sd_site_url(list(), fake_desc("https://codeberg.org/u/p"))))
  expect_true(
    is.na(sd_site_url(list(), fake_desc("https://cran.r-project.org/package=p")))
  )

  # Hosts that do serve documentation still work, custom domains included.
  expect_identical(
    sd_site_url(list(), fake_desc(c("https://github.com/u/p", "https://u.github.io/p"))),
    "https://u.github.io/p"
  )
  expect_identical(
    sd_site_url(list(), fake_desc("https://u.r-universe.dev/p")),
    "https://u.r-universe.dev/p"
  )
  expect_identical(
    sd_site_url(list(), fake_desc("https://docs.example.com/p")),
    "https://docs.example.com/p"
  )

  # An explicit _pkgdown.yml url is a declaration, not a guess: honour it.
  expect_identical(
    sd_site_url(list(url = "https://github.com/u/p"), fake_desc(character())),
    "https://github.com/u/p"
  )
})

test_that("the site URL splits into an origin and a base path", {
  expect_identical(sd_site_origin("https://user.github.io/pkg"), "https://user.github.io")
  expect_identical(sd_site_origin("https://docs.example.com"), "https://docs.example.com")
  expect_true(is.na(sd_site_origin(NA_character_)))

  expect_identical(sd_base_path("https://user.github.io/pkg"), "/pkg")
  expect_identical(sd_base_path("https://user.github.io/pkg/"), "/pkg")
  expect_identical(sd_base_path("https://user.github.io"), "/")
  expect_identical(sd_base_path("https://docs.example.com"), "/")
  expect_identical(sd_base_path(NA_character_), "/")
})

test_that("the alias map covers every alias of every topic", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.full"))
  aliases <- sd_alias_map(pkg$topics)

  expect_identical(aliases[["full_plus"]], "full_add")
  expect_identical(aliases[["full_describe.default"]], "full_describe")
  expect_true("full_internal" %in% names(aliases))
})
