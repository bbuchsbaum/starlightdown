\name{full_config}
\alias{full_config}
\title{Configure \sdpkg}
\usage{
full_config(...)
}
\arguments{
\item{...}{Named options. The recognised names are:
\describe{
  \item{digits}{Number of digits to print.}
  \item{quiet}{Whether to suppress messages.}
}}
}
\value{
A named list of resolved options.
}
\description{
Collects options for \sdpkg and fills in the defaults.
}
\details{
Options are resolved in this order:
\enumerate{
  \item explicit arguments to \code{full_config()},
  \item the session default,
  \item the package default.
}

Unrecognised names are:
\itemize{
  \item silently kept, and
  \item never validated.
}
}
\section{Stability, and one's expectations}{
The set of recognised options is \sdstage{not} frozen.
}
\examples{
full_config(digits = 5)
}
