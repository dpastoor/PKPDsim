% Generated by roxygen2 (4.1.0): do not edit by hand
% Please edit documentation in R/cv_to_omega.R
\name{cv_to_omega}
\alias{cv_to_omega}
\title{Create lower-diagonal omega matrix from CV for parameter estimates}
\usage{
cv_to_omega(par_cv = list(), par = list())
}
\arguments{
\item{par_cv}{list of parameter CVs}

\item{par}{list of parameters}
}
\value{
a vector describing the lower triangle of the omega (between-subject variability) matrix
}
\description{
Create lower-diagonal omega matrix from CV for parameter estimates
}
\seealso{
\link{sim_ode}
}

