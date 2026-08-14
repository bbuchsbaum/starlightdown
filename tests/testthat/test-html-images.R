test_that("Quarto's raw <img> becomes a Markdown image", {
  # Quarto emits raw HTML for any chunk with fig-align or out.width. Astro
  # only routes Markdown images through its asset pipeline, so a raw tag ships
  # a 404 on an otherwise correct page.
  body <- paste0(
    '<img src="getting-started_files/figure-commonmark/plot-1.png" ',
    'style="width:100.0%" data-fig-align="center" />'
  )
  expect_identical(
    sd_html_images_to_markdown(body),
    "![](getting-started_files/figure-commonmark/plot-1.png)"
  )
})

test_that("alt text survives the conversion", {
  expect_identical(
    sd_html_images_to_markdown('<img src="man/figures/logo.png" alt="The logo">'),
    "![The logo](man/figures/logo.png)"
  )
})

test_that("sources that already resolve are left alone", {
  # Absolute, protocol-relative and root-absolute sources need no help; a
  # root-absolute one is already a public/ asset.
  for (src in c(
    "https://example.org/a.png",
    "//example.org/a.png",
    "/albersdown/logo.png"
  )) {
    tag <- paste0('<img src="', src, '">')
    expect_identical(sd_html_images_to_markdown(tag), tag)
  }
})

test_that("an <img> inside a code fence is documentation, not a figure", {
  # The old codebase's defining bug was rewriting code samples. A package
  # documenting HTML must keep its examples verbatim.
  body <- paste0(
    "Use an image tag:\n\n",
    "```html\n",
    '<img src="logo.png" alt="Logo">\n',
    "```\n"
  )
  expect_identical(sd_html_images_to_markdown(body), body)
  expect_identical(sd_unemittable_images(body), character())
})

test_that("multiple figures on one page all convert", {
  body <- paste0(
    '<img src="a/one.png" />\n\ntext\n\n<img src="a/two.png" alt="Two" />\n'
  )
  converted <- sd_html_images_to_markdown(body)
  expect_match(converted, "![](a/one.png)", fixed = TRUE)
  expect_match(converted, "![Two](a/two.png)", fixed = TRUE)
  expect_no_match(converted, "<img", fixed = TRUE)
})

test_that("sd_unemittable_images() finds what would silently 404", {
  expect_identical(
    sd_unemittable_images('<img src="figures/plot-1.png">'),
    "figures/plot-1.png"
  )
  expect_identical(sd_unemittable_images('<img src="/public/ok.png">'), character())
  expect_identical(sd_unemittable_images("![fine](figures/plot-1.png)"), character())
})

test_that("the validator refuses to ship an unemittable image", {
  content <- withr::local_tempdir()
  writeLines(
    c("---", "title: Broken", "---", "", '<img src="figures/plot-1.png">'),
    file.path(content, "page.md")
  )
  dir.create(file.path(content, "figures"))
  file.create(file.path(content, "figures", "plot-1.png"))

  problems <- sd_check_emittable_images(content)
  expect_length(problems, 1L)
  expect_match(problems, "would not be emitted", fixed = TRUE)

  # The file exists next to the page, so the on-disk check alone passes: that
  # is exactly why this gate is separate.
  expect_length(sd_check_relative_targets(content), 0L)
})
