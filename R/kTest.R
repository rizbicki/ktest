convertDataStacked = function(data, classes) {

  if(is.list(data) & is.null(classes)) {

    if(is.data.frame(data)) {

      return(data)

    } else {

      if(is.null(names(data))) {

        data = setNames(data, as.factor(1:length(data)))

      }

      return(stack(data))

    }

  } else if(is.vector(data) & is.vector(classes) & length(data) == length(classes)) {

    return(data.frame(data, as.factor(classes)))

  } else {

    stop("data and class type does not fit, if data is a matrix or a stacked data frame then classes must me NULL, if x is a vector then classes must be a vector.")

  }
}


densitiesEval = function(data, bw = bw.nrd0(data[,1]), npoints = 512) {

  mini = min(data[,1]) - 3*bw

  maxi = max(data[,1]) + 3*bw

  l = levels(data[,2])

  densities = list()

  for(i in 1:length(l)) {

    densities[[i]] = density(data[data[,2] == l[i],1], n = npoints, na.rm = TRUE, from = mini, to = maxi)

  }

  return(list(densities = densities, labels = l))
}


commonArea = function(densities) {

  x = densities[[1]]$x

  y = densities[[1]]$y

  for(i in 2:length(densities)) {

    for(j in 1:length(x)) {

      y[j] = min(y[j], densities[[i]]$y[j])

    }

  }

  return(auc(x, y, type = 'spline'))
}


densityPairs = function(densities, labels) {

  par(mfrow = c(length(densities) - 1, length(densities) - 1))

  for(i in 1:length(densities)) {

    for(j in i:length(densities)) {

      if(i == j && i != 1 && i != length(densities)) {

        plot.new()

      }

      if(i != j) {

        plot(densities[[i]], col = 1, main = "", xlab = paste('Common area =', round(commonArea(densities[c(i,j)]), 4)), ylab = "")

        lines(densities[[j]], col = 2)

        legend('topright', legend = c(paste('Group', labels[i]), paste('Group', labels[j])), col = 1:2, lwd = 1, bty = 'n')

      }

    }

  }

  par(mfrow=c(1,1))
}


#' kTest
#'
#' Performs a hypothesis test for equality of distributions based on the estimated kernel densities and the permutation test.
#'
#' @param data Either a list of numeric vectors, a numeric vector (with classes parameter defined), or a stacked data frame (first column with numeric values and second column with classes).
#' @param classes Classes relative to data parameter, should be used only when data is a numeric vector.
#' @param perm Boolean indicating weather to obtain the p-value trough the permutation test or just return return the common area between densities.
#' @param B Number of permutations.
#' @param bw The bandwidth used to estimate the kernel densities.
#' @param npoints The number of points used to estimate the kernel densities.
#' @param pairsPlot Boolean indicating weather to plot density pairs or not (usefull to detect witch densities differ).
#' @param threads Number of cores to be used (see ??DoParallel).
#'
#' @return A list containing:
#'
#' - commonArea: Common area between the kernel densities.
#'
#' - p.value: The p-value generated by the permutation test (if perm = TRUE).
#'
#' @export
#'
#' @examples data = list(x = rnorm(30), y = rexp(50), z = rpois(70, 1))
#' kTest(data)

kTest = function(data, classes = NULL, perm = TRUE, B = 5000, bw = bw.nrd0(data[,1]), npoints = 512, pairsPlot = TRUE, threads = detectCores() - 1) {

  data = convertDataStacked(data, classes)

  densities = densitiesEval(data, bw, npoints)

  k = commonArea(densities$densities)

  if(pairsPlot) {

    densityPairs(densities$densities, densities$labels)

  }

  if(!perm) {

    return(list(commonArea = k))

  }

  if(threads > 1) {

    if(threads > detectCores()) {

      warning("threads inserted greater than available, parameter threads set to 1.")

      threads = 1

    }

    cl = makeCluster(threads)

    registerDoParallel(cl)

    on.exit(stopCluster(cl))

    Ti = foreach(i = 1:B, .combine = c, .export = c("commonArea", "densitiesEval"), .packages = "MESS") %dopar% {

      data[,1] = sample(data[,1])

      return(commonArea(densitiesEval(data, bw, npoints)$densities))

    }

  } else {

    Ti = vector("numeric", B)

    for(i in 1:B) {

      data[,1] = sample(data[,1])

      Ti[i] = commonArea(densitiesEval(data, bw, npoints)$densities)

    }

  }

  p = (1/B)*sum(Ti < k)

  return(list(commonArea = k, p.value = p))
}


#' kSimmetryTest
#'
#' Performs a pdf simmetry test for given data based on the estimated kernel densities and the permutation test.
#'
#' @param x A numeric vector of data.
#' @param around The desired value to check if the density is simmetryc around. Must be one of 'mean', 'median', or a real number.
#' @param ... Futher parameters to be passed to kTest.
#'
#' @return A list containing:
#'
#' - commonArea: Common area between the (data - median) and (median - data) densities.
#'
#' - p.value: The p-value generated by the permutation test.
#'
#' @export
#'
#' @examples x = rnorm(100)
#' kSimmetryTest(x)

kSimmetryTest = function(x, around = 'median', ...) {

  if(!is.numeric(x)) {

    stop('x must be a numeric vector of data.')

  }

  if(around != 'median' & around != 'mean' & !is.numeric(around)) {

    stop('around must be one of "mean", "median", or a real number.')

  }

  if(around == 'median') {

    around = median(x)

  }

  if(around == 'mean') {

    around = mean(x)

  }

  a = x - around

  b = around - x

  return(kTest(list(a, b), ...))
}

commonAreaReal = function(d, dfunc) {

  x = d$x

  y = d$y

  for(j in 1:length(x)) {

    y[j] = min(y[j], dfunc(d$x[j]))

  }

  return(auc(x, y, type = 'spline'))
}


#' kGOFTest
#'
#' Performs a hypothesis test for goodness-of-fit based on the estimated kernel densities.
#'
#' @param data Either a list of numeric vectors, a numeric vector (with classes parameter defined), or a stacked data frame (first column with numeric values and second column with classes).
#' @param rfunc A function to generate data (see examples).
#' @param dfunc A function to evaluate real density values (see examples).
#' @param classes Classes relative to data parameter, should be used only when data is a numeric vector.
#' @param perm Boolean indicating weather to obtain the p-value trough the permutation test or just return return the common area between densities.
#' @param B Number of permutations.
#' @param bw The bandwidth used to estimate the kernel densities.
#' @param npoints The number of points used to estimate the kernel densities.
#' @param threads Number of cores to be used (see ??DoParallel).
#' @param param_names A vector of variable names (as character). This parameter can be ignored when threads = 1. When using more then 1 threads, it is needed to export the global parameters name on the rfunc and dfunc functions (see examples).
#'
#' @return A list containing:
#'
#' - commonArea: Common area between the kernel and the theoric density.
#'
#' - p.value: The p-value generated by the permutation test (if perm = TRUE).
#'
#' @export
#'
#' @examples data = rnorm(100)
#'
#' param1 = mean(data)
#'
#' param2 = sd(data)
#'
#' var_names = c(param1, param2)
#'
#' rfunc = function(n) {
#'   return(rnorm(n, param1, param2))
#' }
#'
#' dfunc = function(x) {
#'   return(dnorm(x, param1, param2))
#' }
#'
#' kGOFTest(data, rfunc, dfunc, threads = 2, param_names = c('param1', 'param2'))


kGOFTest = function(data, rfunc, dfunc, perm = TRUE, B = 5000, bw = bw.nrd0(data[,1]), npoints = 512, threads = detectCores() - 1, param_names = NULL) {

  if(!is.numeric(data)) {

    stop('data must be a numeric vector of data.')

  }

  if(!is.function(rfunc)) {

    stop('rfunc must be a function to generate data.')

  }

  if(!is.function(dfunc)) {

    stop('dfunc must be a function to evaluate real density values.')

  }

  data = data.frame(data, factor(1))

  d = densitiesEval(data, bw, npoints)$densities[[1]]

  k = commonAreaReal(d, dfunc)

  if(!perm) {

    return(list(commonArea = k))

  }

  if(threads > 1) {

    if(threads > detectCores()) {

      warning("threads inserted greater than available, parameter threads set to 1.")

      threads = 1

    }

    cl = makeCluster(threads)

    registerDoParallel(cl)

    on.exit(stopCluster(cl))

    Ti = foreach(i = 1:B, .combine = c, .export = c("commonAreaReal", "densitiesEval", param_names), .packages = "MESS") %dopar% {

      data[,1] = rfunc(nrow(data))

      return(commonAreaReal(densitiesEval(data, bw, npoints)$densities[[1]], dfunc))

    }

  } else {

    Ti = vector("numeric", B)

    for(i in 1:B) {

      data[,1] = rfunc(nrow(data))

      Ti[i] = commonAreaReal(densitiesEval(data, bw, npoints)$densities[[1]], dfunc)

    }

  }

  p = (1/B)*sum(Ti < k)

  return(list(commonArea = k, p.value = p))
}
