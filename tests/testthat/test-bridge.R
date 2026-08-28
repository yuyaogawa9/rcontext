# Each test points the bridge at files under a fresh temp dir and silences the
# echo message; nothing here touches a real .rcontext/ directory. The pattern
# (tempfile + on.exit unlink + options/on.exit restore) matches test-snapshot.R.
#
# bridge_step() mechanics tests pass confirm = FALSE so they do not depend on
# interactive()/the$bridge_confirm; the confirmation path is tested separately
# with a stubbed `ask`.

bridge_opts <- function(d) {
  options(rcontext.bridge_cmd = file.path(d, "command.R"),
          rcontext.bridge_result = file.path(d, "result.txt"))
}

# bridge() / tick() plumbing ------------------------------------------------

test_that("bridge() installs a named callback and is idempotent", {
  d <- tempfile(); dir.create(d)
  old <- options(rcontext.bridge_cmd = file.path(d, "command.R"))
  on.exit({ options(old); unlink(d, recursive = TRUE)
            removeTaskCallback("rcontext_bridge"); the$bridge <- FALSE }, add = TRUE)

  suppressMessages(bridge())
  expect_true("rcontext_bridge" %in% getTaskCallbackNames())
  expect_true(the$bridge)

  before <- length(getTaskCallbackNames())
  suppressMessages(bridge())                       # second call is a no-op
  expect_length(getTaskCallbackNames(), before)
})

test_that("bridge(FALSE) removes the callback", {
  d <- tempfile(); dir.create(d)
  old <- options(rcontext.bridge_cmd = file.path(d, "command.R"))
  on.exit({ options(old); unlink(d, recursive = TRUE)
            removeTaskCallback("rcontext_bridge"); the$bridge <- FALSE }, add = TRUE)

  suppressMessages(bridge())
  suppressMessages(bridge(FALSE))
  expect_false("rcontext_bridge" %in% getTaskCallbackNames())
  expect_false(the$bridge)
})

test_that("confirm defaults on and bridge(confirm = FALSE) turns it off", {
  d <- tempfile(); dir.create(d)
  old <- options(rcontext.bridge_cmd = file.path(d, "command.R"))
  on.exit({ options(old); unlink(d, recursive = TRUE)
            removeTaskCallback("rcontext_bridge")
            the$bridge <- FALSE; the$bridge_confirm <- TRUE }, add = TRUE)

  expect_true(the$bridge_confirm)                  # default from the$ init

  suppressMessages(bridge(confirm = FALSE))
  expect_false(the$bridge_confirm)

  suppressMessages(bridge(FALSE)); the$bridge <- FALSE
  suppressMessages(bridge())                       # re-enable, default confirm
  expect_true(the$bridge_confirm)
})

# bridge_step() ----------------------------------------------------------

test_that("a queued command is evaluated and its output written", {
  d <- tempfile(); dir.create(d)
  old <- bridge_opts(d)
  on.exit({ options(old); unlink(d, recursive = TRUE) }, add = TRUE)
  the$scratch <- NULL

  writeLines("1 + 1", getOption("rcontext.bridge_cmd"))
  expect_true(suppressMessages(bridge_step(confirm = FALSE)))

  res <- paste(readLines(getOption("rcontext.bridge_result")), collapse = "\n")
  expect_match(res, "[1] 2", fixed = TRUE)
  expect_match(res, "rcontext bridge result", fixed = TRUE)
})

test_that("the consumed command file is renamed to .done", {
  d <- tempfile(); dir.create(d)
  old <- bridge_opts(d)
  on.exit({ options(old); unlink(d, recursive = TRUE) }, add = TRUE)

  writeLines("1", getOption("rcontext.bridge_cmd"))
  suppressMessages(bridge_step(confirm = FALSE))

  expect_false(file.exists(getOption("rcontext.bridge_cmd")))
  expect_true(file.exists(paste0(getOption("rcontext.bridge_cmd"), ".done")))
})

test_that("assignments land in the global environment", {
  d <- tempfile(); dir.create(d)
  old <- bridge_opts(d)
  on.exit({ options(old); unlink(d, recursive = TRUE)
            suppressWarnings(rm("rc_bridge_var", envir = globalenv())) }, add = TRUE)
  the$scratch <- NULL

  writeLines("rc_bridge_var <- 42", getOption("rcontext.bridge_cmd"))
  suppressMessages(bridge_step(confirm = FALSE))

  expect_identical(get0("rc_bridge_var", envir = globalenv(), inherits = FALSE), 42)
})

test_that("an erroring command is captured, not raised, and still consumed", {
  d <- tempfile(); dir.create(d)
  old <- bridge_opts(d)
  on.exit({ options(old); unlink(d, recursive = TRUE) }, add = TRUE)
  the$scratch <- NULL

  writeLines("stop('boom')", getOption("rcontext.bridge_cmd"))
  expect_true(suppressMessages(bridge_step(confirm = FALSE)))   # returns, no throw

  res <- paste(readLines(getOption("rcontext.bridge_result")), collapse = "\n")
  expect_match(res, "Error:", fixed = TRUE)
  expect_true(file.exists(paste0(getOption("rcontext.bridge_cmd"), ".done")))
})

test_that("bridge_step() is a no-op when there is nothing queued", {
  d <- tempfile(); dir.create(d)
  old <- bridge_opts(d)
  on.exit({ options(old); unlink(d, recursive = TRUE) }, add = TRUE)

  expect_false(suppressMessages(bridge_step(confirm = FALSE)))
  expect_false(file.exists(getOption("rcontext.bridge_result")))
})

test_that("a half-written .tmp file is ignored until renamed into place", {
  d <- tempfile(); dir.create(d)
  old <- bridge_opts(d)
  on.exit({ options(old); unlink(d, recursive = TRUE) }, add = TRUE)

  writeLines("1 + 1", paste0(getOption("rcontext.bridge_cmd"), ".tmp"))
  expect_false(suppressMessages(bridge_step(confirm = FALSE)))
  expect_false(file.exists(getOption("rcontext.bridge_result")))
})

# confirmation path ----------------------------------------------------

test_that("saying no sets the command aside and records the refusal", {
  d <- tempfile(); dir.create(d)
  old <- bridge_opts(d)
  on.exit({ options(old); unlink(d, recursive = TRUE)
            suppressWarnings(rm("rc_declined_var", envir = globalenv())) }, add = TRUE)
  the$scratch <- NULL

  writeLines("rc_declined_var <- 1", getOption("rcontext.bridge_cmd"))
  res <- suppressMessages(bridge_step(confirm = TRUE, ask = function(code) FALSE))

  expect_false(isTRUE(res))
  expect_false(exists("rc_declined_var", envir = globalenv(), inherits = FALSE))
  expect_false(file.exists(paste0(getOption("rcontext.bridge_cmd"), ".done")))
  expect_true(file.exists(paste0(getOption("rcontext.bridge_cmd"), ".declined")))
  out <- paste(readLines(getOption("rcontext.bridge_result")), collapse = "\n")
  expect_match(out, "declined by user", fixed = TRUE)
  expect_match(out, "rc_declined_var <- 1", fixed = TRUE)
})

test_that("saying yes runs it, and the prompt receives the code", {
  d <- tempfile(); dir.create(d)
  old <- bridge_opts(d)
  on.exit({ options(old); unlink(d, recursive = TRUE) }, add = TRUE)
  the$scratch <- NULL
  seen <- NULL

  writeLines("6 * 7", getOption("rcontext.bridge_cmd"))
  ok <- suppressMessages(bridge_step(
    confirm = TRUE, ask = function(code) { seen <<- code; TRUE }
  ))

  expect_true(ok)
  expect_identical(seen, "6 * 7")
  expect_match(paste(readLines(getOption("rcontext.bridge_result")), collapse = "\n"),
               "[1] 42", fixed = TRUE)
  expect_true(file.exists(paste0(getOption("rcontext.bridge_cmd"), ".done")))
})

test_that("confirm = FALSE never calls ask", {
  d <- tempfile(); dir.create(d)
  old <- bridge_opts(d)
  on.exit({ options(old); unlink(d, recursive = TRUE) }, add = TRUE)
  the$scratch <- NULL

  writeLines("1 + 1", getOption("rcontext.bridge_cmd"))
  expect_true(suppressMessages(bridge_step(
    confirm = FALSE, ask = function(code) stop("ask() must not be called")
  )))
})

# tick() ---------------------------------------------------------------

test_that("tick() runs a pending command without any task callback", {
  d <- tempfile(); dir.create(d)
  old <- bridge_opts(d)
  on.exit({ options(old); unlink(d, recursive = TRUE)
            the$bridge_confirm <- TRUE }, add = TRUE)
  the$scratch <- NULL
  the$bridge_confirm <- FALSE                      # no prompt in this test

  writeLines("2 * 3", getOption("rcontext.bridge_cmd"))
  expect_true(suppressMessages(tick()))
  expect_match(paste(readLines(getOption("rcontext.bridge_result")), collapse = "\n"),
               "[1] 6", fixed = TRUE)

  expect_false(suppressMessages(tick()))           # nothing left
})

# ensure_rcontext_dir() ---------------------------------------------

test_that("the first write drops a self-ignoring .gitignore in .rcontext/", {
  d <- tempfile()
  on.exit(unlink(d, recursive = TRUE), add = TRUE)

  ensure_rcontext_dir(file.path(d, ".rcontext", "objects"))

  gi <- file.path(d, ".rcontext", ".gitignore")
  expect_true(file.exists(gi))
  expect_identical(readLines(gi), "*")
})

test_that("ensure_rcontext_dir leaves paths outside a .rcontext/ folder alone", {
  d <- tempfile()
  on.exit(unlink(d, recursive = TRUE), add = TRUE)

  ensure_rcontext_dir(file.path(d, "plain"))
  expect_true(dir.exists(file.path(d, "plain")))
  expect_false(file.exists(file.path(d, ".gitignore")))
})
