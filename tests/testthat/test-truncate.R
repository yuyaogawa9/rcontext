test_that("empty input gives an empty string", {
  expect_identical(truncate_output(character(0)), "")
  expect_identical(truncate_output(""), "")
})

test_that("short output passes through untouched", {
  expect_identical(truncate_output(c("a", "b")), "a\nb")
})

test_that("the line cap applies and announces itself", {
  out <- truncate_output(as.character(1:500), max_lines = 10)
  expect_length(strsplit(out, "\n")[[1]], 11L)   # 10 kept + 1 notice
  expect_match(out, "490 more lines truncated", fixed = TRUE)
})

test_that("the character cap applies and announces itself", {
  out <- truncate_output(strrep("x", 500), max_chars = 100)
  expect_identical(nchar(strsplit(out, "\n")[[1]][1]), 100L)
  expect_match(out, "truncated at 100 characters", fixed = TRUE)
})
