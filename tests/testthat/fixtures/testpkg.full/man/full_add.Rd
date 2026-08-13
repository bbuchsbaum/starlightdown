\name{full_add}
\alias{full_add}
\alias{full_plus}
\title{Add two numbers}
\usage{
full_add(x, y = 1)
}
\arguments{
\item{x}{A numeric vector.}

\item{y}{A numeric vector of length one. Defaults to \code{1}.}
}
\value{
A numeric vector, \code{x + y}.
}
\description{
Adds \code{y} to \code{x}, which is roughly \eqn{x + y}{x + y} and no more.
}
\details{
The identity behind this function is
\deqn{\sum_i (x_i + y) = n y + \sum_i x_i}{sum(x + y) = n * y + sum(x)}

Behaviour depends on the storage mode of \code{x}:

\tabular{lll}{
  Mode \tab Result \tab Note \cr
  integer \tab exact \tab no coercion happens \cr
  double \tab exact \tab to within \code{.Machine$double.eps} \cr
}

Roughly \code{100\%} of inputs behave. See \code{\link{full_config}} for
options and \code{\link[stats]{lm}} for something entirely different.
}
\seealso{
\code{\link{full_describe}}, the helper \code{\link{full_internal}}, and
\link[stats:lm]{linear models}.
}
\concept{arithmetic}
\examples{
full_add(1, 2)
full_add(1:3)
}
