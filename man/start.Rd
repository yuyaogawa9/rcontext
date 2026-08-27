\name{start}
\alias{start}
\title{Make this R session visible to coding agents}
\usage{
start()
}
\value{
Invisibly \code{TRUE} if the session was registered, \code{FALSE} if it was
already registered or the session is not interactive.
}
\description{
Installs the console and error hooks, then registers the session with the MCP
broker via \code{mcptools::mcp_session()}. After this, an agent started in a
terminal can read this session's objects, history and plots.
}
\details{
You do not normally call this yourself: \code{\link{setup}()} arranges for it
to run at the start of every interactive R session. Call it by hand if you
skipped \code{setup()}, or after \code{Session > Restart R} if you disabled
the hook.

Idempotent --- calling it twice in one session does nothing the second time.
}
\examples{
\dontrun{
rcontext::start()
}
}
