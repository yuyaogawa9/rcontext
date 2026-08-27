# One-time setup ---------------------------------------------------------------

marker_start <- "# >>> rcontext >>>"
marker_end   <- "# <<< rcontext <<<"

startup_block <- function() {
  c(
    marker_start,
    'if (interactive() &&',
    '    !nzchar(Sys.getenv("RCONTEXT_DISABLE")) &&',
    '    requireNamespace("rcontext", quietly = TRUE)) {',
    '  rcontext::start()',
    '}',
    marker_end
  )
}

block_bounds <- function(lines) {
  i <- which(lines == marker_start)
  j <- which(lines == marker_end)
  if (length(i) != 1L || length(j) != 1L || j < i) return(NULL)
  c(i, j)
}

has_block <- function(path) {
  if (!file.exists(path)) return(FALSE)
  !is.null(block_bounds(readLines(path, warn = FALSE)))
}

add_block <- function(path) {
  lines <- if (file.exists(path)) readLines(path, warn = FALSE) else character(0)
  if (!is.null(block_bounds(lines))) return(invisible(FALSE))  # already there
  sep <- if (length(lines) && nzchar(utils::tail(lines, 1L))) "" else character(0)
  writeLines(c(lines, sep, startup_block()), path)
  invisible(TRUE)
}

remove_block <- function(path) {
  if (!file.exists(path)) return(invisible(FALSE))
  lines <- readLines(path, warn = FALSE)
  at <- block_bounds(lines)
  if (is.null(at)) return(invisible(FALSE))

  keep <- lines[-seq(at[1], at[2])]
  # drop the single blank separator add_block() may have inserted before it
  if (at[1] > 1L && length(keep) >= at[1] - 1L && !nzchar(keep[at[1] - 1L])) {
    keep <- keep[-(at[1] - 1L)]
  }
  writeLines(keep, path)
  invisible(TRUE)
}

# Agent CLIs -------------------------------------------------------------------

server_command <- c("Rscript", "-e", "rcontext::mcp_server()")

agent_args <- function(cli, action) {
  switch(paste(cli, action),
    "claude add"     = c("mcp", "add", "-s", "user", "rcontext", "--", server_command),
    "claude remove"  = c("mcp", "remove", "-s", "user", "rcontext"),
    "copilot add"    = c("mcp", "add", "rcontext", "--", server_command),
    "copilot remove" = c("mcp", "remove", "rcontext"),
    NULL
  )
}

found_agents <- function(agents) {
  agents[nzchar(Sys.which(agents))]
}

run_agent <- function(cli, action) {
  args <- agent_args(cli, action)
  if (is.null(args)) return(FALSE)
  out <- suppressWarnings(
    tryCatch(system2(cli, args, stdout = TRUE, stderr = TRUE),
             error = function(e) structure("", status = 1L))
  )
  status <- attr(out, "status")
  is.null(status) || identical(status, 0L)
}

# Public -----------------------------------------------------------------------

#' Set up rcontext once, for every project
#'
#' Does the two things a package alone cannot: arranges for future R sessions
#' to register themselves, and tells your coding agents how to reach them.
#'
#' Specifically it
#'
#' 1. appends a small guarded block to your `~/.Rprofile`, between markers, so
#'    every interactive R session calls [start()]; and
#' 2. registers `rcontext` as an MCP server with each agent CLI it finds on
#'    your `PATH`, at user scope, by calling that CLI's own `mcp add` command.
#'
#' It shows you both changes and asks before making them. [teardown()] reverses
#' them. Re-running `setup()` is safe: the startup block is added at most once.
#'
#' @param agents Agent CLIs to register with. Ones not found on `PATH` are
#'   skipped with a note.
#' @param rprofile Path to the startup file to modify. Exposed for testing;
#'   there is no reason to change it.
#' @return Invisibly, a list recording what changed.
#' @export
#' @examples
#' \dontrun{
#' rcontext::setup()
#' }
setup <- function(agents = c("claude", "copilot"),
                  rprofile = path.expand("~/.Rprofile")) {
  if (!interactive()) {
    stop("setup() modifies files in your home directory and only runs in an ",
         "interactive session. Start R and call rcontext::setup().",
         call. = FALSE)
  }

  present <- found_agents(agents)
  already <- has_block(rprofile)

  message("rcontext::setup() will make these changes:\n")
  if (already) {
    message("  ~/.Rprofile   already has the rcontext block -- unchanged")
  } else if (file.exists(rprofile)) {
    message("  ", rprofile, "\n                append a 6-line block between rcontext markers")
  } else {
    message("  ", rprofile, "\n                create it, containing only the rcontext block")
  }

  if (length(present)) {
    for (a in present) {
      message("  ", a, "        register MCP server 'rcontext' at user scope")
    }
  } else {
    message("  (no agent CLI found on PATH -- nothing to register)")
  }

  missing_cli <- setdiff(agents, present)
  if (length(missing_cli)) {
    message("\n  not found, skipping: ", paste(missing_cli, collapse = ", "))
  }

  ans <- utils::askYesNo("\nProceed?", default = FALSE)
  if (!isTRUE(ans)) {
    message("Nothing changed.")
    return(invisible(list(rprofile = FALSE, agents = character(0))))
  }

  wrote <- add_block(rprofile)
  registered <- present[vapply(present, run_agent, logical(1), action = "add")]
  failed <- setdiff(present, registered)

  message("")
  message(if (wrote) "  wrote startup block" else "  startup block already present")
  for (a in registered) message("  registered with ", a)
  for (a in failed) {
    message("  could not register with ", a, " -- run this yourself:")
    message("    ", a, " ", paste(agent_args(a, "add"), collapse = " "))
  }

  message("\nNext: restart R (Session > Restart R), then start an agent in a ",
          "terminal and ask it what data frames you have loaded.")

  invisible(list(rprofile = wrote, agents = registered))
}

#' Undo setup()
#'
#' Removes the startup block from your `~/.Rprofile` and unregisters the MCP
#' server from each agent CLI found on `PATH`. Lines you wrote yourself are
#' left exactly as they were.
#'
#' @inheritParams setup
#' @return Invisibly, a list recording what was removed.
#' @export
#' @examples
#' \dontrun{
#' rcontext::teardown()
#' }
teardown <- function(agents = c("claude", "copilot"),
                     rprofile = path.expand("~/.Rprofile")) {
  removed <- remove_block(rprofile)
  present <- found_agents(agents)
  unregistered <- present[vapply(present, run_agent, logical(1), action = "remove")]

  message(if (removed) "  removed startup block from ~/.Rprofile"
          else "  no rcontext block found in ~/.Rprofile")
  for (a in unregistered) message("  unregistered from ", a)

  failed <- setdiff(present, unregistered)
  for (a in failed) {
    message("  could not unregister from ", a, " -- run this yourself:")
    message("    ", a, " ", paste(agent_args(a, "remove"), collapse = " "))
  }

  invisible(list(rprofile = removed, agents = unregistered))
}
