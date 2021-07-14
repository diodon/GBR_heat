#! /bin/bash
## Aggregate satellite products in yearly files clipped to a rectangular RoI or shapefile
## aggregate the recent files into year-to-date file.
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
currentYear=`date +%Y`

paramFile=$1
echo Parameter file is ${paramFile}

## read variables from params.json config file
params=`jq . ${paramFile}`
dataDir=`echo $params | jq -r .dataDir`
sourceURL=`echo $params | jq -r .sourceURL`
sourceDir=`echo $params | jq -r .sourceDir`
ftpUser=`echo $params | jq -r .ftpUser`
ftpPasswd=`echo $params | jq -r .ftpPasswd`

roiName=`echo $params | jq -r .roiName`
yearStart=${currentYear}-01-01
yearEnd=${todayDate}

## paramName must be one of dhw, sst, ssta, hotspot
## product name long MUST match the long name of the product
## dhw -> degree_heating_week
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
    shpExtent=`ogrinfo -al -geom=SUMMARY ${shpfileName} | grep Extent | cut -d: -f2`
    lonMin=`echo $shpExtent | cut -d\( -f2 | cut -d\, -f1`
    latMin=`echo $shpExtent | cut -d\( -f2 | cut -d\, -f2 | cut -d\) -f1`
    lonMax=`echo $shpExtent | cut -d\( -f3 | cut -d\, -f1`
    latMax=`echo $shpExtent | cut -d\( -f3 | cut -d\, -f2 | cut -d\) -f1`
fi


## results path
resultPath=${dataDir}/${roiName}                ## Base dir.            ex. /data/GBR
fileListPath=${resultPath}/${paramName}/Filelist_YtoD       ## FTP file names      ex. /data/GBR/dhw/Filelist_YtoD
tmpPath=${resultPath}/${paramName}/tmp_YtoD     ## FTP downloaded files ex. /data/GBR/dhw/tmp_YtoD
logDir=${resultPath}/${paramName}/log           ## log files            ex. /data/GBR/dhw/log
outDir=${resultPath}/${paramName}/CRW_YtoD      ## croped files         ex. /data/GBR/dhw/CRW_YtoD
outDirAgg=${outDir}_aggregate                   ## aggregated files     ex. /data/GBR/dhw/Filelist_YtoD_aggregate
mkdir -p $fileListPath
mkdir -p $tmpPath
mkdir -p $outDir
mkdir -p $outDirAgg
mkdir -p $logDir

## Logfile names. Aria log file is a huge file: 1y could be +50MB
logFile=$logDir/${roiName}${paramName}_YtoD_log.log
logFileAria=$logDir/${roiName}${paramName}_YtoD_aria.log

## log start. Reset aria log file
echo ========== >$logFileAria
echo ========== >>$logFile
echo `date`: START - processing $roiName $paramName from $yearStart thru $yearEnd. >$logFile
echo `date`: INFO - parameter file is ${paramFile} >$logFile


## log entry
echo `date`: PASS - start processing year $currentYear. >>$logFile

## get the list of fiels for a particular year
echo GETTING FILE LIST...
echo $currentYear

## this is with FTP. Slower but failproof
ftp -n $sourceURL <<-GETFILES 
    prompt
    quote USER $ftpUser
    quote PASS $ftpPasswd
    cd $sourceDir$paramName/${currentYear}
    ls -1 filelist.tmp
    bye
GETFILES

    ## check if the file of list of filesnames exists
    if [ ! -s filelist.tmp ]; then
        echo `date`: ERROR - unable to get filelist from FTP. Possible timeout. >>$logFile
        echo `date`: EXIT >>$logFile
        echo ========== >>$logFile
        exit
    fi 
    
    FileListNameRoot=${paramName}FileList_${currentYear}
    FileListCurrentTemp=${fileListPath}/${FileListNameRoot}.tmp
    ## remove .md5 files
    cat filelist.tmp | grep -v -e "md5" >${FileListCurrentTemp}
    fileLen=`wc -l ${FileListNameRoot}.tmp | cut -d\\  -f1`
    
    ## Log number of files
    echo `date`: PASS - $fileLen file names discovered from FTP. >>$logFile
 
    ## add ftp directory info to each file
    fileListCurrent=${fileListPath}/${FileListNameRoot}_NEW.txt
    > ${fileListCurrent}    ## reset file
    ftpPath=${sourceURL}/${sourceDir}${paramName}/${currentYear}
    for ff in `cat ${FileListCurrentTemp}`; do 
        echo ftp://${ftpPath}/${ff} >>${fileListCurrent}
    done
    
    ## identify and get the new files
    fileListYtoD=${fileListPath}/${FileListNameRoot}.txt
    fileListNew=${fileListPath}/${FileListNameRoot}_diff.txt
    if [ -s ${fileListYtoD} ]; then
        diff ${fileListCurrent} ${fileListYtoD} |  sed 1d | sed 's/< //' >${fileListNew}
        newRun=false
    else
        fileListNew=${fileListCurrent}
        newRun=true
    fi
        
    ## remove unused filenames list files
    rm ${FileListNameRoot}.tmp
    rm filelist.tmp
    
    echo GETTING FILES...
    ## get one full year of data
    aria2c -l ${logFileAria} -d ${tmpPath} -i ${fileListNew}
    fileLenAria=`ls ${tmpPath}/*.nc | wc -l`
    
    ## Log number downloaded files
    echo `date`: PASS - $fileLenAria files downloaded from FTP. >>$logFile
  
    
    ## Loop over daily files
    for ff in `ls ${tmpPath}/*.nc`
        do 
            ffclean=`echo $ff | rev | cut -d/ -f1 | rev`

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
                gdalwarp -t_srs epsg:4326 -te $lonMin $latMin $lonMax $latMax -cutline ${shpfileName} -of NETCDF -overwrite NETCDF:\"${ff}\":${paramNameLong} temp.nc
            fi
            ncap2 -s "time=${timeValueSecs}; time@long_name=\"reference time of the ${paramNameLong} field\"; time@standard_name=\"time\"; time@units=${timeValueSecsUnits}; Band1@long_name=\"${paramNameLong}\"; Band1@scale_factor = ${paramScaleFactor};" temp.nc
            ncrename -v Band1,${paramNameLong} temp.nc
            ncecat -u time temp.nc ${outDir}/${roiName}${paramName}_${ffclean}     ## add time as record dimension
        done
        
        ## Concatenate new files into the aggregated file. Omit history attribute
        fileName=${roiName}${paramName}_${currentYear}.nc
        if [ $newRun == true ]; then
            ncrcat -O -h ${outDir}/*.nc ${outDirAgg}/$fileName
        else
            ncrcat -O -h ${outDirAgg}/$fileName ${outDir}/*.nc ${outDirAgg}/$fileName
        fi
 

        ## Add global attrs
        ## get temporal coverage 
        timeStart=`ncks -H --jsn -v time ${outDirAgg}/${fileName} | jq .variables.time.data[0]`
        timeEnd=`ncks -H --jsn -v time ${outDirAgg}/${fileName} | jq .variables.time.data[-1]`
        epochYear=$(echo $timeValueSecsUnits | cut -d\  -f3)
        lastDate=`ncks --jsn -v time ${outDirAgg}/$fileName | jq .variables.time.data[-1]`
        lastDate=`date -d "${epochYear} ${lastDate} seconds" +%Y-%m-%d`

        timeStartDate=`date -d "${epochYear} ${timeStart} seconds" +%Y-%m-%d`
        timeEndDate=`date -d "${epochYear} ${timeEnd} seconds" +%Y-%m-%d`

        ncap2 -s "global@title=\"Daily ${paramNameLong} from ${roiName} region for year ${currentYear}\"; global@author=\"Eduardo Klein\"; global@creator_email=\"e.klein@aims.gov.au\"; global@creator_url=\"aims.gov.au\"; global@creation_date=\"${todayDate}\";" ${outDirAgg}/${fileName} 
        ncap2 -s "global@geospatial_crs=\"EPSG:4326\"; global@geospatial_lat_min=${latMin}; global@geospatial_lat_max=${latMax}; global@geospatial_lon_min=${lonMin}; global@geospatial_lon_max=${lonMax};" ${outDirAgg}/${fileName}
        ncap2 -s "global@temporal_coverage_start=\"${timeStartDate}\"; global@temporal_coverage_end=\"${lastDate}\";" ${outDirAgg}/${fileName}
        ncap2 -s "global@data_source=\"${sourceURL}/${sourceDir}${paramName}/\"; global@code_repository=\"https://github.com/diodon/GBR_heat\";" ${outDirAgg}/${fileName} 

        
        
        ## cleanup
        rm $tmpPath/*.nc
        rm ${outDir}/*.nc
        
        ## log entry
        echo `date`: PASS - Aggregation success! Data file for year $currentYear is ${outDir}/${roiName}${paramName}_${ffclean}. >>$logFile

##done

## Log END 
echo `date`: END  >>$logFile
echo ========== >>$logFile
