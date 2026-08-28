# File-driven command bridge ------------------------------------------------
#
# For sites that disable every customized MCP server: the agent then has no
# tool to run code in the session, only its native file and shell access. This
# gives one back through a file. The agent writes R to `.rcontext/command.R`;
# the next time the user runs a console command, a task callback evaluates it
# in the global environment and writes `.rcontext/result.txt`.
#
# The design is deliberately supervised, and more so than `run_r`:
#   * it advances only on a user keystroke (a completed top-level command), an
#     RStudio hotkey, or an explicit `tick()` -- never on the agent's schedule;
#   * by default it asks y/n, showing the code, before it runs anything;
#   * evaluation is in `globalenv()`, so effects show up in the user's session
#     and the user can inspect or undo them;
#   * the queued file sits in the working directory until it fires, so the user
#     cancels a command by deleting it;
#   * every run echoes the code and its output to the console;
#   * it is off unless the user calls `bridge()` this session.

#' Ask the user whether to run a queued command
#'
#' Returns `TRUE` to run, `FALSE` to decline. Non-interactive sessions cannot
#' be asked, so `tick()` in a script runs without prompting. An unavailable or
#' cancelled prompt counts as "no".
#'
#' @noRd
bridge_ask <- function(code) {
  if (!interactive()) return(TRUE)
  isTRUE(tryCatch(
    utils::askYesNo(
      paste0("[rcontext bridge] run this code from the agent?\n\n", code, "\n"),
      default = FALSE
    ),
    error = function(e) FALSE
  ))
}

bridge_confirm <- function() isTRUE(the$bridge_confirm)

#' Evaluate a pending `.rcontext/command.R`, if there is one
#'
#' Renames the file to `command.R.done` before evaluating, so a second console
#' command entered while a slow one runs cannot fire it twice. When `confirm`
#' is on and the user says no, the file is moved to `command.R.declined` and
#' `result.txt` records the refusal so the agent does not wait on it.
#'
#' Never throws: file I/O is guarded and [run_code] folds evaluation errors
#' into the string it returns.
#'
#' @return Invisibly `TRUE` if a command was run, `FALSE` otherwise.
#' @noRd
bridge_step <- function(cmd = opt_bridge_cmd(), out = opt_bridge_result(),
                        confirm = bridge_confirm(), ask = bridge_ask) {
  if (!file.exists(cmd)) return(invisible(FALSE))

  code <- tryCatch(paste(readLines(cmd, warn = FALSE), collapse = "\n"),
                   error = function(e) NULL)
  if (is.null(code)) {
    bridge_retire(cmd, ".done")
    return(invisible(FALSE))
  }

  if (isTRUE(confirm) && !isTRUE(ask(code))) {
    bridge_retire(cmd, ".declined")
    bridge_write(out, c(
      paste0("# rcontext bridge -- declined by user ",
             format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
      "", code
    ))
    message("[rcontext bridge] declined ", cmd)
    return(invisible(FALSE))
  }

  bridge_retire(cmd, ".done")
  result <- run_code(code, commit = TRUE)
  bridge_write(out, c(
    paste0("# rcontext bridge result -- ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    "", result
  ))

  # echo to the console so the run is visible in the user's session, not just
  # in result.txt
  message("[rcontext bridge] ran ", cmd, " -> ", out, "\n", code, "\n\n", result)
  invisible(TRUE)
}

# rename cmd to cmd<suffix>, replacing any previous one (file.rename does not
# overwrite on Windows)
bridge_retire <- function(cmd, suffix) {
  target <- paste0(cmd, suffix)
  suppressWarnings(file.remove(target))
  file.rename(cmd, target)
}

bridge_write <- function(out, lines) {
  tryCatch(suppressWarnings({
    ensure_rcontext_dir(dirname(out))
    tmp <- paste0(out, ".tmp")
    writeLines(lines, tmp)
    file.rename(tmp, out)
  }), error = function(e) NULL)
}

#' Let a coding agent run code in your session through a file
#'
#' A fallback for when every customized MCP server is disabled and the agent
#' cannot reach your session at all. Once you call `bridge()`, any R code the
#' agent writes to `.rcontext/command.R` is evaluated **in your global
#' environment** the next time you run a console command (or use [tick()] / the
#' RStudio addin), and its output is written to `.rcontext/result.txt` for the
#' agent to read. The code and its output are also echoed to your console.
#'
#' By default it **asks y/n, showing the code, before running**, so nothing
#' from the agent executes without your say-so on that specific command. Say no
#' and the command is set aside (`command.R.declined`) and the agent is told.
#' Pass `confirm = FALSE` for a session where you would rather it just run.
#'
#' Even with `confirm = FALSE` this is a supervised channel: it advances only on
#' your action, the queued file is visible until it runs so deleting it cancels
#' the command, and everything happens in `globalenv()` where you can see and
#' undo it. It is still arbitrary code execution in a live session holding your
#' real work. Treat `rm()`, `file.remove()`, `system()` and overwriting a
#' loaded object as needing your explicit say-so, exactly as with `run_r`.
#'
#' Off by default. Put `rcontext::bridge()` in your `~/.Rprofile` (after
#' `rcontext::start()`) to have it on in every session.
#'
#' @param enable `TRUE` to install the callback, `FALSE` to remove it.
#' @param confirm `TRUE` (default) to prompt y/n before each run.
#' @return Invisibly `TRUE` when the bridge is on afterwards, `FALSE` when off.
#' @export
#' @examples
#' \dontrun{
#' rcontext::bridge()                 # asks before each run
#' rcontext::bridge(confirm = FALSE)  # runs queued code without prompting
#' # ... agent writes .rcontext/command.R ...
#' rcontext::tick()                   # or run anything at the console
#' rcontext::bridge(FALSE)
#' }
bridge <- function(enable = TRUE, confirm = TRUE) {
  if (!isTRUE(enable)) {
    removeTaskCallback("rcontext_bridge")
    the$bridge <- FALSE
    message("rcontext bridge disabled.")
    return(invisible(FALSE))
  }

  the$bridge_confirm <- isTRUE(confirm)
  if (isTRUE(the$bridge)) return(invisible(TRUE))

  # make the directory the agent will write command.R into, so its first write
  # does not fail on a missing folder
  tryCatch(ensure_rcontext_dir(dirname(opt_bridge_cmd())), error = function(e) NULL)

  addTaskCallback(
    function(...) {
      tryCatch(bridge_step(), error = function(e) NULL)
      TRUE
    },
    name = "rcontext_bridge"
  )
  the$bridge <- TRUE
  message(
    "rcontext bridge enabled",
    if (the$bridge_confirm) " (asks before each run)." else
      " -- runs queued code without prompting.",
    " The agent writes to ", opt_bridge_cmd(),
    "; it runs in your GLOBAL environment on your next console command or ",
    "rcontext::tick(). Delete that file to cancel a queued command. ",
    "rcontext::bridge(FALSE) to turn this off."
  )
  invisible(TRUE)
}

#' @rdname bridge
#' @details
#' `tick()` runs a pending `.rcontext/command.R` immediately, without waiting
#' for you to enter a console command. Bind it to an RStudio keyboard shortcut
#' through **Addins**, or call it directly. It obeys the same `confirm` setting.
#' @return `tick()` invisibly returns `TRUE` if it ran a command, `FALSE` if
#'   there was nothing pending or it was declined.
#' @export
tick <- function() {
  if (!file.exists(opt_bridge_cmd())) {
    message("rcontext: no ", opt_bridge_cmd(), " to run.")
    return(invisible(FALSE))
  }
  invisible(bridge_step())
}
