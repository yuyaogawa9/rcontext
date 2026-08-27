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
}

The two caps exist so that printing a large object cannot bury the agent's
context window; responses that hit a cap say so explicitly, so the agent
narrows its query rather than assuming it saw everything.
}
