#! /bin/bash
## get list of ncfile sfor each product/year
yearStart=1985
yearEnd=2020
productName=$1

USER='anonymous'
PASSWD='eklein@aims.gov.au'

crwURL='ftp.star.nesdis.noaa.gov'
crwDir='pub/sod/mecb/crw/data/5km/v3.1/nc/v1.0/daily/'
for yy in `seq $yearStart $yearEnd`; do 
    echo $yy
    ftp -n $crwURL <<-GETFILES 
        prompt
        quote USER $USER
        quote PASS $PASSWD
        cd $crwDir$productName/$yy
        ls -1 filelist.tmp
        bye
GETFILES
cat filelist.tmp | grep -v -e "md5" >${productName}FileList_${yy}.txt

done

rm filelist.tmp
    
exit

