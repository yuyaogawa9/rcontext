# Tests for the pure parts of agent_tools.R -- the pieces that do not need an
# agent, an MCP server, or RStudio in the loop.
#
# Run with:  Rscript tests/test_agent_tools.R
# Exits non-zero on failure so CI can use it.

source("R/agent_tools.R")   # run from the repo root

failures <- 0L
ok <- function(label, cond) {
  if (isTRUE(cond)) {
    cat("PASS  ", label, "\n", sep = "")
  } else {
    cat("FAIL  ", label, "\n", sep = "")
    failures <<- failures + 1L
  }
}

# --- truncation --------------------------------------------------------------

ok("empty input returns empty string",
   identical(agent_truncate(character(0)), ""))

ok("short output passes through untouched",
   identical(agent_truncate(c("a", "b")), "a\nb"))

long <- agent_truncate(as.character(1:500), max_lines = 10)
ok("line cap applied",
   length(strsplit(long, "\n")[[1]]) == 11L)          # 10 lines + 1 notice
ok("line truncation is announced",
   grepl("490 more lines truncated", long, fixed = TRUE))

wide <- agent_truncate(strrep("x", 500), max_chars = 100)
ok("char cap applied",
   nchar(strsplit(wide, "\n")[[1]][1]) == 100L)
ok("char truncation is announced",
   grepl("truncated at 100 characters", wide, fixed = TRUE))

# --- history -----------------------------------------------------------------

.agent_state$history <- character(0)
ok("empty history reports itself",
   grepl("No console history", agent_console_history()))

agent_log_entry("1 + 1", "[1] 2")
ok("entry is recorded with its output",
   grepl("> 1 + 1\n[1] 2", agent_console_history(), fixed = TRUE))

.agent_state$history <- character(0)
for (i in 1:150) agent_log_entry(paste0("cmd", i))
ok("history is capped at AGENT_HISTORY_MAX",
   length(.agent_state$history) == AGENT_HISTORY_MAX)
ok("history keeps the most recent entries",
   grepl("cmd150", agent_console_history(1), fixed = TRUE))

# --- run_r: sandbox ----------------------------------------------------------

.agent_state$scratch <- new.env(parent = globalenv())
assign("sentinel", "original", envir = globalenv())

invisible(agent_run_r("sentinel <- 'modified'"))
ok("sandboxed assignment does not touch globalenv",
   identical(get("sentinel", envir = globalenv()), "original"))
ok("sandboxed assignment lands in the scratch env",
   identical(get("sentinel", envir = .agent_state$scratch), "modified"))

invisible(agent_run_r("sentinel <- 'committed'", commit = TRUE))
ok("commit = TRUE writes to globalenv",
   identical(get("sentinel", envir = globalenv()), "committed"))

assign("readable", 41, envir = globalenv())
ok("reads fall through to globalenv",
   grepl("42", agent_run_r("readable + 1"), fixed = TRUE))

# --- run_r: output capture ---------------------------------------------------

ok("visible values are printed",
   grepl("[1] 3", agent_run_r("1 + 2"), fixed = TRUE))
ok("invisible assignment produces the delta note, not a value",
   grepl("created in scratch env", agent_run_r("zz <- 5"), fixed = TRUE))
ok("cat() output is captured",
   grepl("hello", agent_run_r("cat('hello\n')"), fixed = TRUE))
ok("errors are returned, not thrown",
   grepl("Error:", agent_run_r("stop('boom')"), fixed = TRUE))
ok("output printed before an error is kept",
   grepl("before", agent_run_r("cat('before\n'); stop('boom')"), fixed = TRUE))
ok("warnings are captured",
   grepl("Warning:", agent_run_r("warning('careful')"), fixed = TRUE))
ok("messages are captured",
   grepl("Message:", agent_run_r("message('fyi')"), fixed = TRUE))
ok("multiple expressions all evaluate",
   grepl("[1] 10", agent_run_r("a <- 4; b <- 6; a + b"), fixed = TRUE))

# --- run_r: feeds the shared history -----------------------------------------

.agent_state$history <- character(0)
invisible(agent_run_r("1 + 1"))
ok("agent executions are written to the console history",
   grepl("[agent] 1 + 1", agent_console_history(), fixed = TRUE))

# --- plots -------------------------------------------------------------------

ok("no device reports cleanly rather than erroring",
   grepl("No active plot device", agent_last_plot()))

# --- result ------------------------------------------------------------------

cat("\n", if (failures == 0L) "all tests passed" else
      paste0(failures, " test(s) failed"), "\n", sep = "")
quit(status = if (failures == 0L) 0L else 1L)
