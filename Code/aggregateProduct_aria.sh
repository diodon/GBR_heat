#! /bin/bash
## Aggregate satellite products in yearly files clipped to a rectangular RoI
## this is for NOAA's CRW 

## read variables from params.json config file
sourceURL=`jq -r .sourceURL params.json`
sourceDir=`jq -r .sourceDir params.json`
ftpUser=`jq -r .ftpUser params.json`
ftpPasswd=`jq -r .ftpPasswd params.json`

roiName=`jq -r .roiName params.json`
yearStart=`jq -r .yearStart params.json`
yearEnd=`jq -r .yearEnd params.json`

latMin=`jq -r .latMin params.json`
latMax=`jq -r .latMax params.json`
lonMin=`jq -r .lonMin params.json`
lonMax=`jq -r .lonMax params.json`

## paramName must be one of dhw, sst, ssta, hotspot
## product name long MUST match the long name of the product
## dhw -> degree_heatng_week
## ssta -> sea_surface_temperature_anomaly
## sst -> analysed_sst
## hs -> hotspot
paramName=`jq -r .paramName params.json`
paramNameLong=`jq -r .paramNameLong params.json`

## results path
resultPath='./'
tmpPath="./tmp"
outDir=${resultPath}${roiName}$paramName
outDirAgg=${outDir}_aggregate
mkdir -p $outDir
mkdir -p $outDirAgg
mkdir -p $tmpPath


## loop over the year range
for yy in `seq $yearStart $yearEnd`; do 
    ## get the list of fiels for a particular year
    echo GETTING FILE LIST...
    echo $yy
    
    ## this is with FTP. Slower but failproof
    ftp -n $sourceURL <<-GETFILES 
        prompt
        quote ftpUser $ftpUser
        quote PASS $ftpPasswd
        cd $sourceDir$paramName/$yy
        ls -1 filelist.tmp
        bye
GETFILES

    fileLen=`wc -l filelist.tmp | cut -d\\   -f1`
    if [ $fileLen -lt 730 ]
        then
            echo 'ERROR: Possible incomplete file list'
            exit
        fi
    
    ## add ftp info and save fileList
    ftpPath=${sourceURL}/${sourceDir}${paramName}/${yy}
    cat filelist.tmp | grep -v -e "md5" >${paramName}FileList_${yy}.tmp
    for ff in `cat ${paramName}FileList_${yy}.tmp`
        do 
            echo ftp://${ftpPath}/${ff} >>${paramName}FileList_${yy}.txt
        done
    rm ${paramName}FileList_${yy}.tmp
    
    echo GETTING FILES...
    ## get one full year and aggregate into one file
    aria2c -d ${tmpPath} -i ${paramName}FileList_${yy}.txt
    
    ## Loop over daily files
    for ff in `ls ${tmpPath}/*.nc`
        do 
            ffclean=`echo $ff | cut -d/ -f3`
            yday=$(date -d `ncks -M ${ff} | grep :time_coverage_start | cut -d\" -f2 | cut -dT -f1` +%j)
            gdalwarp -t_srs epsg:4326 -te $lonMin $latMin $lonMax $latMax -of NETCDF -overwrite NETCDF:"${ff}":${paramNameLong} temp.nc
            ncap2 -s "TIME=${yday}; TIME@long_name=\"day_of_the_year\"; Band1@long_name=\"${paramNameLong}\"; Band1@scale_factor = 0.01f" temp.nc
            ncrename -v Band1,${paramNameLong} temp.nc
            ncecat -u TIME temp.nc ${outDir}/${roiName}${paramName}_${ffclean}     ## add TIME as record dimension
        done
        fileName=${roiName}${paramName}_${yy}.nc
        ncrcat ${outDir}/*.nc ${outDirAgg}/$fileName
        
        ## Add global attrs
        ncap2 -s "global@geospatial_lat_min=${latMin}; global@geospatial_lat_max=${latMax}; global@geospatial_lon_min=${lonMin}; global@geospatial_lon_max=${lonMax};" ${fileName}
        ncap2 -s "global@temporal_coverage_start=${yearStart}; global@temporal_coverage_end=${yearEnd};" ${fileName}
        ncap2 -s "global@data_source=\"${sourceURL}/${sourceDir}${paramName}/\";" ${fileName} 
        ## cleanup
        rm $tmpPath/*.nc
        rm ${outDir}/*.nc
done

## TODO: add global metadata to the resulting file

