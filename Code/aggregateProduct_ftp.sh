#! /bin/bash
## Aggregate DHW in yearly files
yearStart=1985
yearEnd=1995
productName='dhw'
productNameLong='degree_heating_week'

USER='anonymous'
PASSWD='eklein@aims.gov.au'

crwURL='ftp.star.nesdis.noaa.gov'
crwDir='pub/sod/mecb/crw/data/5km/v3.1/nc/v1.0/daily/'
resultPath='./'

## (rectangular) window details
## GBR
roiName='GBR_'
latMin=-28.5
latMax=-6.5
lonMin=140.5
lonMax=156.0

## create the target dir 
outDir=${resultPath}${roiName}$productName
outDirAgg=${outDir}_aggregate
mkdir -p $outDir
mkdir -p $outDirAgg

for yy in `seq $yearStart $yearEnd`; do 
    echo GETTING FILE LIST...
    echo $yy
    ftp -n $crwURL <<-GETFILES 
        prompt
        quote USER $USER
        quote PASS $PASSWD
        cd $crwDir$productName/$yy
        ls -1 filelist.tmp
        bye
GETFILES
    ## save fileList for future use
    cat filelist.tmp | grep -v -e "md5" >${productName}FileList_${yy}.txt
    echo GETTING FILES...
    ## get one year and aggregate into one file
    ftpPath=${crwURL}/${crwDir}${productName}/${yy}
    for ff in `cat ${productName}FileList_${yy}.txt`
        do
            yday=$(date -d $(echo $ff |cut -d _ -f 4 | cut -d. -f1) +%j)
            wget -O DHWtemp.nc ftp://$ftpPath/$ff
            gdalwarp -t_srs epsg:4326 -te $lonMin $latMin $lonMax $latMax NETCDF:"DHWtemp.nc":degree_heating_week temp.nc
            ncap2 -S DHW.nca temp.nc 
            ncrename -v Band1,DHW temp.nc
            ncap2 -s "TIME=${yday}; TIME@long_name=\"day_of_the_year\";" temp.nc
            ncecat -u TIME temp.nc ${outDir}/${roiName}${productName}_${ff}
            #ncks -v degree_heating_week -d lat,$latMn,$latMax -d lon,$lonMin,$lonMax DHWtemp.nc ${outDir}/${roiName}${productName}_${ff}
            rm temp.nc
        done
        ncrcat ${outDir}/*.nc ${outDirAgg}/${productName}_${yy}.nc
        ## cleanup
        rm $outDir/*.nc
done

rm filelist.tmp
    
exit

