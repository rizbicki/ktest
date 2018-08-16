# ktest
R interface for estimated kernel densities comparisons

## The kTest function
Performs a hypothesis test for equality of distributions based on the estimated kernel densities and the permutation test.

### Example

> data = list(x = rnorm(30), y = rexp(50), z = rpois(70, 1))

> kTest(data)

$`commonArea`
[1] 0.4895715

$p.value
[1] 2e-04

## The kSimmetryTest function
Performs a pdf simmetry test for given data based on the estimated kernel densities and the permutation test.

### Example

> x = rnorm(100)

> kSimmetryTest(x, around = 'median')

$`commonArea`
[1] 0.9450761

$p.value
[1] 0.9232

## The kGOFTest function
Performs a hypothesis test for goodness-of-fit based on the estimated kernel densities.

### Example

data = rnorm(100)

rfunc = function(n) {
  return(rnorm(n, mean(data), sd(data)))
}

dfunc = function(x) {
  return(dnorm(x, mean(data), sd(data)))
}

kGOFTest(data, rfunc, dfunc, threads = 2)

$`commonArea`
[1] 0.9282987

$p.value
[1] 0.4938