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

# Regression: 0.1.0 passed unquoted arguments to system2(), so the shell saw
# the parentheses in rcontext::mcp_server() as syntax and registration failed.
# The command printed for the user to copy had the same defect.

test_that("shell metacharacters in the server command are quoted", {
  cl <- agent_command_line("claude", "add")
  expect_match(cl, '"rcontext::mcp_server()"', fixed = TRUE)
})

test_that("the printed command parses back to the intended argv", {
  skip_on_os("windows")
  for (cli in c("claude", "copilot")) {
    line <- agent_command_line(cli, "add")
    args <- sub(paste0("^", cli, " "), "", line)
    argv <- system(
      paste("sh -c 'for a in \"$@\"; do echo \"$a\"; done' _", args),
      intern = TRUE
    )
    expect_identical(argv, agent_args(cli, "add"))
  }
})

test_that("commands executed via system2 are quoted too", {
  skip_on_os("windows")
  args <- shQuote(agent_args("claude", "add"))
  argv <- system(
    paste("sh -c 'for a in \"$@\"; do echo \"$a\"; done' _",
          paste(args, collapse = " ")),
    intern = TRUE
  )
  expect_identical(argv, agent_args("claude", "add"))
})

test_that("agent_command_line handles an unknown CLI", {
  expect_true(is.na(agent_command_line("nonsense", "add")))
})

# Skills -----------------------------------------------------------------------
#
# As above, everything here runs against a temporary directory, never the real
# ~/.claude.

test_that("the package ships a skill the agents can parse", {
  skip_if(!nzchar(skill_source()), "package not installed with inst/")

  src <- file.path(skill_source(), "rcontext", "SKILL.md")
  expect_true(file.exists(src))

  lines <- readLines(src, warn = FALSE)
  expect_identical(lines[1], "---")
  front <- lines[2:(which(lines == "---")[2] - 1L)]
  expect_true(any(grepl("^name: rcontext$", front)))
  expect_true(any(grepl("^description: ", front)))
})

test_that("install_claude_skill writes the skill where claude looks for it", {
  d <- tempfile()
  on.exit(unlink(d, recursive = TRUE), add = TRUE)

  expect_true(install_claude_skill(d))
  expect_true(file.exists(file.path(d, "skills", "rcontext", "SKILL.md")))
})

test_that("install_claude_skill refreshes an existing skill", {
  d <- tempfile()
  on.exit(unlink(d, recursive = TRUE), add = TRUE)

  dest <- file.path(d, "skills", "rcontext")
  dir.create(dest, recursive = TRUE)
  writeLines("stale content from an older version", file.path(dest, "SKILL.md"))

  expect_true(install_claude_skill(d))
  written <- readLines(file.path(dest, "SKILL.md"), warn = FALSE)
  expect_false(any(grepl("stale content", written)))
  expect_identical(written[1], "---")
})

test_that("remove_claude_skill removes it, and is a no-op when absent", {
  d <- tempfile()
  on.exit(unlink(d, recursive = TRUE), add = TRUE)

  expect_false(remove_claude_skill(d))  # nothing there yet

  install_claude_skill(d)
  expect_true(remove_claude_skill(d))
  expect_false(dir.exists(file.path(d, "skills", "rcontext")))
})

test_that("skill_action dispatches claude to the file copy", {
  d <- tempfile()
  on.exit(unlink(d, recursive = TRUE), add = TRUE)

  expect_identical(skill_action("claude", d, "add"), "claude")
  expect_true(file.exists(file.path(d, "skills", "rcontext", "SKILL.md")))

  expect_identical(skill_action("claude", d, "remove"), "claude")
  expect_false(dir.exists(file.path(d, "skills", "rcontext")))
})

test_that("skill commands are the documented ones", {
  expect_identical(
    agent_args("copilot", "skill_add"),
    c("skill", "add", skill_source())
  )
  expect_identical(
    agent_args("copilot", "skill_remove"),
    c("skill", "remove", skill_source())
  )
  # claude has no CLI for this; the file copy handles it
  expect_null(agent_args("claude", "skill_add"))
})

# The library path is outside our control and routinely contains spaces
# (~/Documents/Home Work/...), which is the same defect class as 0.1.1.

test_that("a skill path containing spaces survives shell quoting", {
  skip_on_os("windows")

  args <- shQuote(c("skill", "add", "/tmp/Home Work/lib/rcontext/skills"))
  argv <- system(
    paste("sh -c 'for a in \"$@\"; do echo \"$a\"; done' _",
          paste(args, collapse = " ")),
    intern = TRUE
  )
  expect_identical(argv[3], "/tmp/Home Work/lib/rcontext/skills")
})
