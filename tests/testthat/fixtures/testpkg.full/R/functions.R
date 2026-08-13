full_add <- function(x, y = 1) {
  x + y
}

full_describe <- function(x, ...) {
  UseMethod("full_describe")
}

full_describe.default <- function(x, ...) {
  paste0("<", class(x)[[1L]], " of length ", length(x), ">")
}

full_config <- function(...) {
  defaults <- list(digits = 3L, quiet = FALSE)
  supplied <- list(...)
  defaults[names(supplied)] <- supplied
  defaults
}

full_plot <- function(n = 10) {
  plot(seq_len(n), main = "full_plot")
  invisible(n)
}

full_experimental <- function(x) {
  x * 2
}

full_quotes <- function() {
  "one's bearings"
}

full_internal <- function() {
  invisible(NULL)
}

"+.fullclass" <- function(e1, e2) {
  structure(unclass(e1) + unclass(e2), class = "fullclass")
}
