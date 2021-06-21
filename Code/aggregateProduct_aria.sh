#! /bin/bash
## Aggregate CRW products in yearly files clipped to a rectangular RoI

## Define year range and product
yearStart=2011
yearEnd=2020

## uncomment to select variable
## productName must be one of dhw, sst, ssta, hotspot
## product name long MUST match the long name of the product
## dhw -> degree_heatng_week
## ssta -> sea_surface_temperature_anomaly
## sst -> analysed_sst
## hs -> hotspot

# productName='sst'
productName='ssta'
# productName='dhw'
# productName='hs'

# productNameLong='analysed_sst'
productNameLong='sea_surface_temperature_anomaly'
# productNameLong='degree_heatng_week'
# productNameLong='hotspot'


## FTP credentials
USER='anonymous'
PASSWD='eklein@aims.gov.au'

## ftp source
crwURL='ftp.star.nesdis.noaa.gov'
crwDir='pub/sod/mecb/crw/data/5km/v3.1/nc/v1.0/daily/'
resultPath='./'
tmpPath="./tmp"

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
mkdir -p $tmpPath


## loop over the year range
for yy in `seq $yearStart $yearEnd`; do 
    ## get the list of fiels for a particular year
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
    ## add ftp info and save fileList
    ftpPath=${crwURL}/${crwDir}${productName}/${yy}
    cat filelist.tmp | grep -v -e "md5" >${productName}FileList_${yy}.tmp
    for ff in `cat ${productName}FileList_${yy}.tmp`
        do 
            echo ftp://${ftpPath}/${ff} >>${productName}FileList_${yy}.txt
        done
    rm ${productName}FileList_${yy}.tmp
    
    echo GETTING FILES...
    ## get one full year and aggregate into one file
    aria2c -d ${tmpPath} -i ${productName}FileList_${yy}.txt
    
    ## Loop over daily files
    for ff in `ls ${tmpPath}/*.nc`
        do
            yday=$(date -d $(echo $ff |cut -d _ -f 4 | cut -d. -f1) +%j)
            gdalwarp -t_srs epsg:4326 -te $lonMin $latMin $lonMax $latMax NETCDF:"CRWtemp.nc":${productNameLong} temp.nc
            ncap2 -s "TIME=${yday}; TIME@long_name=\"day_of_the_year\"; Band1@long_name=\"${productNameLong}\"; Band1@scale_factor = 0.01f" temp.nc
            ncrename -v Band1,${productNameLong} temp.nc
            ncecat -u TIME temp.nc ${outDir}/${roiName}${productName}_${ff}     ## add TIME as record dimension
            rm temp.nc
        done
        fileName=${roiName}${productName}_${yy}.nc
        ncrcat ${outDir}/*.nc ${outDirAgg}/$fileName
        
        ## Add global attrs
        ncap2 -s "global@geospatial_lat_min=${latMin}; global@geospatial_lat_max=${latMax}; global@geospatial_lon_min=${lonMin}; global@geospatial_lon_max=${lonMax};" ${fileName}
        ncap2 -s "global@temporal_coverage_start=${yearStart}; global@temporal_coverage_end=${yearEnd};" ${fileName}
        ncap2 -s "global@data_source=\"${crwURL}/${crwDir}${productName}/\";" ${fileName} 
        ## cleanup
        rm $tmpPath/*.nc
done

## TODO: add global metadata to the resulting file

