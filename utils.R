MBB <- function(x, window_size) {
  
  bx = array(0, (floor(length(x)/window_size)+2)*window_size)
  for (i in 1:(floor(length(x)/window_size)+2)){
    c <- sample(1:(length(x)-window_size+1),1)
    bx[((i-1)*window_size+1):(i*window_size)] <- x[c:(c+window_size-1)]
  }
  start_from <- sample(0:(window_size-1),1) + 1
  bx[start_from:(start_from+length(x)-1)]
}



bld.mbb.bootstrap<-function (x, num, block_size = if (frequency(x) > 1) 2 * frequency(x) else 8) 
{
  freq <- frequency(x)
  xs <- list()
  xs[[1]] <- x
  if (num > 1) {
    lambda <- BoxCox.lambda(x, lower = 0, upper = 1)
    x.bc <- BoxCox(x, lambda)
    if (freq > 1) {
      x.stl <- stl(ts(x.bc, frequency = freq), "per")$time.series
      seasonal <- x.stl[, 1]
      trend <- x.stl[, 2]
      remainder <- x.stl[, 3]
    }
    else {
      trend <- 1:length(x)
      suppressWarnings(x.loess <- loess(x.bc ~ trend, span = 6/length(x), 
                                        degree = 1))
      seasonal <- rep(0, length(x))
      trend <- x.loess$fitted
      remainder <- x.loess$residuals
    }
    for (i in 2:num) {
      xs[[i]] <- InvBoxCox(trend + seasonal + MBB(remainder, 
                                                  block_size), lambda)
    }
  }
  xs
}