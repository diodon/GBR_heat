#! /bin/bash
## get list of ncfile sfor each product/year
yearStart=1985
yearEnd=2020
productName='dhw/'

crwURL='ftp://ftp.star.nesdis.noaa.gov/pub/sod/mecb/crw/data/5km/v3.1/nc/v1.0/daily/'

for yy in `seq $yearStart $yearEnd`; do 
    echo $yy
    lftp <<-GETFILES 
        open ftp://ftp.star.nesdis.noaa.gov/pub/sod/mecb/crw/data/5km/v3.1/nc/v1.0/daily/dhw/$yy
        ls -1 *.nc >${productName}FileList_${yy}.txt
        bye
GETFILES
done
    
exit
