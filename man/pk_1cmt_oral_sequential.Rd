% Generated by roxygen2 (4.1.0): do not edit by hand
% Please edit documentation in R/pk_1cmt_oral_sequential.R
\name{pk_1cmt_oral_sequential}
\alias{pk_1cmt_oral_sequential}
\title{ODE system for PK - 1 compartment oral administration with sequential zero and 1st order absorption}
\usage{
pk_1cmt_oral_sequential(t, A, p)
}
\description{
ODE system for PK - 1 compartment oral administration with sequential zero and 1st order absorption
}
\examples{
library(PKPDsim)

p <- list(CL = 38.48,
          V  = 7.4,
          KA = .3,
          K0 = 4,
          K0_T = 1)

r1 <- new_regimen(amt = 100,
                  interval = 24,
                  n = 10)

omega <- cv_to_omega (list(CL = 0.3,
                           V = 0.3,
                           KA = 0.1,
                           K0 = .1,
                           K0_T = .3), p)

## sequential k0 and ka
sim_ode_shiny(ode = "pk_1cmt_oral_sequential",
              par = p,
              regimen = new_regimen(amt=30),
              omega = omega)
}

