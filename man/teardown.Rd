\name{teardown}
\alias{teardown}
\title{Undo setup()}
\usage{
teardown(agents = c("claude", "copilot"), rprofile = path.expand("~/.Rprofile"))
}
\arguments{
\item{agents}{Agent CLIs to unregister from.}

\item{rprofile}{Path to the startup file to modify.}
}
\value{
Invisibly, a list recording what was removed.
}
\description{
Removes the startup block from your \code{~/.Rprofile} and unregisters the MCP
server from each agent CLI found on \code{PATH}. Lines you wrote yourself are
left exactly as they were.
}
\examples{
\dontrun{
rcontext::teardown()
}
}
