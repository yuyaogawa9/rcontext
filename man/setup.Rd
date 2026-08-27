\name{setup}
\alias{setup}
\title{Set up rcontext once, for every project}
\usage{
setup(agents = c("claude", "copilot"), rprofile = path.expand("~/.Rprofile"))
}
\arguments{
\item{agents}{Agent CLIs to register with. Ones not found on \code{PATH} are
skipped with a note.}

\item{rprofile}{Path to the startup file to modify. Exposed for testing;
there is no reason to change it.}
}
\value{
Invisibly, a list recording what changed.
}
\description{
Does the two things a package alone cannot: arranges for future R sessions to
register themselves, and tells your coding agents how to reach them.
}
\details{
Specifically it
\enumerate{
\item appends a small guarded block to your \code{~/.Rprofile}, between
markers, so every interactive R session calls \code{\link{start}()}; and
\item registers \code{rcontext} as an MCP server with each agent CLI it finds
on your \code{PATH}, at user scope, by calling that CLI's own \code{mcp add}
command.
}

It shows you both changes and asks before making them.
\code{\link{teardown}()} reverses them. Re-running \code{setup()} is safe: the
startup block is added at most once.
}
\examples{
\dontrun{
rcontext::setup()
}
}
