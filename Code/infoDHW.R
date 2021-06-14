## extract DHW info from a DHW file crop by shapefile
infoDHW = function(dhw, shp, map=TRUE){
  require(raster)
  require(sparkline)
  require(kableExtra)
  require(leaflet)
  
  rr = raster(dhw)
  shpMask = shapefile(shp)
  rrCrop = crop(rr, shpMask)
  rrMasked = mask(rr, shpMask)
  rrValues = extract(rr, shpMask, df=TRUE)[[2]]
  rrValid = length(rrMasked) - cellStats(rrMasked, "countNA")
  
  if (map){
    pal <- colorNumeric(c("#2b83ba","#80bfac","#c7e9ad","#ffffbf", "#fec980", "#f17c4a", "#d7191c"), values(rr),
                        na.color = "transparent")
    shpMask2 = spTransform(shpMask, "+init=epsg:4326")
    m = leaflet(add2) %>% addTiles() %>% addRasterImage(rrCrop, colors = pal) %>% addPolygons(fill = FALSE) %>% 
      addLegend(pal = pal, values = values(rr), title = "DHW")
  
  }
  rrQuantile = as.numeric(quantile(rrMasked))
  DHWtable = data.frame(DHWmean = cellStats(rrMasked, mean),
                        DHWmin = cellStats(rrMasked, min),
                        DHWmax = cellStats(rrMasked, max),
                        DHWq25 = rrQuantile[2],
                        DHWq50 = rrQuantile[3],
                        DHWq75 = rrQuantile[4],
                        DHW0 = 100*length(rrValues[rrValues==0])/rrValid,
                        DHW2 = 100*length(rrValues[rrValues>0 & rrValues<=2])/rrValid,
                        DHW4 = 100*length(rrValues[rrValues>2 & rrValues<=4])/rrValid,
                        DHW8 = 100*length(rrValues[rrValues>4 & rrValues<=8])/rrValid,
                        DHW28plus = 100*length(rrValues[rrValues>8])/rrValid,
                        DHWboxplot = as.character(htmltools::as.tags(sparkline(rrValues, type='boxplot'))))
  
  out = as.htmlwidget(formattable(DHWtable))
  out$dependencies = c(out$dependencies, htmlwidgets:::widget_dependencies("sparkline", "sparkline"))

  return(list(map=m, table=out))
}




