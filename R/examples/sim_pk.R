install_github("ronkeizer/PKPDsim")
library(PKPDsim)
library(ggplot2)
library(Rcpp)
library(inline)
settings <- getPlugin("Rcpp")
settings$env$CC <- "g++"

p <- list(CL = 5,
          V  = 50,
          KA = .2)

r1 <- new_regimen(amt = 100,
                  type = "infusion",
                  t_inf = 12,
                  interval = 24,
                  n = 2)

# cov_model <- new_covariate_model(list("CL" = f_cov( par * (WT/70)^0.75 ),
#                                       "V"  = f_cov( par * (WT/70)      )))
# covariates <- data_frame("WT" = seq(from=40, to=120, by=5))

#for(i in 1:10) {
system.time({
  dat <- sim_ode (ode = "pk_1cmt_iv",
                  n_ind = 1,
                  omega = cv_to_omega(par_cv = list("CL"=0.1, "V"=0.1), p),
                  par = p,
                  regimen = r1,
                  cpp = TRUE, cpp_recompile = TRUE, cpp_show_function = FALSE)
})
ggplot(dat, aes(x=t, y=y, group=id)) +
  geom_line() +
  facet_wrap(~comp, scales="free")

dat <- sim_ode (ode = "pk_1cmt_iv_mm",
                  n_ind = 10000,
                  omega = cv_to_omega(par_cv = list("VMAX"=0.1, "KM"=0.1), p),
                  par = list(VMAX=20, V=50, KM=5),
                  regimen = r1,
                  cpp = TRUE, cpp_recompile = FALSE, cpp_show_function = FALSE)
ggplot(dat, aes(x=t, y=y, group=id)) +
  geom_line() + scale_y_log10() +
  facet_wrap(~comp, scales="free")


system.time({
  dat2 <- sim_ode (ode = "pk_1cmt_oral",
                   step_size = 1,
                   par = p,
                n_ind = 100,
                regimen = r1,
                cpp = TRUE, cpp_recompile=TRUE)
})
ggplot(dat2, aes(x=t, y=y, group=id)) +
  geom_line() +
  facet_wrap(~comp, scales="free")


system.time({
  for(i in 1:100) {
    dat <- sim_ode (ode = "pk_1cmt_oral",
                    par = p,
                    regimen = r1,
                    cpp = TRUE, cpp_recompile=FALSE)
  }
})
system.time({
  for(i in 1:100) {
    dat <- sim_ode (ode = "pk_1cmt_oral",
                    par = p,
                    regimen = r1,
                    cpp = FALSE)
  }
})


# Plots
ggplot(dat, aes(x=t, y=y, group=id)) +
  geom_line() +
  facet_wrap(~comp, scales="free")

####
p <- list(CL = 38.48,
          V  = 7.4,
          Q2 = 7.844,
          V2 = 5.19,
          Q3 = 9.324,
          V3 = 111)


dat <- sim_ode (ode = "pk_3cmt_iv",
                par = p,
                n_ind = 20,
#                covariates = covariates,
#                covariate_model = covariate_model,
                regimen = r1)

# Plots
ggplot(dat, aes(x=t, y=y, group=id)) +
  geom_line() +
  scale_y_log10() +
  facet_wrap(~comp, scales="free")

# block
omega <- c(0.3,       # IIV CL
           0.1, 0.3)  # IIV V

dat <- sim_ode (ode = "pk_2cmt_oral",
                par = p_oral,
                n_ind = 1,
                regimen = r1)

# Plots
ggplot(dat, aes(x=t, y=y)) +
  geom_line() +
  scale_y_log10() +
  facet_wrap(~comp)

dat_iiv <- sim_ode (ode = "pk_3cmt_iv",
                    par = p,
                    omega = omega,
                    n_ind = 10,
                    regimen = r1)

ggplot(dat_iiv, aes(x=t, y=y, colour=factor(id), group=id)) +
  geom_line() +
  scale_y_log10() +
  facet_wrap(~comp)

dat_tmp <- dat_iiv %>% group_by(comp, t) %>% summarise(med = median(y), q_low = quantile(y, 0.05), q_up = quantile(y, 0.95))
ggplot(dat_tmp, aes(x=t, y=med)) +
  geom_ribbon(aes(ymin=q_low, ymax=q_up), fill="#bfbfbf", colour=NA) +
  geom_line(aes(y=med)) +
  facet_wrap(~comp, scales="free") + theme_empty()

# now create a shiny app on-the-fly using the same parameters
# but with the sim_ode_shiny() function
sim_ode_shiny(ode = "pk_3cmt_iv",
              par = p,
              regimen = new_regimen(amt=30))
#              omega = omega)

p_efv <- list(CL = 10, V=300, KA=0.67)

sim_ode_shiny(ode = "pk_3cmt_iv",
              parameters = p,
              #              regimen = new_regimen (amt=600),
              omega = cv_to_omega (list(CL=0.2, V=0.1, KA=0.1), p_efv))
