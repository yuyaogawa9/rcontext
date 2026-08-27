# Code execution ---------------------------------------------------------------

#' Evaluate code in the live session
#'
#' `commit = FALSE` (the default) evaluates in a scratch environment whose
#' parent is the global environment: reads of existing objects fall through
#' normally, but assignments land in the scratch environment rather than
#' overwriting the user's globals.
#'
#' This is a guard against accidents, **not** a security boundary. `<<-`,
#' `assign(envir = globalenv())`, `file.remove()` and `system()` all escape it
#' trivially. The package documentation says so plainly and so should any
#' description of this function.
#'
#' @noRd
run_code <- function(code, commit = FALSE) {
  env <- if (isTRUE(commit)) globalenv() else scratch_env()
  before <- ls(env)
  notes <- character(0)
  err <- NULL

  # capture.output() wraps the whole evaluation, not just the final value, so
  # cat()/print() side effects and anything printed before an error survive.
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
    sprintf(
      "[created in %s: %s]",
      if (isTRUE(commit)) "global env" else "scratch env",
      paste(created, collapse = ", ")
    )
  } else {
    character(0)
  }

  out <- truncate_output(c(printed, notes, err, delta))
  log_entry(paste0("[agent] ", gsub("[[:space:]]+", " ", code)), out)
  if (nzchar(out)) out else "(no output)"
}
