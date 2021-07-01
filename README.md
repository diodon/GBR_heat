## GBR HEAT: automation of data aggregation

### Goal

This project aggregates [NOAA's Coral Reef Watch](https://coralreefwatch.noaa.gov/) products by year and by parameter in a ready to use netCDF files. Also, some R functions are provided to allow the user to interact with the aggregated products.

The aggregation process is done at to different levels:

1.  Aggregation of historical data prior the current year
2.  Aggregation of daily files (new data) into year-to-date files

### Requirements

The aggregation scripts are Bash scripts running in an Ubuntu 20.04 machine and require the following tools:

| Software | Use                                                                                                                                                                                                   | Version                                              |
|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------|
| GDAL     | To clip the global file to the ROI and re project to EPSG:4326 (`gdalwarp`)                                                                                                                           | GDAL 3.0.4, released 2020/01/28                      |
| NCO      |  to modify the variables and attributes in the netCDF file (`ncap2` and `ncrename`). To concatenate (`ncecat`) the files into yearly aggregations. To edit variable and global attributes (`ncattred`)| version 4.9.1                                        |
| jq       | to read and parse the json configuration file                                                                                                                                                         | jq-1.6                                               |
| aria2    | to download the source files from the \<ftp\> server, using multiple simultaneous threads                                                                                                             | aria2 version 1.35.0                                 |
| netcdf   | `ncdump` to collect the value of the variable `time` from the netcdf file                                                                                                                             | netcdf library version 4.7.3 of Jan 23 2020 04:18:16 |

### Pipeline process

#### Aggregation of historical data

The following steps are executed to produce the yearly aggregated files:

1.  Define the Region of Interest (ROI). The `roiName` is used as a identifying part of the file names. The rectangular area defined by corner lat/lon (`latMin`, `latMax`, `lonMin`, `lonMax`) are used to clip the region of interest.

For each year:

1.  Read the parameter file and extract the key values

2.  Connect to the \<ftp\> server and get the list of files from the `productName` and year. Clean the file list to keep only the `.nc` files

3.  Download all the files for the corresponding year using `aria2`. The files are stored in a `./tmp` directory

4.  Process the individual files:

    1.  Get the day of the year from the `time` variable. (*NOTE*: even if `time` is CF compliant variable, it could be product dependent. It must be reviewed if changed to other sources)

    2.  Clip the file to the ROI using the roi extent. If a shapefile is provided, the values inside the roi but outside the shape are masked.

    3.  Add `time` variable from the original file. Add `time` attributes

    4.  Rename `Band1` (as it is named after the clipping) to `paramNameLong`

    5.  Set `time` as record dimension

    6.  Save the file in a `roiName` + `paramName` directory

5.  After all individual files are processed, concatenate the files into a single yearly file, named `roiName` + `paramName` + year

6.  Add global attributes to the concatenated file

7.  Clean temporal directories


The process will create a directory structure under data storage dir and roi to store downloaded files (tmp/), to store processed individual files (CRW) and finally to store the aggregated files per year (CRW_aggregate). At the end of the process the data from tmp and CRW directories will be deleted.

In this example, PLW is the region of interest, dhw the CRW parameter: 

```
└── PLW
    └── dhw
        ├── CRW
        ├── CRW_aggregate
        ├── Filelist
        └── tmp
```


#### Aggregation of year-to-date data

TODO

#### Configuration file

The scripts will read a configuration file with the values of the operational variables. The configuration file must have the following keys (using DHW for the GBR region as an example):

    {
        "dataDir": "url root of the storage container",
        "sourceURL": "ftp.star.nesdis.noaa.gov",
        "sourceDir": "pub/sod/mecb/crw/data/5km/v3.1/nc/v1.0/daily",
        "ftpUser": "anonymous",
        "ftpPasswd": "eklein@aims.gov.au",
        "roiName": "GBR",
        "paramName": "dhw",
        "paramNameLong": "degree_heating_week",
        "yearStart": 2011,
        "yearEnd": 2020,
        "latMin": -28.5,
        "latMax": -6.5, 
        "lonMin": 140.5,
        "lonMax": 156.0,
        "shpFile": "shapefile name"
    }

If a polygon other than a rectangle is used to define the ROI, it must be submitted as an ESRI shapefile with ESPG:4326 (lat/lon WGS84) projection. If no shapefile will be use, the valu eof the key `shpfileName` MUST BE set to `none`.

### R functions

TO COMPLETE: better to link to a Rmarkdown doc.

These are functions to interact with the aggregated files.

    infoCRWmax_area = function(crwFilename, roiShape, mmmFilename, shpType='WKT', map=TRUE, verbose=TRUE)

    crwFilename: path of the CRW aggragated file. It could be a file with DHW, SSTA, or HOTSPOT
    roiShape: Area to crop the CRW data file. It could be a WKT string (default) or the name of an ESRI shapefile.
    mmmFilename: name of the climatological Maximum Monthly Mean. If provided, summary statistics of the MMM for roiShape are calculated
    shpType: type of the region of interest. WKT (default) or SHP
    map: make a map? Default TRUE
    verbose: if TRUE prints information about the process


    return: map, crwStats, crwStatsDate (date when the maximum valu occured), mmmStats
