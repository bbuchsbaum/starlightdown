\name{full_describe}
\alias{full_describe}
\alias{full_describe.default}
\title{Describe an object in one line}
\usage{
full_describe(x, ...)

\method{full_describe}{default}(x, ...)
}
\arguments{
\item{x}{An object to describe.}

\item{...}{Passed on to methods.}
}
\value{
A length-one character vector.
}
\description{
Returns a one-line summary of \code{x}. The default method reports the class
and the length.
}
\examples{
full_describe(1:5)
full_describe("a")
}
