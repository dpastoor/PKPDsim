% Generated by roxygen2 (4.1.0): do not edit by hand
% Please edit documentation in R/pk_1cmt_oral_transit.R
\name{pk_1cmt_oral_transit}
\alias{pk_1cmt_oral_transit}
\title{ODE system for PK - 1 compartment oral administration using transit model}
\usage{
pk_1cmt_oral_transit(t, A, p)
}
\description{
ODE system for PK - 1 compartment oral administration using transit model
}
\examples{
library(PKPDsim)

p_tr <- list(CL = 17.2,
            V  = 45.1,
            KA = 0.38,
            MTT = 2,
            N = 20.1,
            F = 0) # don't forget to set F=0!

omega <- cv_to_omega (list(CL = 0.3,
                          V = 0.3,
                          KA = 0.1,
                          N = 0.3,
                          MTT = 0.3), p_tr)

sim_ode_shiny(ode = "pk_1cmt_oral_transit",
             par = p_tr,
             regimen = new_regimen(amt=100, interval=24, n = 1),
             omega = omega)
}

