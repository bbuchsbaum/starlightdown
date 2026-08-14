test_that("a GitHub alert becomes a Starlight aside", {
  body <- "> [!NOTE]\n>\n> Neutral guidance.\n"
  expect_identical(
    sd_alerts_to_asides(body),
    ":::note\nNeutral guidance.\n:::\n"
  )
})

test_that("every alert type maps onto an aside Starlight renders", {
  asides <- c(
    NOTE = "note", TIP = "tip", IMPORTANT = "note",
    WARNING = "caution", CAUTION = "danger"
  )
  for (type in names(asides)) {
    converted <- sd_alerts_to_asides(paste0("> [!", type, "]\n> Body.\n"))
    expect_match(converted, paste0(":::", asides[[type]]), fixed = TRUE)
    expect_no_match(converted, "[!", fixed = TRUE)
  }
})

test_that("an unnameable alert keeps its words instead of shipping the marker", {
  # Quarto writes `[!NONE]` for a callout class it does not recognise. That is
  # not alert syntax, so it reached readers as literal text.
  converted <- sd_alerts_to_asides("> [!NONE]\n>\n> Use callout-insight here.\n")
  expect_no_match(converted, "NONE", fixed = TRUE)
  expect_match(converted, "Use callout-insight here.", fixed = TRUE)
})

test_that("consecutive callouts stay separate", {
  body <- paste0(
    "> [!NOTE]\n>\n> First.\n\n",
    "> [!WARNING]\n>\n> Second.\n"
  )
  converted <- sd_alerts_to_asides(body)
  expect_match(converted, ":::note\nFirst.\n:::", fixed = TRUE)
  expect_match(converted, ":::caution\nSecond.\n:::", fixed = TRUE)
})

test_that("multi-line and multi-paragraph alert bodies survive", {
  body <- "> [!TIP]\n> One.\n>\n> Two.\n"
  converted <- sd_alerts_to_asides(body)
  expect_match(converted, "One.", fixed = TRUE)
  expect_match(converted, "Two.", fixed = TRUE)
  expect_true(startsWith(converted, ":::tip"))
  expect_true(endsWith(trimws(converted), ":::"))
})

test_that("an alert inside a code fence is documentation, not a callout", {
  body <- "Write:\n\n```markdown\n> [!NOTE]\n> Body.\n```\n"
  expect_identical(sd_alerts_to_asides(body), body)
  expect_identical(sd_unrenderable_alerts(body), character())
})

test_that("an ordinary blockquote is left alone", {
  body <- "> Just a quotation.\n"
  expect_identical(sd_alerts_to_asides(body), "> Just a quotation.\n")
})

test_that("the validator refuses to ship an unrendered alert marker", {
  content <- withr::local_tempdir()
  writeLines(
    c("---", "title: Broken", "---", "", "> [!NONE]", "> Body."),
    file.path(content, "page.md")
  )
  problems <- sd_check_rendered_alerts(content)
  expect_length(problems, 1L)
  expect_match(problems, "literal text", fixed = TRUE)
})
