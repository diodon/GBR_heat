#! /bin/bash
## Aggregate satellite products in yearly files clipped to a rectangular RoI or shapefile
## Eduardo Klein. eklein at ocean-analytics dot com dot au
## see documentation and source at github diodon GBR_heat
## June 2020
##
## this is for NOAA's CRW 
##

if [ -z $1 ]; then
    echo 'ERROR. Need a parameter file name. EXIT'
    exit
fi


todayDate=`date`

paramFile=$1
## read variables from params.json config file
params=`jq . ${1}`
sourceURL=`echo $params | jq -r .sourceURL`
sourceDir=`echo $params | jq -r .sourceDir`
ftpUser=`echo $params | jq -r .ftpUser`
ftpPasswd=`echo $params | jq -r .ftpPasswd`

roiName=`echo $params | jq -r .roiName`
yearStart=`echo $params | jq -r .yearStart`
yearEnd=`echo $params | jq -r .yearEnd`

## paramName must be one of dhw, sst, ssta, hotspot
## product name long MUST match the long name of the product
## dhw -> degree_heatng_week
## ssta -> sea_surface_temperature_anomaly
## sst -> analysed_sst
## hs -> hotspot
paramName=`echo $params | jq -r .paramName`
paramNameLong=`echo $params | jq -r .paramNameLong`

latMin=`echo $params | jq -r .latMin`
latMax=`echo $params | jq -r .latMax`
lonMin=`echo $params | jq -r .lonMin`
lonMax=`echo $params | jq -r .lonMax`
shpfileName=`echo $params | jq -r .shpfileName`

## get bounding box in case of shapefile
if [ ! $shpfileName == 'none' ]; then
    shpExtent=`ogrinfo -al -geom=SUMMARY ${shpName} | grep Extent | cut -d: -f2`
    lonMin=`echo $shpExtent | cut -d\( -f2 | cut -d\, -f1`
    latMin=`echo $shpExtent | cut -d\( -f2 | cut -d\, -f2 | cut -d\) -f1`
    lonMax=`echo $shpExtent | cut -d\( -f3 | cut -d\, -f1`
    latMax=`echo $shpExtent | cut -d\( -f3 | cut -d\, -f2 | cut -d\) -f1`
fi


## results path
resultPath=/data/${roiName}
fileListPath=${resultPath}/${paramName}/Filelist
tmpPath=${resultPath}/${paramName}/tmp
outDir=${resultPath}/${paramName}/CRW
outDirAgg=${outDir}_aggregate
mkdir -p $fileListPath
mkdir -p $tmpPath
mkdir -p $outDir
mkdir -p $outDirAgg

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

    ## check if got a full file list
    ## TODO: make it to detect gaps not number of files. programm n repeated tries
    ## check if list of files file exists
    if [ ! -e filelist.tmp ]; then
        echo ERROR: unable to get filelist from FTP. Possible timeout. EXIT
        exit
    fi 
    ## Check if the number of file names is less than 265*2, including the .md5 checksum file
    fileLen=`wc -l filelist.tmp | cut -d\\   -f1`
    if [ $fileLen -lt 730 ]; then
        echo 'ERROR: Possible incomplete file list. EXIT'
        exit
    fi
    
    ## add ftp info to the file name and save fileList
    ftpPath=${sourceURL}/${sourceDir}${paramName}/${yy}
    cat filelist.tmp | grep -v -e "md5" >${paramName}FileList_${yy}.tmp
    for ff in `cat ${paramName}FileList_${yy}.tmp`
        do 
            echo ftp://${ftpPath}/${ff} >>${fileListPath}/${paramName}FileList_${yy}.txt
        done
    ## remove unused file list files
    rm ${paramName}FileList_${yy}.tmp
    rm filelist.tmp
    
    echo GETTING FILES...
    ## get one full year of data
    aria2c -d ${tmpPath} -i ${fileListPath}/${paramName}FileList_${yy}.txt
    
    ## Loop over daily files
    for ff in `ls ${tmpPath}/*.nc`
        do 
            ffclean=`echo $ff | cut -d/ -f3`
            
            ## get time value and scale factor from original file
            ## NOTE: time is supossed to be a CF standard variable. Check in the source
            timeValue=`ncdump -i -v time ${ff} | grep time\ =\ \" | cut -d\" -f2 | cut -dT -f1`
            timeValueSecs=`ncdump -v time ${ff} | tail -2 | head -1 | cut -d\  -f4`
            timeValueSecsUnits=\"`ncdump -h ${ff} | grep time:units | cut -d\" -f2`\"
            ## get parameter scale factor if any
            paramScaleFactor=`ncdump -h $ff | grep ${paramNameLong}:scale_factor | cut -d\  -f3`
            if [ -z $paramScaleFactor ]; then
                paramScaleFactor=1.0
            fi

            
            if [ $shpfileName == 'none' ]; then 
                gdalwarp -t_srs epsg:4326 -te $lonMin $latMin $lonMax $latMax -of NETCDF -overwrite NETCDF:\"${ff}\":${paramNameLong} temp.nc
            else 
                gdalwarp -t_srs epsg:4326 -cutline ${shpfileName} -of NETCDF -overwrite NETCDF:\"${ff}\":${paramNameLong} temp.nc
            fi
            ncap2 -s "TIME=${timeValueSecs}; TIME@long_name=\"reference time of the ${paramNameLong} field\"; TIME@standard_name=\"time\"; TIME@units=${timeValueSecsUnits}; Band1@long_name=\"${paramNameLong}\"; Band1@scale_factor = ${paramScaleFactor};" temp.nc
            ncrename -v Band1,${paramNameLong} temp.nc
            ncecat -u TIME temp.nc ${outDir}/${roiName}${paramName}_${ffclean}     ## add TIME as record dimension
        done
        
        ## Concatenate one year into one file. Omit history attribute
        fileName=${roiName}${paramName}_${yy}.nc
        ncrcat -h ${outDir}/*.nc ${outDirAgg}/$fileName
        
        ## Add global attrs
        ## get temporal coverage 
        timeStart=`ncks -H --jsn -v TIME ${outDirAgg}/${fileName} | jq .variables.TIME.data[1]`
        timeEnd=`ncks -H --jsn -v TIME ${outDirAgg}/${fileName} | jq .variables.TIME.data[-1]`
        epochYear=$(echo $timeValueSecsUnits | cut -d\  -f3)
        timeStartDate=`date -d "${epochYear} ${timeStart} seconds" +%Y-%m-%d`
        timeEndDate=`date -d "${epochYear} ${timeEnd} seconds" +%Y-%m-%d`

        ncap2 -s "global@title=\"Daily ${paramNameLong} from ${roiName} region for year ${yy}\"; global@author=\"Eduardo Klein\"; global@creator_email=\"e.klein@aims.gov.au\"; global@creator_url=\"aims.gov.au\"; global@creation_date=\"${todayDate}\";" ${outDirAgg}/${fileName} 
        ncap2 -s "global@geospatial_crs=\"EPSG:4326\"; global@geospatial_lat_min=${latMin}; global@geospatial_lat_max=${latMax}; global@geospatial_lon_min=${lonMin}; global@geospatial_lon_max=${lonMax};" ${outDirAgg}/${fileName}
        ncap2 -s "global@temporal_coverage_start=\"${timeStartDate}\"; global@temporal_coverage_end=\"${timeEndDate}\";" ${outDirAgg}/${fileName}
        ncap2 -s "global@data_source=\"${sourceURL}/${sourceDir}${paramName}/\"; global@code_repository=\"https://github.com/diodon/GBR_heat\";" ${outDirAgg}/${fileName} 
        ## cleanup
        rm $tmpPath/*.nc
        rm ${outDir}/*.nc
done
