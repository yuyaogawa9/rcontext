# Session registration and the broker ------------------------------------------

#' Make this R session visible to coding agents
#'
#' Installs the console and error hooks, then registers the session with the
#' MCP broker via [mcptools::mcp_session()]. After this, an agent started in a
#' terminal can read this session's objects, history and plots.
#'
#' You do not normally call this yourself: [setup()] arranges for it to run at
#' the start of every interactive R session. Call it by hand if you skipped
#' `setup()`, or after `Session > Restart R` if you disabled the hook.
#'
#' Idempotent — calling it twice in one session does nothing the second time.
#'
#' @return Invisibly `TRUE` if the session was registered, `FALSE` if it was
#'   already registered or the session is not interactive.
#' @export
#' @examples
#' \dontrun{
#' rcontext::start()
#' }
start <- function() {
  if (!interactive()) {
    return(invisible(FALSE))
  }
  if (isTRUE(the$hooked)) {
    return(invisible(FALSE))
  }

  install_hooks()

  # mcp_session() opens a socket the broker connects back to. A failure here
  # should never stop the user's session from starting.
  ok <- tryCatch({
    mcptools::mcp_session()
    TRUE
  }, error = function(e) {
    warning("rcontext: could not register this session (", conditionMessage(e), ")",
            call. = FALSE)
    FALSE
  })

  invisible(ok)
}

#' Stop exposing this session
#'
#' Removes the console hook installed by [start()]. The error handler
#' registered through `globalCallingHandlers()` cannot be selectively removed
#' and stays for the life of the session; it is inert once nothing reads the
#' log.
#'
#' @return Invisibly `TRUE`.
#' @export
stop_session <- function() {
  remove_hooks()
  the$history <- character(0)
  invisible(TRUE)
}

#' Run the MCP server
#'
#' The broker process. This is what agent configurations run; it blocks and is
#' not meant to be called interactively.
#'
#' Because it resolves through the installed package rather than a file path,
#' the agent can be started from any directory — unlike a configuration that
#' has to `source()` a script relative to the working directory.
#'
#' @param tools Tool list to serve. Defaults to [rcontext_tools()].
#' @return Does not return; blocks serving the protocol.
#' @export
#' @examples
#' \dontrun{
#' # this is the command registered with the agent:
#' # Rscript -e "rcontext::mcp_server()"
#' }
mcp_server <- function(tools = rcontext_tools()) {
  mcptools::mcp_server(tools = tools)
}
