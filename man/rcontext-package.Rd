\name{rcontext-package}
\alias{rcontext}
\alias{rcontext-package}
\docType{package}
\title{Make Your Live R Session Visible to Terminal Coding Agents}
\description{
Terminal coding agents such as Claude Code and GitHub Copilot CLI run in a
separate process from R, so they cannot see the objects you have loaded, the
commands you have run, or the errors those commands threw. This package
exposes that session state to them over the Model Context Protocol.

Run \code{\link{setup}()} once. It arranges for every future interactive R
session to register itself, and tells each agent CLI on your PATH how to
reach it.
}
\section{Security}{
\code{\link{rcontext_tools}()} includes a \code{run_r} tool, which lets a
language model evaluate R code in your live session. By default assignments
land in a scratch environment rather than your global environment, but that
is a guard against accidents and \emph{not} a security boundary: \code{<<-},
\code{assign(envir = globalenv())}, \code{file.remove()} and \code{system()}
all escape it. If that is not acceptable to you, serve a subset of the tools
instead of the full list.
}
\seealso{
\code{\link{setup}}, \code{\link{start}}, \code{\link{mcp_server}},
\code{\link{rcontext_tools}}
}
\author{Yuya Ogawa}
