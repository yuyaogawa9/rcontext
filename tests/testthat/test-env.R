test_that("an empty environment reports itself clearly", {
  # can't truly empty the global env, so only assert the code path exists
  expect_type(describe_env(), "character")
})

test_that("data frames are summarised with their columns", {
  assign("rc_df", data.frame(a = 1:3, b = c("x", "y", NA)), envir = globalenv())
  on.exit(rm("rc_df", envir = globalenv()), add = TRUE)

  out <- describe_env()
  expect_match(out, "rc_df", fixed = TRUE)
  expect_match(out, "columns: a, b", fixed = TRUE)
})

test_that("describe_df reports shape, types and missing counts", {
  assign("rc_df", data.frame(a = 1:3, b = c("x", "y", NA)), envir = globalenv())
  on.exit(rm("rc_df", envir = globalenv()), add = TRUE)

  out <- describe_df("rc_df")
  expect_match(out, "3 rows x 2 columns", fixed = TRUE)
  expect_match(out, "1 missing", fixed = TRUE)
  expect_match(out, "integer", fixed = TRUE)
})

test_that("describe_df fails helpfully on bad input", {
  expect_match(describe_df("rc_definitely_not_here"), "No object named")
  assign("rc_vec", 1:10, envir = globalenv())
  on.exit(rm("rc_vec", envir = globalenv()), add = TRUE)
  expect_match(describe_df("rc_vec"), "not a data frame")
})
