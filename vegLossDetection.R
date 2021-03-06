### load libraries ###

if(!require(raster)) install.packages("raster")
library(raster)

if(!require(rgdal)) install.packages("rgdal")
library(rgdal)

if(!require(snow)) install.packages("snow")
library(snow)

if(!require(MASS)) install.packages("MASS")
library(MASS)

if(!require(igraph)) install.packages("igraph")
library(igraph)

### main function ###

vegLossDetection <- function(imgVector, grouping, coarse = TRUE, test = "generic.change", pval = 0.05, clumps = TRUE, directions = 8, genLogs = TRUE, writePath = NULL, format = NULL){
  
  ### check dependencies ###
  
  if(!is.vector(imgVector)){
    stop("please specify imgVector as a vector")
  }
  
  if(!is.list(grouping)){
    stop("please input grouping as a list of vectors")
  }
  
  if(!is.logical(coarse)){
    stop("coarse must be logical")
  }
  
  if(!test %in% c("generic.change", "increase", "decrease")){
    stop("test must be either generic.change, increase or decrease")
  }
  
  if(!is.numeric(pval)){
    stop("pval must be numeric")
  }
  
  if(!is.logical(clumps)){
    stop("clumps must be logical")
  }
  
  if(is.null(directions) & clumps == TRUE){
    directions <- 8
    warning(paste0("no input for directions detected, defaulting to ", directions))
  } else if(clumps == FALSE){
    warning(paste0("no directions parsed since clumps is ", clumps))
  } else if(!directions %in% c(4,8) | length(directions) > 1){
    stop("directions must be either 4 or 8")
  }
  
  if(!is.logical(genLogs)){
    stop("genLogs must be logical")
  }
  
  if(is.null(writePath)){
    writePath = paste(getwd(), "/output/vegLossDetection", sep = "")
    warning(paste("no writePath supplied, defaulting to ", writePath, sep=""))
  } else if (substr(writePath, nchar(writePath), nchar(writePath)) == "/") {
    writePath <- substr(writePath, 1, nchar(writePath)-1)
  }
  
  if(!file.exists(writePath)) {
    stop(paste("the directory ", writePath, " does not exist", sep=""))
  }
  
  if(is.null(format)){
    format <- "GTiff"
    warning(paste("no format provided, defaulting to ", format, sep=""))
  }
  
  source("./aux/pairing.R", encoding = "UTF-8")
  source("./aux/subtract.R", encoding = "UTF-8")
  source("./aux/customUTest.R", encoding= "UTF-8")
  
  ### main body ###
  
  start <- proc.time()
  
  p <- list()
  g <- lapply(grouping, function(x) return(stack(imgVector[x])))
  f <- lapply(pairing(grouping), function(x) return(stack(imgVector[x])))
  gNA <- lapply(g, function(x) sum(is.na(x)))
  
  # clean individual images for cleaner median calculation, remove large NA stacks
  
  cat("cleaning images for median calculations, removing large NA stacks...\n")
  
  for(i in 1:length(g)){
    g[[i]][gNA[[i]][] > length(names(g[[i]]))/2] <- NA
  }
  
  for(i in 1:length(f)){
    f[[i]][gNA[[i]][] > length(names(g[[i]]))/2 | gNA[[i+1]][] > length(names(g[[i+1]]))/2] <- NA
  }
  
  # generate medians of individual groups and stack consecutive medians, subtract medians to get buffers
  
  cat("generating medians and difference rasters...\n")
  
  beginCluster()
  gM <- lapply(g, function(x) return(calc(x, fun=median, na.rm=T)))
  fM <- lapply(pairing(gM), function(x) return(stack(x)))
  diff <- lapply(fM, function(x) return(calc(x, fun=subtract)))
  endCluster()
  
  # limiting search spaces for diff based on coarse option and test type
  
  if(test=="generic.change"){
    testW="two.sided"
    if(coarse==TRUE){
      for(i in 1:length(diff)){
        diff[[i]][diff[[i]][] < 1 & diff[[i]][] > -1] <- NA
      }
    } else{
      for(i in 1:length(diff)){
        diff[[i]][diff[[i]][] < 0.5 & diff[[i]][] > -0.5] <- NA
      }
    }
  } else if(test=="increase") {
    testW="less"
    if(coarse==TRUE){
      for(i in 1:length(diff)){
        diff[[i]][diff[[i]][] < 1] <- NA
      }
    } else{
      for(i in 1:length(diff)){
        diff[[i]][diff[[i]][] < 0.5] <- NA
      }
    }
  } else if(test=="decrease"){
    testW="greater"
    if(coarse==TRUE){
      for(i in 1:length(diff)){
        diff[[i]][diff[[i]][] > -1] <- NA
      }
    } else{
      for(i in 1:length(diff)){
        diff[[i]][diff[[i]][] > -0.5] <- NA
      }
    }
  }
  
  # custom U-test and filter results, and write results
  
  cat("starting customUTest...\n")
  
  for(i in 1:length(f)){
    p[[i]] <- customUTest(f[[i]], diff[[i]], length(grouping[[i]]), (length(grouping[[i]]) + length(grouping[[i+1]])), testW)
    p[[i]][p[[i]][] > pval] <- NA
    writeRaster(p[[i]], file.path(writePath, paste0("manW_", i, "_", i+1)), format = format, overwrite = TRUE)
  }
  
  # clumping of pixels and write results
  
  if(clumps == TRUE){
    c <- p
    clumpsR <- lapply(c, function(x) return(clump(x, directions=directions, gaps = TRUE)))
    clumpFreq <- lapply(clumpsR, function(x) return(as.data.frame(freq(x))))
    excludeID <- lapply(clumpFreq, function(x) return(x$value[which(x$count==1)]))
    
    for(i in 1:length(c)){
      c[[i]][clumpsR[[i]] %in% excludeID[[i]]] <- NA
      writeRaster(c[[i]], file.path(writePath, paste0("manW_clump_", i, "_", i+1)), format = format, overwrite = TRUE)
    }
  }
  
  # generate logs of results
  
  if(genLogs==TRUE){
    logs <- data.frame(matrix(ncol=8))
    names(logs) <- c("coarse", "test", "pval", "clumps", "directions", "diffPixels", "pPixels", "cPixels")
    for(i in 1:length(diff)){
      logs[i,1] <- coarse
      logs[i,2] <- test
      logs[i,3] <- pval
      logs[i,4] <- clumps
      logs[i,6] <- length(which(!is.na(diff[[i]][])))
      logs[i,7] <- length(which(!is.na(p[[i]][])))
      if(clumps==TRUE){
        logs[i,5] <- directions
        logs[i,8] <- length(which(!is.na(c[[i]][])))
      } else {
        logs[i,5] <- NA
        logs[i,8] <- NA
      }
      row.names(logs)[i] <- paste0(i, "_", i+1)
    }
    write.csv(logs, file.path(writePath, "logs.csv"), row.names = TRUE)
  }
  
  end <- proc.time()
  print(end-start)
  return(0)
}