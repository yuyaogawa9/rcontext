#' @keywords internal
"_PACKAGE"

# Internal, per-session state. Created at load time; never serialized between
# sessions. The scratch environment is built lazily because its parent must be
# the global environment of the *running* session, not of the build.
the <- new.env(parent = emptyenv())
the$history <- character(0)
the$scratch <- NULL
the$hooked <- FALSE
the$bridge <- FALSE
the$bridge_confirm <- TRUE

#' Options
#'
#' @description
#' `rcontext` reads these options, all of which have defaults:
#'
#' * `rcontext.max_lines` (200) — maximum lines in a single tool response.
#' * `rcontext.max_chars` (8000) — maximum characters in a single tool response.
#' * `rcontext.history` (100) — console entries retained.
#' * `rcontext.plot_dir` (".rcontext/plots") — where [get_last_plot] writes PNGs.
#' * `rcontext.session_file` (".rcontext/session.md") — where the console hook
#'   mirrors the session state for agents that cannot reach the MCP server.
#' * `rcontext.object_dir` (".rcontext/objects") — where [export] writes `.rds`
#'   files.
#' * `rcontext.bridge_cmd` (".rcontext/command.R") — file [bridge] reads code
#'   from.
#' * `rcontext.bridge_result` (".rcontext/result.txt") — file [bridge] writes
#'   output to.
#'
#' The two caps exist so that printing a large object cannot bury the agent's
#' context window; responses that hit a cap say so explicitly, so the agent
#' narrows its query rather than assuming it saw everything.
#'
#' @name rcontext-options
NULL

opt_max_lines    <- function() getOption("rcontext.max_lines", 200L)
opt_max_chars    <- function() getOption("rcontext.max_chars", 8000L)
opt_history      <- function() getOption("rcontext.history", 100L)
opt_plot_dir      <- function() getOption("rcontext.plot_dir", ".rcontext/plots")
opt_session_file  <- function() getOption("rcontext.session_file", ".rcontext/session.md")
opt_object_dir    <- function() getOption("rcontext.object_dir", ".rcontext/objects")
opt_bridge_cmd    <- function() getOption("rcontext.bridge_cmd", ".rcontext/command.R")
opt_bridge_result <- function() getOption("rcontext.bridge_result", ".rcontext/result.txt")

scratch_env <- function() {
  if (is.null(the$scratch)) the$scratch <- new.env(parent = globalenv())
  the$scratch
}
