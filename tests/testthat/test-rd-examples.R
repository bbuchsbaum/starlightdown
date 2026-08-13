example_rd <- function(lines, env = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".Rd", .local_envir = env)
  writeLines(
    c("\\name{tmp}", "\\alias{tmp}", "\\title{Temp}", "\\examples{", lines, "}"),
    path
  )
  sd_rd_sections(sd_rd_parse(path))$examples
}

# No package name, so examples evaluate in a child of the global environment
# and nothing needs installing.
bare_ctx <- function() sd_rd_ctx(base = "/")

test_that("example chunks preserve dontrun / donttest / dontshow", {
  chunks <- sd_example_chunks(example_rd(c(
    "shown_and_run <- 1",
    "\\dontrun{never_run()}",
    "\\donttest{also_run <- 2}",
    "\\dontshow{hidden <- 3}",
    "back_to_normal <- 4"
  )))

  expect_identical(
    vapply(chunks, function(x) x$kind, character(1)),
    c("code", "dontrun", "code", "dontshow", "code")
  )
  expect_match(chunks[[2L]]$code, "never_run()", fixed = TRUE)
  # \donttest is ordinary code, so it merges with what follows it.
  expect_match(chunks[[3L]]$code, "also_run <- 2", fixed = TRUE)
})

test_that("running examples emits the source/output fence contract", {
  out <- sd_run_examples(
    example_rd(c("1 + 1", "x <- 41", "x + 1")),
    topic_slug = "topic",
    ctx = bare_ctx()
  )

  expect_snapshot(cat(out$markdown))
  expect_identical(out$figures, character())
  expect_identical(out$errors, character())
})

test_that("messages, warnings and errors get their own fences", {
  out <- sd_run_examples(
    example_rd(c(
      'message("a message")',
      'warning("a warning")',
      'stop("an error")',
      '"still evaluated"'
    )),
    topic_slug = "topic",
    ctx = bare_ctx()
  )

  expect_snapshot(cat(out$markdown))
  expect_identical(out$errors, "an error")
})

test_that("dontrun is shown but not run, dontshow is run but not shown", {
  env_probe <- new.env()
  out <- sd_run_examples(
    example_rd(c(
      "1 + 1",
      '\\dontrun{stop("this must never run")}',
      "\\dontshow{invisible(NULL)}"
    )),
    topic_slug = "topic",
    ctx = bare_ctx()
  )

  expect_snapshot(cat(out$markdown))
  expect_identical(out$errors, character())
  expect_false(grepl("invisible(NULL)", out$markdown, fixed = TRUE))
})

test_that("run_dont_run executes the dontrun block", {
  out <- sd_run_examples(
    example_rd('\\dontrun{message("now it runs")}'),
    topic_slug = "topic",
    ctx = bare_ctx(),
    run_dont_run = TRUE
  )

  expect_match(out$markdown, "r-message", fixed = TRUE)
  expect_match(out$markdown, "now it runs", fixed = TRUE)
})

test_that("execute = FALSE shows the code without running it", {
  out <- sd_run_examples(
    example_rd(c("1 + 1", 'stop("must not run")')),
    topic_slug = "topic",
    ctx = bare_ctx(),
    execute = FALSE
  )

  expect_snapshot(cat(out$markdown))
  expect_identical(out$errors, character())
})

test_that("examples cannot leak state into the build", {
  before_wd <- getwd()
  before_digits <- getOption("digits")

  out <- sd_run_examples(
    example_rd(c(
      'options(digits = 3)',
      'setwd(tempdir())',
      'writeLines("x", "example-side-effect.txt")'
    )),
    topic_slug = "topic",
    ctx = bare_ctx()
  )

  expect_identical(getwd(), before_wd)
  expect_identical(getOption("digits"), before_digits)
  expect_false(file.exists(file.path(before_wd, "example-side-effect.txt")))
  expect_identical(out$errors, character())
})

test_that("random examples render identically on consecutive builds", {
  run <- function() {
    sd_run_examples(
      example_rd("round(runif(3), 4)"),
      topic_slug = "topic",
      ctx = bare_ctx()
    )$markdown
  }
  first <- run()
  expect_identical(run(), first)
  expect_match(first, "r-output", fixed = TRUE)
})

test_that("an example closing the device does not lose later figures", {
  fig_dir <- withr::local_tempdir()
  out <- sd_run_examples(
    example_rd(c("plot(1:3)", "dev.off()", "plot(4:6)")),
    topic_slug = "guarded",
    ctx = bare_ctx(),
    fig_dir = fig_dir
  )

  expect_length(out$figures, 2L)
  expect_true(all(file.exists(out$figures)))
})

test_that("an example opening its own device still closes it", {
  fig_dir <- withr::local_tempdir()
  target <- file.path(withr::local_tempdir(), "written-by-example.png")
  out <- sd_run_examples(
    example_rd(c(
      sprintf('grDevices::png("%s")', target),
      "plot(1:3)",
      "dev.off()",
      "plot(7:9)"
    )),
    topic_slug = "own-device",
    ctx = bare_ctx(),
    fig_dir = fig_dir
  )

  expect_true(file.exists(target))
  # Only the plot drawn on the recording device becomes a page figure.
  expect_length(out$figures, 1L)
})

test_that("plots are written to the figure directory and referenced", {
  fig_dir <- withr::local_tempdir()
  out <- sd_run_examples(
    example_rd(c("plot(1:10)", 'plot(1:5, main = "second")')),
    topic_slug = "my-topic",
    ctx = bare_ctx(),
    fig_dir = fig_dir
  )

  expect_length(out$figures, 2L)
  expect_true(all(file.exists(out$figures)))
  expect_true(all(file.size(out$figures) > 1000))
  expect_identical(
    basename(out$figures),
    c("my-topic-1.png", "my-topic-2.png")
  )
  expect_match(out$markdown, "![](figures/my-topic-1.png)", fixed = TRUE)
  expect_match(out$markdown, "![](figures/my-topic-2.png)", fixed = TRUE)
})
