# These exercise the file manipulation against a temporary file, never the
# real ~/.Rprofile.

test_that("add_block creates the file when it does not exist", {
  f <- tempfile()
  on.exit(unlink(f), add = TRUE)

  expect_false(has_block(f))
  expect_true(add_block(f))
  expect_true(has_block(f))
  expect_match(paste(readLines(f), collapse = "\n"), "rcontext::start()", fixed = TRUE)
})

test_that("add_block is idempotent", {
  f <- tempfile()
  on.exit(unlink(f), add = TRUE)

  add_block(f)
  first <- readLines(f)
  expect_false(add_block(f))
  expect_identical(readLines(f), first)
})

test_that("teardown leaves the user's own lines exactly as they were", {
  f <- tempfile()
  on.exit(unlink(f), add = TRUE)

  original <- c("options(stringsAsFactors = FALSE)", "", "message('hello')")
  writeLines(original, f)

  add_block(f)
  expect_true(has_block(f))

  expect_true(remove_block(f))
  expect_false(has_block(f))
  expect_identical(readLines(f), original)
})

test_that("remove_block is a no-op when there is nothing to remove", {
  f <- tempfile()
  on.exit(unlink(f), add = TRUE)

  writeLines("x <- 1", f)
  expect_false(remove_block(f))
  expect_identical(readLines(f), "x <- 1")

  expect_false(remove_block(tempfile()))  # missing file
})

test_that("the startup block is guarded on all three conditions", {
  blk <- paste(startup_block(), collapse = "\n")
  expect_match(blk, "interactive()", fixed = TRUE)
  expect_match(blk, "RCONTEXT_DISABLE", fixed = TRUE)
  expect_match(blk, "requireNamespace", fixed = TRUE)
})

test_that("agent commands are the documented ones", {
  expect_identical(
    agent_args("claude", "add"),
    c("mcp", "add", "-s", "user", "rcontext", "--",
      "Rscript", "-e", "rcontext::mcp_server()")
  )
  expect_identical(
    agent_args("copilot", "add"),
    c("mcp", "add", "rcontext", "--", "Rscript", "-e", "rcontext::mcp_server()")
  )
  expect_null(agent_args("nonsense", "add"))
})

test_that("setup() refuses to touch anything non-interactively", {
  expect_error(setup(), "interactive session")
})
