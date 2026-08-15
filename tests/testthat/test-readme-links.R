test_that("only images are relocated, never links to repository files", {
  # A README linking to NEWS.md had that file copied into figures/ as though
  # it were an image, producing a page with no route and aborting the build.
  pkg <- local_fixture_pkg()
  writeLines(
    c(
      "# testpkg.minimal", "",
      "See the [changelog](NEWS.md) and the [readme](README.md).", "",
      "![A figure](man/figures/mark.svg)"
    ),
    file.path(pkg, "README.md")
  )
  writeLines("# testpkg.minimal 0.1.0", file.path(pkg, "NEWS.md"))
  dir.create(file.path(pkg, "man", "figures"), recursive = TRUE, showWarnings = FALSE)
  writeLines("<svg xmlns='http://www.w3.org/2000/svg'></svg>", file.path(pkg, "man/figures/mark.svg"))

  stage <- withr::local_tempdir()
  moved <- sd_relocate_local_images(sd_read_utf8(file.path(pkg, "README.md")), sd_pkg(pkg), stage)

  expect_identical(moved$assets, "figures/mark.svg")
  expect_true(file.exists(file.path(stage, "figures", "mark.svg")))
  expect_false(file.exists(file.path(stage, "figures", "NEWS.md")))
  expect_false(file.exists(file.path(stage, "figures", "README.md")))
})

test_that("README links to published sources become links to their pages", {
  pkg <- local_fixture_pkg()
  model <- sd_pkg(pkg)

  expect_identical(sd_readme_route("NEWS.md", model), "/news/")
  expect_identical(sd_readme_route("./NEWS.md", model), "/news/")
  expect_identical(sd_readme_route("vignettes/intro.Rmd", model), "/articles/intro/")
  expect_identical(sd_readme_route("vignettes/intro.qmd", model), "/articles/intro/")
  expect_true(is.na(sd_readme_route("CONTRIBUTING.md", model)))
})

test_that("a link to an unpublished repository file points into the repository", {
  pkg <- local_fixture_pkg()
  desc::desc_set(URL = "https://github.com/owner/repo", file = file.path(pkg, "DESCRIPTION"))
  writeLines("Contributions welcome.", file.path(pkg, "CONTRIBUTING.md"))
  model <- sd_pkg(pkg)

  resolved <- sd_resolve_readme_links("See [how to help](CONTRIBUTING.md).", model)
  expect_identical(
    resolved,
    "See [how to help](https://github.com/owner/repo/blob/HEAD/CONTRIBUTING.md)."
  )
})

test_that("anchors survive link resolution", {
  pkg <- local_fixture_pkg()
  writeLines("# testpkg.minimal 0.1.0", file.path(pkg, "NEWS.md"))
  model <- sd_pkg(pkg)

  expect_identical(
    sd_resolve_readme_links("[latest](NEWS.md#testpkg-minimal-010)", model),
    "[latest](/news/#testpkg-minimal-010)"
  )
})

test_that("external links and images are left alone", {
  pkg <- local_fixture_pkg()
  model <- sd_pkg(pkg)
  body <- "[Astro](https://astro.build/) and ![badge](https://img.shields.io/x.svg)"
  expect_identical(sd_resolve_readme_links(body, model), body)
})
