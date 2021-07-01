## extract CRW parameter info from a aggregated CRW file file crop by shapefile
infoCRWmax_area = function(crwFilename, roiShape, mmmFilename=NULL, shpType='WKT', map=TRUE, verbose=TRUE){
  options(warn=-1)

  suppressPackageStartupMessages(require(ncdf4))
  suppressPackageStartupMessages(require(leaflet))
  suppressPackageStartupMessages(require(raster))
  suppressPackageStartupMessages(require(rgeos))

  if (verbose){
    cat("Getting files...")
  }
  

  
  ## get temporal_coverage_start attribute, a.k.a. start date
  nc <- nc_open(crwFilename)
  dateStart <- as.Date(ncatt_get(nc, 0, "temporal_coverage_start")$value)
  nc_close(nc)
  yy <- as.numeric(format.Date(dateStart, "%Y"))
  
  
    
  ## read variable and get max values map
  ## the MaxDate is given in day of the year
  rr = stack(crwFilename)
  rrMax = max(rr)
  rrMaxDates <- which.max(rr)
  
  ## get the masking shape
  if (shpType=="WKT"){
    shpMask <- rgeos::readWKT(roiShape)
    crs(shpMask) <- CRS('+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs')
  }else if (shpType=="SHP"){
    shpMask <- raster::shapefile(roiShape)
  }else {
    print(paste0(shpType, " not a valid format. Must be WKT or SHP"))
    return()
  }
  
  if (verbose){
    cat("Cropping layers...")
  }
  ## Crop and mask the data
  rrCrop <- crop(rrMax, shpMask)
  rrMasked <- mask(rrMax, shpMask)
  rrMaskedDates <- mask(rrMaxDates, shpMask)
  rrValues <- extract(rrMax, shpMask, df=TRUE)[[2]]
  rrValid <- length(rrMasked) - cellStats(rrMasked, "countNA")

  if (verbose){
    cat("Calculating Stats...")
  }
  ## create map
  if (map){
    pal <- colorNumeric(c("#2b83ba","#80bfac","#c7e9ad","#ffffbf", "#fec980", "#f17c4a", "#d7191c"), values(rr),
                        na.color = "transparent")
    shpMask2 <- spTransform(shpMask, '+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs')
    m <- leaflet(shpMask2) %>% addTiles() %>% addRasterImage(rrMax, colors = pal) %>% addPolygons(fill = FALSE) %>% 
      addLegend(pal = pal, values = values(rr), title = "DHW")
  
  }
  
  ## get statistics and store it in a dataframe
  quantileProbs = c(0.0, 0.25, 0.50, 0.75, 0.90, 0.95, 0.99, 1.0)
  
  ## param values stats
  rrQuantile <- quantile(rrMasked, probs=quantileProbs)
  crwStats <- data.frame(crwMean = cellStats(rrMasked, mean),
                         crwSD = cellStats(rrMasked, sd),
                         crwMedian = rrQuantile['50%'],
                         crwMin = rrQuantile['0%'],
                         crwQ25 = rrQuantile['25%'],
                         crwQ75 = rrQuantile['75%'],
                         crwQ90 = rrQuantile['90%'],
                         crwQ95 = rrQuantile['95%'],
                         crwQ99 = rrQuantile['99%'], 
                         crwMax = rrQuantile['100%'], 
                         row.names = yy)

  ## when max occurs
  rrQuantileDate <- as.Date(dateStart) + quantile(rrMaskedDates, probs=quantileProbs)
  crwStatsDates <- data.frame(crwMedian = rrQuantileDate['50%'],
                         crwMin = rrQuantileDate['0%'],
                         crwQ25 = rrQuantileDate['25%'],
                         crwQ75 = rrQuantileDate['75%'],
                         crwQ90 = rrQuantileDate['90%'],
                         crwQ95 = rrQuantileDate['95%'],
                         crwQ99 = rrQuantileDate['99%'], 
                         crwMax = rrQuantileDate['100%'], 
                         row.names = yy)
  
  ## MMM
  if (!is.null(mmmFilename)){
    ## get MMM values
    mmm <- raster(mmmFilename)
    mmmCrop <- crop(mmm, shpMask)
    
    rrQuantile <- quantile(mmmCrop, probs=quantileProbs)
    mmmStats <- data.frame(mmmMean = cellStats(mmmCrop, mean),
                           mmmSD = cellStats(mmmCrop, sd),
                           mmmMedian = rrQuantile['50%'],
                           mmmMin = rrQuantile['0%'],
                           mmmQ25 = rrQuantile['25%'],
                           mmmQ75 = rrQuantile['75%'],
                           mmmQ90 = rrQuantile['90%'],
                           mmmQ95 = rrQuantile['95%'],
                           mmmQ99 = rrQuantile['99%'], 
                           mmmMax = rrQuantile['100%'], 
                           row.names = yy)
  }else {
    mmmStats=NULL
  }
  
  if (verbose){
    cat("DONE. Results are: map, crwStats, crwStatsDates and mmmStats")
    cat("\n")
  }
  return(list(map=m, crwStats=crwStats, crwStatsDates=crwStatsDates, mmmStats=mmmStats))
}




