#' Simulate ODE
#'
#' Simulates a specified ODE system and regimen
#' @param ode function describing the ODE system
#' @param parameters
#' @param omega vector describing the lower-diagonal of the between-subject variability matrix
#' @param omega_type exponential or normal
#' @param n_ind number of individuals to simulate
#' @param regimen a regimen object created using the regimen() function
#' @param adherence List specifying adherence. Simulates adherence using either markov model or binomial sampling.
#' @param A_init vector with the initial state of the ODE system
#' @param step_size the step size between the observations (NOT the step size of the differential equation solver)
#' @param t_max maximum simulation time, if not specified will pick the end of the regimen as maximum
#' @param t_obs vector of observation times, only output these values
#' @param t_tte vector of observation times for time-to-event simulation
#' @param rtte should repeated events be allowed (FALSE by default)
#' @param output vector specifying which compartment numbers to output
#' @return a data frame of compartments with associated concentrations at requested times
#' @export
#' @seealso \link{sim_ode_shiny}
#' @examples
#'library(ggplot2)
#'library(PKPDsim)
#'p <- list(CL = 38.48,
#'          V  = 7.4,
#'          Q2 = 7.844,
#'          V2 = 5.19,
#'          Q3 = 9.324,
#'          V3 = 111)
#'
#'r1 <- new_regimen(amt = 100,
#'              times = c(0, 24, 36),
#'              type = "infusion")
#'
#'dat <- sim_ode (ode = "pk_3cmt_iv",
#'                par = p,
#'                regimen = r1)
#'
#'ggplot(dat, aes(x=t, y=y)) +
#'  geom_line() +
#'  scale_y_log10() +
#'  facet_wrap(~comp)
#'
#'# repeat with IIV:
#'omega <- c(0.3,       # IIV CL
#'           0.1, 0.3)  # IIV V
#'
#'dat <- sim_ode (ode = "pk_3cmt_iv",
#'                par = p,
#'                omega = omega,
#'                n_ind = 20,
#'                regimen = r1)
#'
#'ggplot(dat, aes(x=t, y=y, colour=factor(id), group=id)) +
#'  geom_line() +
#'  scale_y_log10() +
#'  facet_wrap(~comp)

sim_ode <- function (ode = NULL,
                     dde = NULL,
                     parameters = list(),
                     omega = NULL,
                     omega_type = "exponential",
                     n_ind = 1,
                     regimen = NULL,
                     adherence = NULL,
                     covariates = NULL,
                     covariate_model = NULL,
                     A_init = NULL,
                     step_size = .5,
                     t_max = NULL,
                     t_obs = NULL,
                     t_tte = NULL,
                     rtte = FALSE,
                     output_cmt = NULL,
                     cpp = FALSE,
                     cpp_recompile = TRUE,
                     cpp_show_function = FALSE
                     ) {
  if (!is.null(covariate_model) && !is.null(covariates)) {
    n_ind <- length(t(covariates[,1]))
    message(paste0("Simulating ", n_ind, " individuals with covariates...\n"))
    if (sum("tbl_df" %in% class(covariates))==0) {
      covariates <- data_frame(covariates)
    }
  }
  if ((!is.null(covariate_model) && is.null(covariates)) | (is.null(covariate_model) && !is.null(covariates))) {
    stop("For models with covariates, specify both the 'covariate_model' and the 'covariates' arguments. See help for more information.")
  }
  if (!is.null(dde)) {
    lsoda_func <- deSolve::dede
  } else {
    lsoda_func <- deSolve::lsoda
  }
  if(!is.null(dde)) {
    ode <- dde
  }
  if(cpp) {
    if(cpp_recompile) {
      if (class(ode) != "character") {
        stop("The 'ode' argument has to be a character string referencing the function.")
      } else {
        message("Compiling simulation function...")
        compile_sim_cpp(ode, parameters, cpp_show_function)
      }
    }
  }
  if (class(ode) == "character") {
    ode <- get(ode)
  } else {
    warning("The preferred input to the 'ode' argument is a character string referencing the function, not the function itself.")
  }
  if(is.null(ode) | is.null(parameters)) {
    stop("Please specify at least the required arguments 'ode' and 'parameters'.")
  }
  if(is.null(regimen)) {
    regimen <- new_regimen()
  }
#   if(!is.null(t_tte)) {
#     stop("Please specify possible observation times for time-to-event analysis as 't_tte' argument!")
#   }
  # get the ODE size
  size <- get_size_ode(ode, parameters)

  if (!is.null(omega)) {
    omega_mat <- triangle_to_full(omega)
    etas   <- MASS::mvrnorm(n = n_ind, mu=rep(0, nrow(omega_mat)), Sigma=omega_mat)
    if(n_ind == 1) {
      etas <- t(matrix(etas))
    }
  }
  if(!is.null(adherence)) {
    if(adherence$type == "markov") {
      if(!all(c("p01", "p11") %in% names(adherence$markov))) {
        stop("Adherence simulation using Markov model requires specification of p01 and p11!")
      }
    }
  }
  comb <- list()
  p <- parameters
  if(class(regimen) != "regimen") {
    stop("Please create a regimen using the new_regimen() function!")
  }
  if(regimen$type == "infusion") {
    p$t_inf <- regimen$t_inf
    p$dose_type <- "infusion"
    design <- data.frame(rbind(cbind(t=regimen$dose_times, dose = regimen$dose_amts, dum = 0),
                               cbind(t=regimen$dose_times + regimen$t_inf, dose=0, dum = 1))) %>%
      dplyr::arrange(t)
  } else {
    p$dose_type <- "bolus"
    design <- data.frame(rbind(cbind(t=regimen$dose_times, dose = regimen$dose_amts, dum = 0)))
  }
  if(!is.null(t_obs)) { # make sure observation times are in dataset
    design <- data.frame(rbind(design, cbind(t = setdiff(t_obs, design$t), dose = 0, dum = 0))) %>% arrange(t)
  }
  if(!is.null(t_tte)) { # make sure tte times are in dataset
    design <- data.frame(rbind(design, cbind(t = setdiff(t_tte, design$t), dose = 0, dum = 0))) %>% arrange(t)
  }
  if (is.null(t_max)) {
    if (length(design$t) > 1) {
      t_max <- tail(design$t,1) + max(diff(regimen$dose_times))
    } else {
      t_max <- tail(design$t,1) + 24 # guess timeframe, user should use tmax argument
    }
    if(!is.null(t_obs)) {
      if(is.null(t_max) || t_max < max(t_obs)) { t_max <- max(t_obs) }
    }
    if(!is.null(t_tte)) {
      if(is.null(t_tte) || t_max < max(t_tte)) { t_max <- max(t_tte) }
    }
  }
  design <- rbind(design %>%
                    dplyr::filter(t < t_max), tail(design,1))
  design[length(design[,1]), c("t", "dose")] <- c(t_max,0)
  times <- seq(from=0, to=tail(design$t,1), by=step_size)
  if (is.null(A_init)) {
    A_init <- rep(0, size)
  }
  p$dose_times <- regimen$dose_times
  p$dose_amts <- regimen$dose_amts
  if(!is.null(p$F)) {
    design$dose <- design$dose * F
  }
  events <- c() # only for tte
  scale <- 1
  if(class(attr(ode, "obs")[["scale"]]) == "numeric") {
    scale <- attr(ode, "obs")[["scale"]]
  }
  comb <- c()
  message("Simulating...")
  for (i in 1:n_ind) {
    p_i <- p
    if (!is.null(covariates) && !is.null(covariate_model)) {
      keys <- names(p_i)[names(p_i) %in% names(covariate_model)]
      if (length(keys) > 0) {
        for (j in seq(keys)) {
          p_i[[keys[j]]] <- covariate_model[[keys[j]]](par = p_i[[keys[j]]], cov = covariates[i,])
        }
      }
    }
    design_i <- design
    A_init_i = A_init
    if (!is.null(adherence)) {
      if(adherence$type == "markov") {
        adh_i <- new_adherence(n = length(design_i[design_i$dum == 0,]$dose),
                               markov = list(p01 = adherence$markov$p01, p11 = adherence$markov$p11))
      } else {
        adh_i <- new_adherence(n = length(design_i[design_i$dum == 0,]$dose),
                               p_binom = adherence$p_bionm)
      }
      design_i[design_i$dum == 0,]$dose <- design_i[design_i$dum == 0,]$dose * adh_i
    }
    if (!is.null(omega)) {
      if (omega_type=="exponential") {
        p_i[1:nrow(omega_mat)] <- relist(unlist(as.relistable(p_i[1:nrow(omega_mat)])) * exp(etas[i,]))
      } else {
        p_i[1:nrow(omega_mat)] <- relist(unlist(as.relistable(p_i[1:nrow(omega_mat)])) + etas[i,])
      }
    }
    if(class(A_init) == "function") {
      A_init_i = A_init(p_i)
    }
    event_occurred <- FALSE
    tmp <- c()
    prv_cumhaz <- 0
    if(cpp) {
      tmp <- sim_wrapper_cpp(A_init, design_i$t, design_i$dose, length(design$t), p_i, 1)
      des_out <- cbind(matrix(unlist(tmp$y), nrow=length(tmp$time), byrow = TRUE))
      dat_ind <- c()
      for (j in 1:length(A_init)) {
        dat_ind <- rbind (dat_ind, cbind(id=i, t=tmp$time, comp=j, y=des_out[,j]))
      }
      if(i == 1) {
        l_mat <- length(dat_ind[,1])
        comb <- matrix(nrow = l_mat*n_ind, ncol=ncol(dat_ind)) # don't grow but define upfront
      }
      comb[((i-1)*l_mat)+(1:l_mat),] <- dat_ind
#      comb <- data.frame(dat_ind)
    } else {
      for (k in 1:(length(design$t)-1)) {
        if (k > 1) {
          A_upd <- dat[dat$comp!="cumhaz" & dat$t==tail(time_window,1),][,]$y
          if(event_occurred) {
            A_upd[attr(ode, "cumhaz")[["cmt"]]] <- 0 # reset cumulative hazard
          }
        } else {
          A_upd <- A_init_i
        }
        p_i$rate <- 0
        if(p_i$dose_type != "infusion") {
          A_upd[regimen$cmt] <- A_upd[regimen$cmt] + design_i[design_i$dum == 0,]$dose[k]
        } else {
          if(design_i$dose[k] > 0) {
            p_i$rate <- design_i$dose[k] / p_i$t_inf
          }
        }
        time_window <- times[(times >= design_i$t[k]) & (times <= design_i$t[k+1])]
        dat <- cbind(id = i, num_int_wrapper (time_window, A_upd, ode, p_i, lsoda_func, cpp, step_size))
        if(!is.null(attr(ode, "cumhaz"))) {
          event_occurred <- FALSE
          dat <- rbind (dat, dat %>%
                          dplyr::filter(comp == attr(ode, "cumhaz")[["cmt"]]) %>%
                          dplyr::mutate(comp = "cumhaz", y = y-prv_cumhaz))
          tmp <- dat %>% dplyr::filter(comp == "cumhaz") %>% dplyr::filter(t %in% t_tte) %>% tail(1)
          if(length(tmp[,1])>0) {
            prv_cumhaz <- tmp$y
            if(runif(1) > cumhaz_to_surv(tmp$y)) {
              events <- rbind(events, cbind(id = i, t = tmp$t[1]))
              event_occurred <- TRUE
            } else {
              event_occurred <- FALSE
            }
          }
        }
        comb <- rbind(comb, dat)
      }
    }
  }

  # Add concentration to dataset, and perform scaling and/or transformation:
  comb <- data.frame(comb)
  colnames(comb) <- c("id", "t", "comp", "y")
  if(!is.null(attr(ode, "obs"))) {
    scale <- 1
    if(class(attr(ode, "obs")[["scale"]]) == "character") {
      scale <- p[[attr(ode, "obs")[["scale"]]]]
    }
    if(class(attr(ode, "obs")[["scale"]]) == "numeric") {
      scale <- attr(ode, "obs")[["scale"]]
    }
    comb <- rbind (comb, comb %>% dplyr::filter(comp == attr(ode, "obs")[["cmt"]]) %>% dplyr::mutate(comp = "obs", y = y/scale))
    if(!is.null(attr(ode, "obs")[["trans"]])) {
      if(class(attr(ode, "obs")[["trans"]]) == "character") {
        trans_func <- get(attr(ode, "obs")[["trans"]])
        comb[comb$comp == "obs",]$y <- trans_func(comb[comb$comp == "obs",]$y)
      }
    }
  }
  if(!is.null(t_obs)) {
    comb <- comb %>% dplyr::filter(t %in% t_obs)
  }
  if(!is.null(output_cmt)) {
    comb <- comb %>% dplyr::filter(comp %in% output_cmt)
  }
  if(length(events)>0) {
    events <- data.frame(events)
    events <- events[!duplicated(paste0(events$id, "_", events$t)),]
    ids <- unique(comb$id)
    if(!rtte) { # no repeated TTE
      events <- events[!duplicated(events$id),]
      ids_ev <- unique(events[,1])
    } else {
      ids_ev <- unique(events[events[,2] == max(t_tte),1])
    }
    cens <- setdiff(ids, ids_ev) # censor individuals who didn't have event on last obs day
    comb <- rbind(comb, cbind(events, comp="event", y = 1))
    if(length(cens)>0) {
      comb <- rbind(comb, cbind(id = cens, t = max(comb$t), comp="event", y=0))
    }
  }
  comb$id <- as.numeric(comb$id)
  comb$t <- as.numeric(comb$t)
  comb$y <- as.numeric(comb$y)
  comb <- data.frame(comb %>% arrange(id, comp, t))
  class(comb) <- c(class(comb), "PKPDsim")
  return(comb)
}
