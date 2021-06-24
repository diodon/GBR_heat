## GBR HEAT: automation of data aggregation

### Goal

This project aggregates [NOAA's Coral Reef Watch](https://coralreefwatch.noaa.gov/) products by year and by parameter in a ready to use netCDF files. Also, some R functions are provided to allow the user to interact with the aggregated products.

The aggregation process is done at to different levels:

1.  Aggregation of historical data prior the current year
2.  Aggregation of daily files (new data) into year-to-date files

### Requirements

The aggregation scripts are Bash scripts running in an Ubuntu 20.04 machine and require the following tools:

| Software | Use                                                                                                                                              | Version                                     |
|----------|--------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------|
| GDAL     | to clip the global file to the ROI and re project to EPSG:3226 (`gdalwarp`)                                                                      | GDAL 3.0.4, released 2020/01/28             |
| nco      | to modify the variables and attributes in the netCDF file (`ncap2` and `ncrename`). To concatenate (`ncecat`) the files into yearly aggregations | ncap2 version 4.9.1, ncrename version 4.9.1 |
| jq       | to read and parse the json configuration file                                                                                                    | jq-1.6                                      |

: Software requirements

### Pipeline process

#### Aggregation of historical data

#### Aggregation of year-to-date data

#### Configuration file

The scripts will read a configuration file with the values of the operational variables. The configuration file must have the following keys (using DHW for the GBR region):

    {
        "sourceURL": "ftp.star.nesdis.noaa.gov",
        "sourceDir": "pub/sod/mecb/crw/data/5km/v3.1/nc/v1.0/daily",
        "ftpUser": "anonymous",
        "ftpPasswd": "eklein@aims.gov.au",
        "roiName": "GBR_",
        "paramName": "dhw",
        "paramNameLong": "degree_heating_week",
        "yearStart": 2011,
        "yearEnd": 2020,
        "latMin": -28.5,
        "latMax": -6.5, 
        "lonMin": 140.5,
        "lonMax": 156.0,
        "shpFile": ""
    }
