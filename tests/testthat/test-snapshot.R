# write_session_snapshot -----------------------------------------------------

test_that("the snapshot carries the environment and the console history", {
  d <- tempfile()
  f <- file.path(d, "session.md")
  on.exit(unlink(d, recursive = TRUE), add = TRUE)

  the$history <- character(0)
  log_entry("2 + 2", "[1] 4")
  assign("rc_snap_df", data.frame(a = 1:3), envir = globalenv())
  on.exit(rm("rc_snap_df", envir = globalenv()), add = TRUE)

  write_session_snapshot(f)

  txt <- paste(readLines(f), collapse = "\n")
  expect_match(txt, "## Environment", fixed = TRUE)
  expect_match(txt, "rc_snap_df", fixed = TRUE)
  expect_match(txt, "## Console history", fixed = TRUE)
  expect_match(txt, "> 2 + 2\n[1] 4", fixed = TRUE)
})

test_that("write_session_snapshot creates the parent directory", {
  d <- tempfile()
  on.exit(unlink(d, recursive = TRUE), add = TRUE)

  write_session_snapshot(file.path(d, "nested", "session.md"))
  expect_true(file.exists(file.path(d, "nested", "session.md")))
})

test_that("a snapshot failure never reaches the user's console", {
  # a path ending in "/" makes writeLines() warn and then throw; none of it
  # may surface -- not the error, not the warnings
  expect_silent(write_session_snapshot(paste0(tempdir(), "/")))
})

test_that("log_entry refreshes the snapshot only while hooked", {
  f <- tempfile(fileext = ".md")
  old <- options(rcontext.session_file = f)
  on.exit(options(old), add = TRUE)
  on.exit(unlink(f), add = TRUE)
  on.exit(the$hooked <- FALSE, add = TRUE)

  the$history <- character(0)

  the$hooked <- FALSE
  log_entry("unhooked <- 1")
  expect_false(file.exists(f))

  the$hooked <- TRUE
  log_entry("hooked <- 1")
  expect_true(file.exists(f))
})

# export --------------------------------------------------------------------

test_that("export writes an rds per named object that round-trips", {
  d <- tempfile()
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  assign("rc_exp_a", data.frame(x = 1:5), envir = globalenv())
  assign("rc_exp_b", list(k = "v"), envir = globalenv())
  on.exit(rm("rc_exp_a", "rc_exp_b", envir = globalenv()), add = TRUE)

  written <- suppressMessages(export(rc_exp_a, rc_exp_b, dir = d))

  expect_setequal(basename(written), c("rc_exp_a.rds", "rc_exp_b.rds"))
  expect_identical(readRDS(file.path(d, "rc_exp_a.rds")), data.frame(x = 1:5))
  expect_identical(readRDS(file.path(d, "rc_exp_b.rds")), list(k = "v"))
})

test_that("export accepts quoted names too", {
  d <- tempfile()
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  assign("rc_exp_q", 1:3, envir = globalenv())
  on.exit(rm("rc_exp_q", envir = globalenv()), add = TRUE)

  written <- suppressMessages(export("rc_exp_q", dir = d))
  expect_identical(basename(written), "rc_exp_q.rds")
})

test_that("export skips an unknown object without writing it", {
  d <- tempfile()
  on.exit(unlink(d, recursive = TRUE), add = TRUE)

  expect_message(res <- export(rc_not_a_real_object, dir = d), "no such object")
  expect_identical(res, character(0))
})

test_that("export skips an object over the size cap", {
  d <- tempfile()
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  assign("rc_exp_big", rnorm(1000), envir = globalenv())
  on.exit(rm("rc_exp_big", envir = globalenv()), add = TRUE)

  expect_message(res <- export(rc_exp_big, max_size = 10, dir = d),
                 "exceeds the")
  expect_identical(res, character(0))
  expect_false(file.exists(file.path(d, "rc_exp_big.rds")))
})

test_that("export with no objects named is a no-op with a hint", {
  expect_message(res <- export(), "name at least one object")
  expect_identical(res, character(0))
})
