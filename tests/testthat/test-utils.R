test_that("%||% returns the fallback only for NULL", {
  expect_identical(NULL %||% "b", "b")
  expect_identical("a" %||% "b", "a")
  expect_identical(FALSE %||% "b", FALSE)
})
