\name{mcp_server}
\alias{mcp_server}
\title{Run the MCP server}
\usage{
mcp_server(tools = rcontext_tools())
}
\arguments{
\item{tools}{Tool list to serve. Defaults to \code{\link{rcontext_tools}()}.}
}
\value{
Does not return; blocks serving the protocol.
}
\description{
The broker process. This is what agent configurations run; it blocks and is
not meant to be called interactively.
}
\details{
Because it resolves through the installed package rather than a file path, the
agent can be started from any directory --- unlike a configuration that has to
\code{source()} a script relative to the working directory.
}
\examples{
\dontrun{
# this is the command registered with the agent:
# Rscript -e "rcontext::mcp_server()"
}
}
