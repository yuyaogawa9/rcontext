test_that("empty history says so rather than returning nothing", {
  the$history <- character(0)
  expect_match(console_history(), "No console history")
})

test_that("an entry keeps its command and output together", {
  the$history <- character(0)
  log_entry("1 + 1", "[1] 2")
  expect_match(console_history(), "> 1 + 1\n[1] 2", fixed = TRUE)
})

test_that("history is capped and keeps the most recent entries", {
  the$history <- character(0)
  old <- options(rcontext.history = 100L)
  on.exit(options(old), add = TRUE)

  for (i in 1:150) log_entry(paste0("cmd", i))
  expect_length(the$history, 100L)
  expect_match(console_history(1), "cmd150", fixed = TRUE)
  expect_false(grepl("cmd1\n", console_history(100), fixed = TRUE))
})
