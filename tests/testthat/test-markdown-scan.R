# The scanner exists because the old codebase read raw Markdown with regex and
# rewrote its own code samples. Every case here is one of those.

test_that("fenced code is not scanned for targets", {
  doc <- paste(
    "Real [link](/reference/x/).", "",
    "```markdown", "![img](nope.png)", "[a](/not/a/route/)", "```", "",
    "~~~", "[c](/tilde/fence/)", "~~~",
    sep = "\n"
  )

  expect_false("nope.png" %in% sd_relative_targets(doc))
  expect_false("/not/a/route/" %in% sd_root_link_targets(doc))
  expect_false("/tilde/fence/" %in% sd_root_link_targets(doc))
  expect_true("/reference/x/" %in% sd_root_link_targets(doc))
})

test_that("inline code spans are not scanned for targets", {
  doc <- "Write `[b](/also/not/)` like this, then [real](/yes/)."
  expect_setequal(sd_root_link_targets(doc), "/yes/")
})

test_that("fenced samples survive base rewriting verbatim", {
  # A package documenting Markdown must not have its examples mangled.
  doc <- paste(
    "See [here](/reference/x/).", "",
    "```markdown", "[a](/not/a/route/)", "```", "",
    "And `[b](/nor/this/)`.",
    sep = "\n"
  )
  out <- sd_apply_base_to_links(doc, "/pkg")

  expect_match(out, "[here](/pkg/reference/x/)", fixed = TRUE)
  expect_match(out, "[a](/not/a/route/)", fixed = TRUE)
  expect_match(out, "`[b](/nor/this/)`", fixed = TRUE)
})

test_that("images keep their relative paths through a base rewrite", {
  doc <- "![fig](figures/a.png) and [link](/reference/)"
  out <- sd_apply_base_to_links(doc, "/pkg")

  expect_match(out, "![fig](figures/a.png)", fixed = TRUE)
  expect_match(out, "[link](/pkg/reference/)", fixed = TRUE)
})

test_that("image titles, angle brackets and encoding are all parsed", {
  doc <- paste(
    '![M](man/figures/mark.svg "The mark")',
    "![T](tools/logo.png)",
    "![S](<my dir/with space.png>)",
    "![E](my%20logo.png)",
    sep = "\n"
  )
  expect_setequal(
    sd_relative_targets(doc),
    c("man/figures/mark.svg", "tools/logo.png", "my dir/with space.png", "my logo.png")
  )
})

test_that("reference definitions and raw HTML are seen and rewritten", {
  doc <- paste(
    "See [x][ri] and [y][rn].", "",
    "[ri]: /reference/", "[rn]: /news/", "",
    '<a href="/articles/intro/">intro</a>',
    '<img src="figures/a.png">',
    sep = "\n"
  )

  expect_setequal(
    sd_root_link_targets(doc),
    c("/reference/", "/news/", "/articles/intro/")
  )
  expect_true("figures/a.png" %in% sd_relative_targets(doc))

  out <- sd_apply_base_to_links(doc, "/pkg")
  expect_match(out, "[ri]: /pkg/reference/", fixed = TRUE)
  expect_match(out, 'href="/pkg/articles/intro/"', fixed = TRUE)
  # An <img> is an image: it stays relative.
  expect_match(out, 'src="figures/a.png"', fixed = TRUE)
})

test_that("an already-based or external link is left alone", {
  doc <- paste(
    "[a](/pkg/already/)", "[b](https://example.com/x)", "[c](//cdn.example/x)",
    "[d](#anchor)", "[e](relative/path)",
    sep = "\n"
  )
  expect_identical(sd_apply_base_to_links(doc, "/pkg"), doc)
  expect_identical(sd_apply_base_to_links(doc, "/"), doc)
})

test_that("a base containing regex metacharacters is handled literally", {
  doc <- "[a](/reference/x/)"
  expect_identical(
    sd_apply_base_to_links(doc, "/testpkg.full"),
    "[a](/testpkg.full/reference/x/)"
  )
  expect_identical(
    sd_apply_base_to_links("[a](/testpkg.full/reference/x/)", "/testpkg.full"),
    "[a](/testpkg.full/reference/x/)"
  )
})

test_that("HTML comments are not prose", {
  view <- sd_md_view("<!--\n# not a heading\n-->\n# real heading")
  lines <- strsplit(view, "\n", fixed = TRUE)[[1L]]
  expect_false(any(grepl("^# not", lines)))
  expect_true(any(grepl("^# real", lines)))
})

test_that("setext headings are normalised before stripping", {
  expect_match(sd_normalise_setext("Title\n=====\n\nBody."), "^# Title", perl = TRUE)
  expect_match(sd_normalise_setext("Section\n-------\n\nBody."), "^## Section", perl = TRUE)
  # A document with no setext heading comes back untouched, newline and all.
  expect_identical(sd_normalise_setext("# Already\n\nBody.\n"), "# Already\n\nBody.\n")
  # A rule inside code is not a heading.
  expect_identical(
    sd_normalise_setext("```\nx\n===\n```\n"),
    "```\nx\n===\n```\n"
  )
})
