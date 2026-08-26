# agent_tools.R ---------------------------------------------------------------
#
# Tools that let a terminal coding agent see this R session: what is loaded,
# what you ran, what it printed, and what the last plot looked like.
#
# Sourced by .Rprofile. Defines plain R functions first (testable without any
# agent in the loop), then wraps them as ellmer tools at the bottom.

# --- configuration -----------------------------------------------------------

AGENT_MAX_LINES   <- 200    # per tool response
AGENT_MAX_CHARS   <- 8000   # per tool response
AGENT_HISTORY_MAX <- 100    # entries retained
AGENT_PLOT_DIR    <- ".agent/plots"

# --- internal state ----------------------------------------------------------

.agent_state <- new.env(parent = emptyenv())
.agent_state$history   <- character(0)
.agent_state$scratch   <- new.env(parent = globalenv())
.agent_state$hooked    <- FALSE

# --- output shaping ----------------------------------------------------------

#' Cap tool output so a large print() cannot bury the agent's context.
#' Always says when it truncated, so the agent narrows its query instead of
#' assuming it saw everything.
agent_truncate <- function(x, max_lines = AGENT_MAX_LINES, max_chars = AGENT_MAX_CHARS) {
  txt <- paste(x, collapse = "\n")
  if (!nzchar(txt)) return("")

  lines <- strsplit(txt, "\n", fixed = TRUE)[[1]]
  notes <- character(0)

  if (length(lines) > max_lines) {
    notes <- sprintf("... [%d more lines truncated]", length(lines) - max_lines)
    lines <- lines[seq_len(max_lines)]
  }

  out <- paste(lines, collapse = "\n")
  if (nchar(out) > max_chars) {
    out   <- substr(out, 1, max_chars)
    notes <- c(notes, sprintf("... [truncated at %d characters]", max_chars))
  }

  paste(c(out, notes), collapse = "\n")
}

# --- console history ---------------------------------------------------------

#' Append one entry to the shared history log.
#' Both the console callback and run_r() feed this, so the agent can see its
#' own earlier work as well as yours.
agent_log_entry <- function(cmd, output = "") {
  entry <- if (nzchar(output)) paste0("> ", cmd, "\n", output) else paste0("> ", cmd)
  .agent_state$history <- utils::tail(c(.agent_state$history, entry), AGENT_HISTORY_MAX)
  invisible(entry)
}

#' Install the console + error hooks. Idempotent.
#'
#' Two hooks are needed because addTaskCallback() does not fire for a top-level
#' expression that throws -- and errors are exactly what the agent needs to see.
#' globalCallingHandlers() catches those without swallowing them, so RStudio
#' still shows the error to you normally.
agent_start_logging <- function() {
  if (isTRUE(.agent_state$hooked)) return(invisible(FALSE))

  addTaskCallback(function(expr, value, ok, visible) {
    cmd <- paste(deparse(expr), collapse = " ")
    out <- if (ok && visible) {
      tryCatch(paste(utils::capture.output(print(value)), collapse = "\n"),
               error = function(e) "<unprintable>")
    } else {
      ""
    }
    agent_log_entry(cmd, agent_truncate(out))
    TRUE
  }, name = "agent_console_log")

  tryCatch(
    globalCallingHandlers(error = function(e) {
      call_txt <- if (is.null(conditionCall(e))) "<top level>" else
        paste(deparse(conditionCall(e)), collapse = " ")
      agent_log_entry(call_txt, paste0("Error: ", conditionMessage(e)))
    }),
    error = function(e) invisible(NULL)  # handlers already on the stack
  )

  .agent_state$hooked <- TRUE
  invisible(TRUE)
}

#' Recent console commands and their output, oldest first.
agent_console_history <- function(n = 20) {
  h <- .agent_state$history
  if (length(h) == 0) return("No console history recorded yet.")
  agent_truncate(paste(utils::tail(h, n), collapse = "\n\n"))
}

# --- code execution ----------------------------------------------------------

#' Evaluate code in this session.
#'
#' commit = FALSE (default) evaluates in a scratch environment whose parent is
#' globalenv(): reads fall through to your real data, assignments land in the
#' scratch env instead of overwriting your globals.
#'
#' This is a guard against accidents, NOT a security boundary. `<<-`,
#' assign(envir = globalenv()), file.remove() and system() all escape it.
agent_run_r <- function(code, commit = FALSE) {
  env    <- if (isTRUE(commit)) globalenv() else .agent_state$scratch
  before <- ls(env)
  notes  <- character(0)
  err    <- NULL

  printed <- utils::capture.output(
    withCallingHandlers(
      tryCatch({
        for (e in parse(text = code)) {
          res <- withVisible(eval(e, envir = env))
          if (res$visible) print(res$value)
        }
      }, error = function(e) err <<- paste0("Error: ", conditionMessage(e))),
      warning = function(w) {
        notes <<- c(notes, paste0("Warning: ", conditionMessage(w)))
        invokeRestart("muffleWarning")
      },
      message = function(m) {
        notes <<- c(notes, paste0("Message: ", trimws(conditionMessage(m))))
        invokeRestart("muffleMessage")
      }
    )
  )

  created <- setdiff(ls(env), before)
  delta <- if (length(created)) {
    sprintf("[created in %s: %s]",
            if (isTRUE(commit)) "global env" else "scratch env",
            paste(created, collapse = ", "))
  } else character(0)

  out <- agent_truncate(c(printed, notes, err, delta))
  agent_log_entry(paste0("[agent] ", gsub("[[:space:]]+", " ", code)), out)
  if (nzchar(out)) out else "(no output)"
}

# --- plots -------------------------------------------------------------------

#' Write the current plot to PNG inside the project and return its path.
#' Project-relative so the path falls inside the agent's normal file access;
#' tempdir() produces paths some agents cannot open.
agent_last_plot <- function() {
  if (is.null(grDevices::dev.list())) {
    return("No active plot device -- draw a plot first.")
  }
  dir.create(AGENT_PLOT_DIR, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(AGENT_PLOT_DIR, format(Sys.time(), "plot-%Y%m%d-%H%M%S.png"))

  ok <- tryCatch({
    grDevices::dev.copy(grDevices::png, filename = path,
                        width = 1000, height = 700, res = 120)
    grDevices::dev.off()
    TRUE
  }, error = function(e) FALSE)

  if (!ok || !file.exists(path)) "Could not copy the current plot device." else path
}

# --- ellmer tool wrappers ----------------------------------------------------
# Only defined when ellmer is available, so this file stays sourceable (and
# testable) in a plain R session with nothing installed.

agent_tools <- function() {
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    stop("ellmer is not installed. Run setup.R first.", call. = FALSE)
  }

  list(
    ellmer::tool(
      agent_console_history,
      name = "get_console_history",
      description = paste(
        "Recent commands run in the user's live R console and their printed",
        "output, including errors. Use this to see what the user just tried",
        "and what went wrong before suggesting a fix."
      ),
      arguments = list(
        n = ellmer::type_integer("How many recent entries to return. Default 20.",
                                 required = FALSE)
      )
    ),

    ellmer::tool(
      agent_run_r,
      name = "run_r",
      description = paste(
        "Evaluate R code in the user's live session and return printed output,",
        "warnings, messages and errors. By default assignments go to a scratch",
        "environment and do NOT modify the user's global environment; reads of",
        "existing objects work normally. Pass commit = TRUE only when the user",
        "wants the result kept in their global environment."
      ),
      arguments = list(
        code   = ellmer::type_string("R code to evaluate."),
        commit = ellmer::type_boolean(
          "TRUE to assign into the global environment instead of the scratch environment.",
          required = FALSE
        )
      )
    ),

    ellmer::tool(
      agent_last_plot,
      name = "get_last_plot",
      description = paste(
        "Save the plot currently displayed in RStudio to a PNG file and return",
        "its path, so it can be opened and looked at."
      ),
      arguments = list()
    )
  )
}
