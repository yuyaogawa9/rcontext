# Console history --------------------------------------------------------------

#' Append one entry to the shared history log
#'
#' Both the console callback and [run_r] feed this, so the agent sees its own
#' earlier work alongside the user's. Keeping them in one log is what stops the
#' agent losing track of what it did two turns ago.
#'
#' @noRd
log_entry <- function(cmd, output = "") {
  entry <- if (nzchar(output)) paste0("> ", cmd, "\n", output) else paste0("> ", cmd)
  the$history <- utils::tail(c(the$history, entry), opt_history())
  invisible(entry)
}

#' Install the console and error hooks
#'
#' Two hooks are required, not one. `addTaskCallback()` does not fire for a
#' top-level expression that throws, and errors are precisely what the agent
#' needs to see. `globalCallingHandlers()` catches those without consuming
#' them, so RStudio still reports the error to the user as normal.
#'
#' Idempotent: repeated calls do nothing.
#'
#' @noRd
install_hooks <- function() {
  if (isTRUE(the$hooked)) return(invisible(FALSE))

  addTaskCallback(function(expr, value, ok, visible) {
    cmd <- paste(deparse(expr), collapse = " ")
    out <- if (ok && visible) {
      tryCatch(
        paste(utils::capture.output(print(value)), collapse = "\n"),
        error = function(e) "<unprintable>"
      )
    } else {
      ""
    }
    log_entry(cmd, truncate_output(out))
    TRUE
  }, name = "rcontext_console")

  tryCatch(
    globalCallingHandlers(error = function(e) {
      call_txt <- if (is.null(conditionCall(e))) {
        "<top level>"
      } else {
        paste(deparse(conditionCall(e)), collapse = " ")
      }
      log_entry(call_txt, paste0("Error: ", conditionMessage(e)))
    }),
    error = function(e) invisible(NULL)  # handlers already on the stack
  )

  the$hooked <- TRUE
  invisible(TRUE)
}

#' Remove the console hook
#'
#' `globalCallingHandlers()` cannot selectively deregister, so the error hook
#' stays for the life of the session. It is harmless once the package is
#' detached: it only appends to an environment nobody reads.
#'
#' @noRd
remove_hooks <- function() {
  removeTaskCallback("rcontext_console")
  the$hooked <- FALSE
  invisible(TRUE)
}

console_history <- function(n = 20) {
  if (length(the$history) == 0L) return("No console history recorded yet.")
  truncate_output(paste(utils::tail(the$history, n), collapse = "\n\n"))
}
