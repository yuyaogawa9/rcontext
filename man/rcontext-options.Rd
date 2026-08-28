\name{rcontext-options}
\alias{rcontext-options}
\title{Options}
\description{
\code{rcontext} reads these options, all of which have defaults:
\itemize{
\item \code{rcontext.max_lines} (200) --- maximum lines in a single tool response.
\item \code{rcontext.max_chars} (8000) --- maximum characters in a single tool response.
\item \code{rcontext.history} (100) --- console entries retained.
\item \code{rcontext.plot_dir} (".rcontext/plots") --- where \code{get_last_plot} writes PNGs.
\item \code{rcontext.session_file} (".rcontext/session.md") --- where the console
hook mirrors the session state for agents that cannot reach the MCP server.
\item \code{rcontext.object_dir} (".rcontext/objects") --- where \code{export} writes
\code{.rds} files.
\item \code{rcontext.bridge_cmd} (".rcontext/command.R") --- file \code{bridge} reads
code from.
\item \code{rcontext.bridge_result} (".rcontext/result.txt") --- file \code{bridge}
writes output to.
}

The two caps exist so that printing a large object cannot bury the agent's
context window; responses that hit a cap say so explicitly, so the agent
narrows its query rather than assuming it saw everything.
}
