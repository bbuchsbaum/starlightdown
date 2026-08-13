\name{full_plot}
\alias{full_plot}
\title{Plot a sequence}
\usage{
full_plot(n = 10)
}
\arguments{
\item{n}{Number of points to draw.}
}
\value{
Invisibly, \code{n}.
}
\description{
Draws a scatter plot of \code{seq_len(n)}.
}
\examples{
full_plot(10)

plot(1:10, main = "a second figure")
}
