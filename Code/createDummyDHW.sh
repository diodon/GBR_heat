#!/bin/bash

## Create daily DHW files with dregree_heating_week=0 for all files
## using one CRW file as source for the structure

## get the file. Uncomment to download and process
#wget ftp://ftp.star.nesdis.noaa.gov/pub/sod/mecb/crw/data/5km/v3.1/nc/v1.0/daily/dhw/1985/ct5km_dhw_v3.1_19851231.nc

## cut to GBR region
ncks -v degree_heating_week -d lat,-28.9,-7.3 -d lon,142.0,156.0 ct5km_dhw_v3.1_19851231.nc DHWGBR.nc
## remove global attrs
ncatted -O -a ,global,d,, DHWGBR.nc DHWGBR.nc

## set dhw to zero value and create count variable
ncap2 -s 'degree_heating_week=degree_heating_week*0; count=0' DHWGBR.nc dummy.nc



## copy the dummy to 366 files numerated according yod
for i in {001..366}
    do
        echo $i
        cp dummy.nc ./DHWday/DHWGBR_$i.nc
    done

