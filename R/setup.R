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

# Skills -----------------------------------------------------------------------
#
# Registering the MCP server puts five tools in front of the agent with no
# surrounding context, which is not the same as the agent knowing when to reach
# for them. The skill supplies that. The two CLIs take it differently: copilot
# can register a directory of skills, so we hand it the packaged one and an
# upgrade updates the skill in place; claude has no such command, so the file is
# copied into its skills directory and refreshed on every setup().

skill_source <- function() {
  system.file("skills", package = "rcontext")
}

claude_skill_dir <- function(claude_dir) {
  file.path(claude_dir, "skills", "rcontext")
}

install_claude_skill <- function(claude_dir) {
  src <- file.path(skill_source(), "rcontext", "SKILL.md")
  if (!nzchar(skill_source()) || !file.exists(src)) return(FALSE)

  dest <- claude_skill_dir(claude_dir)
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)
  file.copy(src, file.path(dest, "SKILL.md"), overwrite = TRUE)
}

remove_claude_skill <- function(claude_dir) {
  dest <- claude_skill_dir(claude_dir)
  if (!dir.exists(dest)) return(FALSE)
  unlink(dest, recursive = TRUE)
  !dir.exists(dest)
}

skill_action <- function(agents, claude_dir, action) {
  if (!nzchar(skill_source())) return(character(0))

  ok <- vapply(agents, function(a) {
    if (identical(a, "claude")) {
      isTRUE(switch(action,
        add    = install_claude_skill(claude_dir),
        remove = remove_claude_skill(claude_dir)
      ))
    } else {
      run_agent(a, paste0("skill_", action))
    }
  }, logical(1))

  agents[ok]
}

# Agent CLIs -------------------------------------------------------------------

server_command <- c("Rscript", "-e", "rcontext::mcp_server()")

agent_args <- function(cli, action) {
  switch(paste(cli, action),
    "claude add"     = c("mcp", "add", "-s", "user", "rcontext", "--", server_command),
    "claude remove"  = c("mcp", "remove", "-s", "user", "rcontext"),
    "copilot add"    = c("mcp", "add", "rcontext", "--", server_command),
    "copilot remove" = c("mcp", "remove", "rcontext"),
    "copilot skill_add"    = c("skill", "add", skill_source()),
    "copilot skill_remove" = c("skill", "remove", skill_source()),
    NULL
  )
}

found_agents <- function(agents) {
  agents[nzchar(Sys.which(agents))]
}

# system2() does not quote its arguments, and the server command contains
# parentheses, which the shell treats as syntax. Both the executed command and
# the one we print for the user to copy have to survive shell parsing.
run_agent <- function(cli, action) {
  args <- agent_args(cli, action)
  if (is.null(args)) return(FALSE)
  out <- suppressWarnings(
    tryCatch(system2(cli, shQuote(args), stdout = TRUE, stderr = TRUE),
             error = function(e) structure("", status = 1L))
  )
  status <- attr(out, "status")
  is.null(status) || identical(status, 0L)
}

#' A copy-pasteable command line, quoting only the arguments that need it
#' @noRd
agent_command_line <- function(cli, action) {
  args <- agent_args(cli, action)
  if (is.null(args)) return(NA_character_)
  needs_quote <- grepl("[^A-Za-z0-9_./:=-]", args)
  args[needs_quote] <- paste0('"', args[needs_quote], '"')
  paste(cli, paste(args, collapse = " "))
}

# Public -----------------------------------------------------------------------

#' Set up rcontext once, for every project
#'
#' Does the things a package alone cannot: arranges for future R sessions to
#' register themselves, tells your coding agents how to reach them, and tells
#' those agents when to bother.
#'
#' Specifically it
#'
#' 1. appends a small guarded block to your `~/.Rprofile`, between markers, so
#'    every interactive R session calls [start()];
#' 2. registers `rcontext` as an MCP server with each agent CLI it finds on
#'    your `PATH`, at user scope, by calling that CLI's own `mcp add` command;
#'    and
#' 3. installs a skill describing when to use the tools and how to read their
#'    output, so an agent reaches for your live session unprompted instead of
#'    guessing from your source files.
#'
#' It shows you every change and asks before making any of them. [teardown()]
#' reverses them. Re-running `setup()` is safe: the startup block is added at
#' most once, and the skill is refreshed from the installed package, so
#' upgrading `rcontext` and re-running picks up newer guidance.
#'
#' @param agents Agent CLIs to register with. Ones not found on `PATH` are
#'   skipped with a note.
#' @param rprofile Path to the startup file to modify. Exposed for testing;
#'   there is no reason to change it.
#' @param claude_dir Path to Claude Code's configuration directory, which is
#'   where its skill is written. Exposed for testing, as `rprofile` is.
#' @return Invisibly, a list recording what changed.
#' @export
#' @examples
#' \dontrun{
#' rcontext::setup()
#' }
setup <- function(agents = c("claude", "copilot"),
                  rprofile = path.expand("~/.Rprofile"),
                  claude_dir = path.expand("~/.claude")) {
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
      message("  ", a, "        install the 'rcontext' skill, so it knows when to use it")
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
  skilled <- skill_action(present, claude_dir, "add")
  skill_failed <- setdiff(present, skilled)

  message("")
  message(if (wrote) "  wrote startup block" else "  startup block already present")
  for (a in registered) message("  registered with ", a)
  for (a in failed) {
    message("  could not register with ", a, " -- run this yourself:")
    message("    ", agent_command_line(a, "add"))
  }
  for (a in skilled) message("  installed skill for ", a)
  for (a in skill_failed) {
    cl <- agent_command_line(a, "skill_add")
    if (is.na(cl)) {
      message("  could not install the skill for ", a)
    } else {
      message("  could not install the skill for ", a, " -- run this yourself:")
      message("    ", cl)
    }
  }

  message("\nNext: restart R (Session > Restart R), then start an agent in a ",
          "terminal and ask it what data frames you have loaded. Agents read ",
          "skills and MCP servers at startup, so quit any that are already ",
          "running.")

  invisible(list(rprofile = wrote, agents = registered, skills = skilled))
}

#' Undo setup()
#'
#' Removes the startup block from your `~/.Rprofile`, unregisters the MCP
#' server from each agent CLI found on `PATH`, and removes the skill that
#' [setup()] installed. Lines you wrote yourself are left exactly as they were.
#'
#' @inheritParams setup
#' @return Invisibly, a list recording what was removed.
#' @export
#' @examples
#' \dontrun{
#' rcontext::teardown()
#' }
teardown <- function(agents = c("claude", "copilot"),
                     rprofile = path.expand("~/.Rprofile"),
                     claude_dir = path.expand("~/.claude")) {
  removed <- remove_block(rprofile)
  present <- found_agents(agents)
  unregistered <- present[vapply(present, run_agent, logical(1), action = "remove")]
  deskilled <- skill_action(present, claude_dir, "remove")

  message(if (removed) "  removed startup block from ~/.Rprofile"
          else "  no rcontext block found in ~/.Rprofile")
  for (a in unregistered) message("  unregistered from ", a)

  failed <- setdiff(present, unregistered)
  for (a in failed) {
    message("  could not unregister from ", a, " -- run this yourself:")
    message("    ", agent_command_line(a, "remove"))
  }
  for (a in deskilled) message("  removed skill for ", a)

  invisible(list(rprofile = removed, agents = unregistered, skills = deskilled))
}
