full_topics <- function() {
  sd_pkg(local_fixture_pkg("testpkg.full", env = parent.frame()))$topics
}

test_that("selectors resolve to topic names", {
  topics <- full_topics()
  select <- function(...) sd_select_topics(c(...), topics)

  expect_identical(select("full_add"), "full_add")
  # Literal names match aliases as well as topic names.
  expect_identical(select("full_plus"), "full_add")
  expect_identical(select("full_describe.default"), "full_describe")

  expect_identical(select('starts_with("full_c")'), "full_config")
  expect_identical(select('ends_with("_plot")'), "full_plot")
  expect_identical(select('contains("quot")'), "full_quotes")
  expect_identical(select('matches("^full_(add|plot)$")'), c("full_add", "full_plot"))
  expect_identical(select('has_concept("arithmetic")'), "full_add")
})

test_that("wildcard selectors skip internal topics but has_keyword() finds them", {
  topics <- full_topics()

  expect_false("full_internal" %in% sd_select_topics("everything()", topics))
  expect_false("full_internal" %in% sd_select_topics('starts_with("full_")', topics))
  expect_identical(
    sd_select_topics('has_keyword("internal")', topics),
    "full_internal"
  )
  # Naming an internal topic outright still selects it.
  expect_identical(sd_select_topics("full_internal", topics), "full_internal")
})

test_that("negation removes literals and selector matches", {
  topics <- full_topics()

  expect_identical(
    sd_select_topics(c('starts_with("full_")', "-full_add"), topics),
    c("full_config", "full_describe", "full_experimental", "full_plot", "full_quotes")
  )
  expect_identical(
    sd_select_topics(c('starts_with("full_")', '-starts_with("full_c")'), topics),
    c("full_add", "full_describe", "full_experimental", "full_plot", "full_quotes")
  )
  # Order follows the order of selection, not the order of the topic index.
  expect_identical(
    sd_select_topics(c("full_plot", "full_add"), topics),
    c("full_plot", "full_add")
  )
})

test_that("contents may be a yaml list and duplicates collapse", {
  topics <- full_topics()

  expect_identical(
    sd_select_topics(list("full_add", 'starts_with("full_a")'), topics),
    "full_add"
  )
  expect_identical(sd_select_topics(NULL, topics), character())
  expect_identical(sd_select_topics(character(), topics), character())
})

test_that("unmatched names and unsupported selectors warn", {
  topics <- full_topics()

  expect_warning(
    expect_identical(sd_select_topics(c("full_add", "nope", "nah"), topics), "full_add"),
    "nope"
  )
  expect_warning(sd_select_topics("lacks_concepts(\"x\")", topics), "unsupported")
  # Selector arguments must be string literals: nothing is ever evaluated.
  expect_warning(sd_select_topics("starts_with(stop('boom'))", topics), "unsupported")
  expect_warning(sd_select_topics("matches(1)", topics), "unsupported")
})

test_that("operator method names are topics, not selector syntax", {
  topics <- full_topics()

  # `+.fullclass` parses as a call to `+`; `-.foo` looks like a negation.
  expect_identical(sd_select_topics("+.fullclass", topics), "+.fullclass")
  expect_identical(
    sd_select_topics(c("everything()", "-+.fullclass"), topics),
    c(
      "full_add", "full_config", "full_describe", "full_experimental",
      "full_plot", "full_quotes"
    )
  )

  labels <- sd_topic_labels(topics)
  expect_true("+.fullclass" %in% labels)
  expect_identical(
    sd_parse_selector("+.fullclass", labels),
    list(kind = "literal", value = "+.fullclass", negate = FALSE)
  )
  expect_identical(
    sd_parse_selector("-.fullclass", c("-.fullclass", "x")),
    list(kind = "literal", value = "-.fullclass", negate = FALSE)
  )
})

test_that("an invalid matches() pattern aborts naming the pattern", {
  topics <- full_topics()
  expect_error(sd_select_topics('matches("[")', topics), "Invalid regular expression")
  expect_error(sd_select_topics('matches("[")', topics), "\\[")
})

test_that("selector parsing accepts only known calls with a single string", {
  expect_identical(
    sd_parse_selector('starts_with("x")'),
    list(kind = "starts_with", value = "x", negate = FALSE)
  )
  expect_identical(
    sd_parse_selector('- ends_with("x")'),
    list(kind = "ends_with", value = "x", negate = TRUE)
  )
  expect_identical(
    sd_parse_selector("everything()"),
    list(kind = "everything", value = NA_character_, negate = FALSE)
  )
  expect_identical(
    sd_parse_selector("some_topic"),
    list(kind = "literal", value = "some_topic", negate = FALSE)
  )
  expect_null(sd_parse_selector("system('rm -rf /')"))
  expect_null(sd_parse_selector('starts_with("a", "b")'))
})
