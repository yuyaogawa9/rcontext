test_that("sandboxed assignment leaves the global environment alone", {
  the$scratch <- NULL
  assign("rc_sentinel", "original", envir = globalenv())
  on.exit(rm("rc_sentinel", envir = globalenv()), add = TRUE)

  run_code("rc_sentinel <- 'modified'")

  expect_identical(get("rc_sentinel", envir = globalenv()), "original")
  expect_identical(get("rc_sentinel", envir = scratch_env()), "modified")
})

test_that("commit = TRUE writes to the global environment", {
  the$scratch <- NULL
  assign("rc_sentinel", "original", envir = globalenv())
  on.exit(rm("rc_sentinel", envir = globalenv()), add = TRUE)

  run_code("rc_sentinel <- 'committed'", commit = TRUE)

  expect_identical(get("rc_sentinel", envir = globalenv()), "committed")
})

test_that("reads fall through to the global environment", {
  the$scratch <- NULL
  assign("rc_readable", 41, envir = globalenv())
  on.exit(rm("rc_readable", envir = globalenv()), add = TRUE)

  expect_match(run_code("rc_readable + 1"), "42", fixed = TRUE)
})

test_that("output, warnings, messages and errors are all captured", {
  the$scratch <- NULL
  expect_match(run_code("1 + 2"), "[1] 3", fixed = TRUE)
  expect_match(run_code("cat('hello\n')"), "hello", fixed = TRUE)
  expect_match(run_code("warning('careful')"), "Warning:", fixed = TRUE)
  expect_match(run_code("message('fyi')"), "Message:", fixed = TRUE)
  expect_match(run_code("stop('boom')"), "Error:", fixed = TRUE)
})

test_that("an error does not discard output printed before it", {
  the$scratch <- NULL
  expect_match(run_code("cat('before\n'); stop('boom')"), "before", fixed = TRUE)
})

test_that("new objects are reported as a delta", {
  the$scratch <- NULL
  expect_match(run_code("zz <- 5"), "created in scratch env", fixed = TRUE)
})

test_that("agent executions land in the shared console history", {
  the$scratch <- NULL
  the$history <- character(0)
  run_code("1 + 1")
  expect_match(console_history(), "[agent] 1 + 1", fixed = TRUE)
})
