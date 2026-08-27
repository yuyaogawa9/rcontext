\name{rcontext_tools}
\alias{rcontext_tools}
\title{Tools exposed to the coding agent}
\usage{
rcontext_tools()
}
\value{
A list of \code{ellmer::tool()} objects.
}
\description{
Returns the list of \code{ellmer::tool()} definitions that
\code{\link{mcp_server}()} serves. Exported so you can compose your own
server, or add these to an existing \code{ellmer} chat client.
}
\details{
The tools are \code{describe_environment}, \code{describe_data_frame},
\code{get_console_history}, \code{run_r} and \code{get_last_plot}.

Tool descriptions are written for the agent, not for you: they say when to
reach for each tool, because a tool an agent does not know when to call is the
same as one that is not there.
}
\section{Security}{
\code{run_r} evaluates model-supplied code in your session. See the package
help for what its sandbox does and does not protect against.
}
\examples{
\dontrun{
# serve a subset yourself
mcptools::mcp_server(tools = rcontext_tools()[1:2])
}
}
