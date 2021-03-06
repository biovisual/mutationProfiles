% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/mutSigs.R
\name{mutSigs}
\alias{mutSigs}
\title{mutSigs}
\usage{
mutSigs(..., snv_data = NULL, samples = NULL, pie = FALSE,
  write = FALSE)
}
\arguments{
\item{samples}{Calculates and plots mutational signatures on a per-sample basis [Default no]}

\item{pie}{Plot a pie chart shwoing contribution of each signature to overall profile [Default no]}
}
\description{
Calculate and plot the mutational signatures accross samples using the package `deconstructSigs`
}
\keyword{signatures}
