#!/bin/bash

## create a climatology for DHW 1985-2012
## download the file
## cut to GBR region
## add to corresponding day-file
## divide each file by its count
## concatenate into one 

## it needs empty daily files created with createDummyDHW.sh


##paths
ftpPath="ftp://ftp.star.nesdis.noaa.gov/pub/sod/mecb/crw/data/5km/v3.1/nc/v1.0/daily/dhw/2020/"
resultPath="./DHWday/"

## test one year
for ff in `cat fileList2020.txt`
    do
        echo $ff
        yday=$(date -d $(echo $ff |cut -d _ -f 4 | cut -d. -f1) +%j)
        wget -O DHWtemp.nc $ftpPath$ff
        gdalwarp -cutline LME_NortheastAustralianShelf.shp -crop_to_cutline NETCDF:"DHWtemp.nc":degree_heating_week temp.nc 
        ncap2 -S DHW.nca temp.nc 
                ncap2 -s "YDAY=${yday}; YDAY@long_name=\"day_of_the_year\";" temp.nc
        ncks -x -v Band1 temp.nc ${resultPath}LME_${ff}
        rm temp.nc
    done

        
