# Example execution ---------------------------------------------------------
#
# Examples are reconstructed from the Rd (so `\dontrun` / `\donttest` /
# `\dontshow` keep their meaning) and executed with evaluate() in a child of
# the package namespace, exactly as `example()` would. Output is emitted using
# the reserved fence info strings that the Starlight side renders as fused
# source/output cells.

sd_example_kinds <- c("code", "dontrun", "dontshow")

# pkgdown's seed, so a package documented with both tools shows the same
# numbers.
sd_example_seed <- 1014L

#' Split an `\examples` section into executable chunks
#'
#' @param x The `\examples` Rd fragment.
#' @param ctx Rendering context (used for non-code markup inside examples).
#' @return A list of `list(code, kind)` records in source order.
#' @noRd
sd_example_chunks <- function(x, ctx = sd_rd_ctx()) {
  code_ctx <- ctx
  code_ctx$verbatim <- TRUE
  code_ctx$in_code <- TRUE

  chunks <- list()

  add <- function(code, kind) {
    if (!nzchar(code)) {
      return(invisible())
    }
    n <- length(chunks)
    if (n && identical(chunks[[n]]$kind, kind)) {
      chunks[[n]]$code <<- paste0(chunks[[n]]$code, code)
    } else {
      chunks[[n + 1L]] <<- list(code = code, kind = kind)
    }
    invisible()
  }

  walk <- function(node, kind) {
    for (el in node) {
      tag <- attr(el, "Rd_tag")
      if (!is.null(tag) && tag %in% c("COMMENT", "USERMACRO")) {
        next
      }
      if (is.null(tag) || !grepl("^\\\\", tag)) {
        add(sd_cat0(el), kind)
        next
      }
      switch(sub("^\\\\", "", tag),
        dontrun = walk(el, "dontrun"),
        donttest = walk(el, kind),
        # \dontdiff only exempts output from R CMD check's diffing; the code
        # is ordinary and both runs and shows.
        dontdiff = walk(el, kind),
        dontshow = walk(el, "dontshow"),
        testonly = walk(el, "dontshow"),
        add(sd_rd_to_md(el, code_ctx), kind)
      )
    }
  }

  walk(x, "code")

  Filter(function(ch) nzchar(trimws(ch$code)), chunks)
}

#' Environment examples run in
#'
#' Mirrors `example()`: a child of the package namespace, so internal helpers
#' resolve the same way they do for the package's own code. Falls back to the
#' global environment when the package is not installed.
#' @noRd
sd_example_env <- function(ctx) {
  parent <- globalenv()
  if (sd_is_string(ctx$package)) {
    ns <- tryCatch(asNamespace(ctx$package), error = function(e) NULL)
    if (is.environment(ns)) {
      parent <- ns
    } else {
      sd_warn_once(
        ctx,
        "example-ns",
        c(
          "Package {.pkg {ctx$package}} is not installed; running examples in the global environment.",
          "i" = "Install the package first so examples see its namespace."
        )
      )
    }
  }
  new.env(parent = parent)
}

# evaluate() records plots off the device it opened, so an example calling a
# bare `dev.off()` (or `graphics.off()`) closes the recorder and every later
# figure in that topic vanishes without a warning. Masking both in the example
# environment keeps the last device alive while leaving the common
# `png(f); plot(); dev.off()` idiom working -- there the example's own device is
# the one that closes.
#' @noRd
sd_guard_devices <- function(env) {
  env$dev.off <- function(which = grDevices::dev.cur()) {
    if (length(grDevices::dev.list()) <= 1L) {
      return(invisible(grDevices::dev.cur()))
    }
    grDevices::dev.off(which)
  }
  env$graphics.off <- function(...) {
    while (length(grDevices::dev.list()) > 1L) {
      grDevices::dev.off()
    }
    invisible(NULL)
  }
  env
}

#' Run (or merely show) the examples of one topic
#'
#' @param examples_rd The `\examples` Rd fragment.
#' @param topic_slug Slug of the topic; figure files are named after it.
#' @param ctx Rendering context.
#' @param run_dont_run Execute `\dontrun{}` blocks too?
#' @param fig_dir Directory to write figures into.
#' @param execute Execute at all? When `FALSE` the code is shown, not run.
#' @return `list(markdown, figures, errors)`.
#' @noRd
sd_run_examples <- function(examples_rd,
                            topic_slug,
                            ctx,
                            run_dont_run = FALSE,
                            fig_dir = tempfile("sd-figures"),
                            execute = TRUE) {
  chunks <- sd_example_chunks(examples_rd, ctx)
  empty <- list(markdown = "", figures = character(), errors = character())
  if (!length(chunks)) {
    return(empty)
  }

  blocks <- character()
  figures <- character()
  errors <- character()
  state <- new.env(parent = emptyenv())
  state$figure_index <- 0L

  env <- NULL
  if (execute) {
    # Examples are arbitrary code: they call setwd(), set options, and write
    # files. Contain all three, or one topic's example silently changes how
    # every later topic renders -- and the build's own working directory.
    fig_dir <- as.character(fs::path_abs(fig_dir))
    fs::dir_create(fig_dir)

    scratch <- withr::local_tempdir("sd-examples")
    withr::local_dir(scratch)

    previous_options <- options()
    withr::defer(options(previous_options))

    # A fixed seed keeps a random example's output stable across builds.
    withr::local_seed(sd_example_seed)

    # evaluate() opens a device to record plots on; pin it to a null PDF at the
    # same aspect ratio as the PNGs we replay onto.
    withr::local_options(list(
      device = function(...) grDevices::pdf(file = NULL, width = 7, height = 5)
    ))

    env <- sd_guard_devices(sd_example_env(ctx))
  }

  for (chunk in chunks) {
    code <- sd_trim_code(chunk$code)
    if (!nzchar(code)) {
      next
    }

    shown <- chunk$kind != "dontshow"
    run <- execute && (chunk$kind != "dontrun" || run_dont_run)

    if (!run) {
      if (shown) {
        body <- if (chunk$kind == "dontrun") {
          paste0("# Not run:\n", code, "\n# End(Not run)")
        } else {
          code
        }
        blocks <- c(blocks, sd_code_fence(body, "r"))
      }
      next
    }

    results <- evaluate::evaluate(
      code,
      envir = env,
      new_device = TRUE,
      stop_on_error = 0L
    )

    errors <- c(errors, sd_eval_errors(results))
    if (!shown) {
      next
    }

    rendered <- sd_render_eval_results(results, topic_slug, fig_dir, state, ctx)
    blocks <- c(blocks, rendered$blocks)
    figures <- c(figures, rendered$figures)
  }

  list(
    markdown = paste0(blocks, collapse = "\n\n"),
    figures = figures,
    errors = errors
  )
}

#' @noRd
sd_trim_code <- function(x) {
  x <- gsub("\r\n", "\n", x, fixed = TRUE)
  x <- sub("^\n+", "", x)
  sub("[ \t\n]+$", "", x)
}

#' @noRd
sd_eval_errors <- function(results) {
  msgs <- vapply(
    Filter(function(r) inherits(r, "error"), results),
    conditionMessage,
    character(1)
  )
  as.character(msgs)
}

# Turn one evaluate() result list into fenced Markdown blocks. Consecutive
# statements that produce nothing are merged into a single source block, so the
# page reads as code interleaved with the output it produced.
#' @noRd
sd_render_eval_results <- function(results, topic_slug, fig_dir, state, ctx) {
  blocks <- character()
  figures <- character()
  pending <- character()

  flush <- function() {
    src <- sd_trim_code(sd_cat0(pending))
    pending <<- character()
    if (nzchar(src)) {
      blocks <<- c(blocks, sd_code_fence(src, "r"))
    }
  }

  for (r in results) {
    if (inherits(r, "source")) {
      pending <- c(pending, r$src)
      next
    }
    flush()

    if (inherits(r, "recordedplot")) {
      state$figure_index <- state$figure_index + 1L
      name <- paste0(topic_slug, "-", state$figure_index, ".png")
      path <- file.path(fig_dir, name)
      if (sd_write_plot(r, path, ctx)) {
        blocks <- c(blocks, paste0("![](figures/", name, ")"))
        figures <- c(figures, path)
      } else {
        state$figure_index <- state$figure_index - 1L
      }
      next
    }

    if (is.character(r)) {
      text <- sub("\n$", "", gsub("\r\n", "\n", sd_cat0(r), fixed = TRUE))
      if (nzchar(text)) {
        blocks <- c(blocks, sd_code_fence(text, "r-output"))
      }
      next
    }

    if (inherits(r, "error")) {
      blocks <- c(blocks, sd_code_fence(sd_format_condition(r, "Error"), "r-error"))
    } else if (inherits(r, "warning")) {
      blocks <- c(blocks, sd_code_fence(sd_format_condition(r, "Warning"), "r-warning"))
    } else if (inherits(r, "condition")) {
      msg <- sub("\n$", "", conditionMessage(r))
      blocks <- c(blocks, sd_code_fence(msg, "r-message"))
    }
  }
  flush()

  list(blocks = blocks, figures = figures)
}

#' @noRd
sd_format_condition <- function(cond, label) {
  msg <- sub("\n$", "", conditionMessage(cond))
  call <- conditionCall(cond)
  if (is.null(call)) {
    paste0(label, ": ", msg)
  } else {
    paste0(label, " in ", paste0(deparse(call), collapse = " "), ": ", msg)
  }
}

#' @noRd
sd_write_plot <- function(plot, path, ctx) {
  opened <- FALSE
  ok <- tryCatch(
    {
      sd_open_png(path)
      opened <- TRUE
      grDevices::replayPlot(plot)
      TRUE
    },
    error = function(e) {
      sd_warn_once(
        ctx,
        "figure-replay",
        "Failed to write an example figure: {conditionMessage(e)}"
      )
      FALSE
    }
  )
  # The file is only complete once the device closes, so close before deciding
  # whether the figure exists.
  if (opened) {
    try(grDevices::dev.off(), silent = TRUE)
  }
  isTRUE(ok) && file.exists(path)
}

#' @noRd
sd_open_png <- function(path) {
  if (requireNamespace("ragg", quietly = TRUE)) {
    ragg::agg_png(path, width = 7, height = 5, units = "in", res = 192)
  } else {
    grDevices::png(path, width = 7, height = 5, units = "in", res = 192)
  }
}
