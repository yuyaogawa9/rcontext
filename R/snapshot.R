# File-based fallback --------------------------------------------------------
#
# The broker reaches the session over a local socket. Some corporate endpoint
# security blocks that socket, and then no live channel is left at all. What
# still works is a file in the project: an agent that cannot read files is
# useless, so those are never blocked. These two functions write into
# `.rcontext/` -- already git-ignored by setup() -- so a blocked agent can read
# the session state and load its objects instead of guessing from `.R` files.

#' Mirror the session state into `.rcontext/session.md`
#'
#' Rewritten after every top-level command by the same console hook that
#' maintains the history (via [log_entry]), so it is never more than one
#' command stale. The content is what `describe_environment` and
#' `get_console_history` would return, for an agent that has neither.
#'
#' Writes into the working directory, like [get_last_plot], because agents
#' often cannot open files outside the project they were started in. Any
#' failure is swallowed: refreshing a fallback file is never worth disrupting
#' the user's console for.
#'
#' @noRd
write_session_snapshot <- function(path = opt_session_file()) {
  tryCatch(suppressWarnings({
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    writeLines(c(
      "# R session snapshot",
      "",
      "Written by rcontext after every top-level command. When the rcontext MCP",
      "tools are unavailable, read this instead of guessing from `.R` files --",
      "it is what `describe_environment` and `get_console_history` would return.",
      "",
      paste0("_Updated ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "._"),
      "",
      "## Environment",
      "",
      describe_env(),
      "",
      "## Console history",
      "",
      console_history(opt_history())
    ), path)
  }), error = function(e) NULL)
  invisible(NULL)
}

#' Export objects for analysis outside the live session
#'
#' Writes one `.rds` file per named object into `.rcontext/objects/`. When the
#' MCP broker cannot reach your session, an agent can still start its own
#' `Rscript`, `readRDS()` one of these files and analyse the copy, without ever
#' touching your session. Read-only by construction.
#'
#' Object selection is explicit and never automatic. Serialising a dataset to
#' disk in a corporate setting is a data-governance decision, so this writes
#' only the objects you name, and skips any larger than `max_size`.
#'
#' The files land under `.rcontext/`, which [setup()] leaves git-ignored.
#'
#' @param ... Objects to export, named or quoted: `export(model, penguins)` or
#'   `export("model", "penguins")`.
#' @param max_size Per-object ceiling in bytes. A larger object is skipped with
#'   a message rather than written. Default 50 MB.
#' @param dir Destination directory. Defaults to `.rcontext/objects`.
#' @return Invisibly, the paths written.
#' @export
#' @examples
#' \dontrun{
#' rcontext::export(model, penguins)
#' }
export <- function(..., max_size = 50 * 1024^2, dir = opt_object_dir()) {
  quoted <- as.list(substitute(list(...)))[-1L]
  names <- vapply(quoted, function(e) if (is.character(e)) e else deparse(e),
                  character(1))

  if (length(names) == 0L) {
    message("export(): name at least one object, e.g. export(my_data).")
    return(invisible(character(0)))
  }

  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  written <- character(0)

  for (nm in names) {
    if (!exists(nm, envir = globalenv(), inherits = FALSE)) {
      message("  skipped ", nm, " -- no such object in the global environment")
      next
    }
    obj <- get(nm, envir = globalenv())
    size_txt <- format(utils::object.size(obj), units = "auto")
    if (as.numeric(utils::object.size(obj)) > max_size) {
      message(sprintf(
        "  skipped %s -- %s exceeds the %.0f MB cap (raise max_size to override)",
        nm, size_txt, max_size / 1024^2
      ))
      next
    }
    file <- file.path(dir, paste0(gsub("[^A-Za-z0-9._-]", "_", nm), ".rds"))
    saveRDS(obj, file)
    written <- c(written, file)
    message(sprintf("  wrote %s (%s)", file, size_txt))
  }

  invisible(written)
}
