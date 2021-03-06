library(forecast)
library(parallel)
library(TSclust)

#this code uses parts of baggedETS function from the forecast package
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



baggedClusterETS<-function (y,cores=detectCores()-1,nclusters=5,distance="EUCL",silhouette=F,
                            h_pseudo = NULL,boot_samples=1000, 
         ...) 
{
  #Windows OS
  if(Sys.info()[1]=="Windows"){
    cl <- makeCluster(getOption("cl.cores", cores))
    
    bootstrapped_series <- bld.mbb.bootstrap(y, boot_samples)
    
    if (is.null(h_pseudo)==T){
      h_pseudo <- ifelse(frequency(y) > 1, 2 * frequency(y), 10)  
    }
    
    
    start.i <- tsp(y)[1]
    start.f <- tsp(y)[2] + 1/frequency(y)
    
    
    real.pre<-y[((length(y)-h_pseudo+1):length(y))]
    
    
    if(length(y)-h_pseudo>h_pseudo){
      #real.pre<-y[((length(y)-h_pseudo+1):length(y))]
      #clusterExport(cl=cl, varlist=c("y","h_pseudo","start.i","start.f"))
      pseudo<-parLapply(cl,bootstrapped_series, function(x) {
        ts(x[(1:(length(y)-h_pseudo))],frequency=frequency(y),start=start.i)
      })
      
      
      clusterExport(cl=cl, varlist=c("forecast","ets"))
      forecasts_pseudo <- parLapply(cl,pseudo, function(x) {
        mod <- forecast(ets(x),h=h_pseudo)$mean
      })
      
      
      
      resultado.pre.lista<-list()
      
      #clusterExport(cl=cl, varlist=c("real.pre"))
      resultado.pre.lista<-parLapply(cl, forecasts_pseudo, function(x) {
        100*sum(abs((real.pre-as.numeric(x))/real.pre))/length(real.pre)})
      
      resultado.pre<-unlist(resultado.pre.lista)
      
      selec=which(rank(resultado.pre)<300)
      
      
      matseries<-ts(matrix(unlist(bootstrapped_series), ncol = length(bootstrapped_series), byrow = F),frequency=frequency(y),start=start.i)
      
      selecao<-NULL
      selecClus<-NULL
      eucl<-diss(matseries[,selec],distance)
      
      #silhouette
      clusterExport(cl=cl, varlist=c("pam"))
      if (silhouette==T){
        k<-(2:100)
        teste<-parSapply(cl,k,function(x){pam(eucl, k=x) $ silinfo $ avg.width})
        k.best<-which.max(teste)+1
      }else{k.best=nclusters}  
      
      eucl.pamclus <- pam(eucl, k = k.best)$clustering
      
      
      Nh<-NULL
      n<-100
      nh<-NULL
      Sh<-NULL
      selecClus<-NULL
      selecao3<-list()
      
      t<-(1:k.best)
      Nh<-as.numeric(table(eucl.pamclus))
      
      nh<-round(Nh/299*100)
      nh<-ifelse(nh==0,1,nh)
      
      
      for (t in 1:k.best){
        selecao2<-NULL
        teste2<-names(eucl.pamclus[eucl.pamclus==t])
        
        for (i in (1:length(teste2))){
          pre_sele2<-as.numeric(strsplit(teste2," ")[[i]][2])
          selecao2<-c(selecao2,pre_sele2)
        }
        selecao3[[t]]<-selecao2
        
      }
      
      
      for (t in 1:k.best){
        selecClus<-c(selecClus,selecao3[[t]][which(rank(resultado.pre[selecao3[[t]]],ties.method ="first")<(nh[t]+1))])
      }
      bootstrapped_series_ori<-bootstrapped_series
      bootstrapped_series<-bootstrapped_series[selecClus]
    }else{
      bootstrapped_series_ori<-bootstrapped_series
      bootstrapped_series<-bootstrapped_series[sample(1:1000,100)]
      k.best<-NA
    }
    ###########################################
    
    
    mod_boot <- parLapply(cl,bootstrapped_series, function(x) {
      mod <- ets(x)
    })
    out <- list()
    out$y <- as.ts(y)
    out$selec<-selec
    out$resultado.pre<-resultado.pre
    out$clusters<-selecao3
    out$bootstrapped_series <- bootstrapped_series
    out$bootstrapped_series_ori <- bootstrapped_series_ori
    out$models <- mod_boot
    out$etsargs <- list(...)
    fitted_boot <- lapply(out$models, fitted)
    fitted_boot <- as.matrix(as.data.frame(fitted_boot))
    out$fitted <- ts(apply(fitted_boot, 1, mean))
    tsp(out$fitted) <- tsp(out$y)
    out$residuals <- out$y - out$fitted
    out$series <- deparse(substitute(y))
    out$k<-k.best
    out$method <- "baggedClusterETS"
    out$call <- match.call()
    return(structure(out, class = c("baggedClusterETS")))
  }else{
    #UNIX systems (OSX, Linux)
    start.i <- tsp(y)[1]
    start.f <- tsp(y)[2] + 1/frequency(y)
    
    bootstrapped_series <- bld.mbb.bootstrap(y, boot_samples)
    
    if (is.null(h_pseudo)==T){
      h_pseudo <- ifelse(frequency(y) > 1, 2 * frequency(y), 10)  
    }
    
    
    
    real.pre<-y[((length(y)-h_pseudo+1):length(y))]
    
    
    if(length(y)-h_pseudo>h_pseudo){
      #real.pre<-y[((length(y)-h_pseudo+1):length(y))]
      pseudo <- mclapply(bootstrapped_series,mc.cores=cores, function(x) {
        ts(x[(1:(length(y)-h_pseudo))],frequency=frequency(y),start=start.i)
      })
      
      
      forecasts_pseudo <- mclapply(pseudo,mc.cores=cores, function(x) {
        mod <- forecast(ets(x),h=h_pseudo)$mean
      })
      
      #  forecasts_pseudo <- mclapply(pseudo,mc.cores=cores, function(x) {
      #      mod <- hw(x,h=h_pseudo)$mean
      #    })
      
      
      resultado.pre.lista<-list()
      
      resultado.pre.lista<-mclapply(forecasts_pseudo,mc.cores=cores, function(x) {
        100*sum(abs((real.pre-as.numeric(x))/real.pre))/length(real.pre)})
      
      resultado.pre<-unlist(resultado.pre.lista)
      
      selec=which(rank(resultado.pre)<300)
      
      
      matseries<-ts(matrix(unlist(bootstrapped_series), ncol = length(bootstrapped_series), byrow = F),frequency=frequency(y),start=start.i)
      
      selecao<-NULL
      selecClus<-NULL
      eucl<-diss(matseries[,selec],distance)
      
      #silhouette
      if (silhouette==T){
        k<-(2:100)
        teste<-sapply(k,function(x){pam(eucl, k=x) $ silinfo $ avg.width})
        k.best<-which.max(teste)+1
      }else{k.best=nclusters}  
      
      eucl.pamclus <- pam(eucl, k = k.best)$clustering
      
      
      Nh<-NULL
      n<-100
      nh<-NULL
      Sh<-NULL
      selecClus<-NULL
      selecao3<-list()
      
      t<-(1:k.best)
      Nh<-as.numeric(table(eucl.pamclus))
      
      nh<-round(Nh/299*100)
      nh<-ifelse(nh==0,1,nh)
      
      
      for (t in 1:k.best){
        selecao2<-NULL
        teste2<-names(eucl.pamclus[eucl.pamclus==t])
        
        for (i in (1:length(teste2))){
          pre_sele2<-as.numeric(strsplit(teste2," ")[[i]][2])
          selecao2<-c(selecao2,pre_sele2)
        }
        selecao3[[t]]<-selecao2
        
      }
      
      
      for (t in 1:k.best){
        selecClus<-c(selecClus,selecao3[[t]][which(rank(resultado.pre[selecao3[[t]]],ties.method ="first")<(nh[t]+1))])
      }
      bootstrapped_series_ori<-bootstrapped_series
      bootstrapped_series<-bootstrapped_series[selecClus]
    }else{
      bootstrapped_series_ori<-bootstrapped_series
      bootstrapped_series<-bootstrapped_series[sample(1:1000,100)]
      k.best<-NA
    }
    ###########################################
    
    
    mod_boot <- mclapply(bootstrapped_series,mc.cores=cores, function(x) {
      mod <- ets(x,...)
    })
    out <- list()
    out$y <- as.ts(y)
    out$selec<-selec
    out$resultado.pre<-resultado.pre
    out$clusters<-selecao3
    out$bootstrapped_series <- bootstrapped_series
    out$bootstrapped_series_ori <- bootstrapped_series_ori
    out$models <- mod_boot
    out$etsargs <- list(...)
    fitted_boot <- lapply(out$models, fitted)
    fitted_boot <- as.matrix(as.data.frame(fitted_boot))
    out$fitted <- ts(apply(fitted_boot, 1, mean))
    tsp(out$fitted) <- tsp(out$y)
    out$residuals <- out$y - out$fitted
    out$series <- deparse(substitute(y))
    out$k<-k.best
    out$method <- "baggedClusterETS"
    out$call <- match.call()
    return(structure(out, class = c("baggedClusterETS")))
  }
}

  





forecast.baggedClusterETS<-function (object, cores=detectCores()-1,h = ifelse(frequency(object$x) > 1, 2 * frequency(object$x), 
                             10), ...) 
{
  
  if(Sys.info()[1]=="Windows"){
    out <- list(model = object, series = object$series, x = object$y, 
                method = object$method)
    tspx <- tsp(out$x)
    
    cl <- makeCluster(getOption("cl.cores", cores))
    clusterExport(cl=cl, varlist=c("forecast"))
    forecasts_boot <- parLapply(cl,out$model$models,function(mod) {
      forecast(mod, PI = FALSE, h = h)$mean
    })
    
    forecasts_boot <- as.matrix(as.data.frame(forecasts_boot))
    colnames(forecasts_boot) <- NULL
    if (!is.null(tspx)) 
      start.f <- tspx[2] + 1/frequency(out$x)
    else start.f <- length(out$x) + 1
    out$forecasts_boot <- forecasts_boot
    out$mean <- ts(apply(forecasts_boot, 1, mean), frequency = frequency(out$x), 
                   start = start.f)
    out$median <- ts(apply(forecasts_boot, 1, median))
    out$lower <- ts(apply(forecasts_boot, 1, min))
    out$upper <- ts(apply(forecasts_boot, 1, max))
    out$level <- 100
    tsp(out$median) <- tsp(out$lower) <- tsp(out$upper) <- tsp(out$mean)
    class(out) <- "forecast"
    out 
  }else{
    out <- list(model = object, series = object$series, x = object$y, 
                method = object$method)
    tspx <- tsp(out$x)
    
    forecasts_boot <- mclapply(out$model$models,mc.cores=cores ,function(mod) {
      forecast(mod, PI = FALSE, h = h)$mean
    })
    forecasts_boot <- as.matrix(as.data.frame(forecasts_boot))
    colnames(forecasts_boot) <- NULL
    if (!is.null(tspx)) 
      start.f <- tspx[2] + 1/frequency(out$x)
    else start.f <- length(out$x) + 1
    out$forecasts_boot <- forecasts_boot
    out$mean <- ts(apply(forecasts_boot, 1, mean), frequency = frequency(out$x), 
                   start = start.f)
    out$median <- ts(apply(forecasts_boot, 1, median))
    out$lower <- ts(apply(forecasts_boot, 1, min))
    out$upper <- ts(apply(forecasts_boot, 1, max))
    out$level <- 100
    tsp(out$median) <- tsp(out$lower) <- tsp(out$upper) <- tsp(out$mean)
    class(out) <- "forecast"
    out
  }
}






