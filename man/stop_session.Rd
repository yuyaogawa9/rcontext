\name{stop_session}
\alias{stop_session}
\title{Stop exposing this session}
\usage{
stop_session()
}
\value{
Invisibly \code{TRUE}.
}
\description{
Removes the console hook installed by \code{\link{start}()} and clears the
recorded history. The error handler registered through
\code{globalCallingHandlers()} cannot be selectively removed and stays for the
life of the session; it is inert once nothing reads the log.
}
