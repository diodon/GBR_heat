#! /bin/bash
## Aggregate satellite products in yearly files clipped to a rectangular RoI
## this is for NOAA's CRW 

## read variables from params.json config file
params=`jq . params.json`
sourceURL=`echo $params | jq -r .sourceURL`
sourceDir=`echo $params | jq -r .sourceDir`
ftpUser=`echo $params | jq -r .ftpUser`
ftpPasswd=`echo $params | jq -r .ftpPasswd`

roiName=`echo $params | jq -r .roiName`
yearStart=`echo $params | jq -r .yearStart`
yearEnd=`echo $params | jq -r .yearEnd`

latMin=`echo $params | jq -r .latMin`
latMax=`echo $params | jq -r .latMax`
lonMin=`echo $params | jq -r .lonMin`
lonMax=`echo $params | jq -r .lonMax`

## paramName must be one of dhw, sst, ssta, hotspot
## product name long MUST match the long name of the product
## dhw -> degree_heatng_week
## ssta -> sea_surface_temperature_anomaly
## sst -> analysed_sst
## hs -> hotspot
paramName=`echo $params | jq -r .paramName`
paramNameLong=`echo $params | jq -r .paramNameLong`

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
        quote USER $ftpUser
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
            ## NOTE: check if the time_coverage_start exits in the source file as global attr and the format of the value
            yday=$(date -d `ncks -M ${ff} | grep :time_coverage_start | cut -d\" -f2 | cut -dT -f1` +%j)
            if [ -z $shpName ]; then 
                gdalwarp -t_srs epsg:4326 -te $lonMin $latMin $lonMax $latMax -of NETCDF -overwrite NETCDF:"${ff}":${paramNameLong} temp.nc
            else 
                gdalwarp -t_srs epsg:4326 -cutline ${shpName} -of NETCDF -overwrite NETCDF:"${ff}":${paramNameLong} temp.nc
            fi
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

