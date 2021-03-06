% Generated by roxygen2 (4.1.0): do not edit by hand
% Please edit documentation in R/sim_ode.R
\name{sim_ode}
\alias{sim_ode}
\title{Simulate ODE}
\usage{
sim_ode(ode = NULL, dde = NULL, parameters = list(), omega = NULL,
  omega_type = "exponential", n_ind = 1, regimen = NULL,
  adherence = NULL, covariates = NULL, covariate_model = NULL,
  A_init = NULL, step_size = 0.25, t_max = NULL, t_obs = NULL,
  t_tte = NULL, rtte = FALSE, output_cmt = NULL)
}
\arguments{
\item{ode}{function describing the ODE system}

\item{parameters}{}

\item{omega}{vector describing the lower-diagonal of the between-subject variability matrix}

\item{omega_type}{exponential or normal}

\item{n_ind}{number of individuals to simulate}

\item{regimen}{a regimen object created using the regimen() function}

\item{adherence}{List specifying adherence. Simulates adherence using either markov model or binomial sampling.}

\item{A_init}{vector with the initial state of the ODE system}

\item{step_size}{the step size between the observations (NOT the step size of the differential equation solver)}

\item{t_max}{maximum simulation time, if not specified will pick the end of the regimen as maximum}

\item{t_obs}{vector of observation times, only output these values}

\item{t_tte}{vector of observation times for time-to-event simulation}

\item{rtte}{should repeated events be allowed (FALSE by default)}

\item{output}{vector specifying which compartment numbers to output}
}
\value{
a data frame of compartments with associated concentrations at requested times
}
\description{
Simulates a specified ODE system and regimen
}
\examples{
library(ggplot2)
library(PKPDsim)
p <- list(CL = 38.48,
         V  = 7.4,
         Q2 = 7.844,
         V2 = 5.19,
         Q3 = 9.324,
         V3 = 111)

r1 <- new_regimen(amt = 100,
             times = c(0, 24, 36),
             type = "infusion")

dat <- sim_ode (ode = "pk_3cmt_iv",
               par = p,
               regimen = r1)

ggplot(dat, aes(x=t, y=y)) +
 geom_line() +
 scale_y_log10() +
 facet_wrap(~comp)

# repeat with IIV:
omega <- c(0.3,       # IIV CL
          0.1, 0.3)  # IIV V

dat <- sim_ode (ode = "pk_3cmt_iv",
               par = p,
               omega = omega,
               n_ind = 20,
               regimen = r1)

ggplot(dat, aes(x=t, y=y, colour=factor(id), group=id)) +
 geom_line() +
 scale_y_log10() +
 facet_wrap(~comp)
}
\seealso{
\link{sim_ode_shiny}
}

