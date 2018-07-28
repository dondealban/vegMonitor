# vegMonitor 

## Investigating losses in vegetation cover using remote sensing data and the Random Forests algorithm

This is a project which summarizes remote sensing data processing techniques in order to extract key vegetation data and indications about vegetation changes.

## Case study and objectives

The study area of this project is [Dharamshala Tehsil](https://en.wikipedia.org/wiki/Dharamshala), located in the Indian state of Himachal Pradesh. This region is famous for its natural and cultural beauty. Intense tourism and development in recent years has allegedly led to a large loss of local forest cover. In order to conduct an independent investigation of these changes, we suggest here a set of methodologies based on public remote-sensing data.

The end of goal of this project is to generate vegetation cover classification images of the study area from 2013-2017. With this images, we aim to develop a change detection technique that would indicate to us regions undergoing significant vegetation loss. These regions would then be flagged for further investigation.

## Guide to methodologies for Ubuntu 16.04

### 1. Pre-processing remote sensing data using Google Earth Engine

Firstly, we need to download relevant remote-sensing data for our purpose. The traditional means of going about this process would be to navigate to various data providers such as the USGS's [Earth-Explorer](https://earthexplorer.usgs.gov/) interface. Although this is a very interactive and comfortable interface, it does present us with some key limitations. For one, we are limited to how much we can query and filter large data before downloading it. This would mean we would need to download many GB's of data, only to use a few MB at the end. Next, we are also limited with how much data we can query at once. For example, the USGS Earth-Explorer interface only hosts certain datasets and perhaps not all the relevant ones. In order to access other datasets, we would need to navigate to another interface altogether. 

In order to overcome these issues, we propose using the Google Earth Engine (GEE). The Google Earth Engine is essentially a Javascript-based API hosted on Google's infrastructure. This API allows us to query a large volume of Earth observation datasets and to pre-process them before downloading. This provides an efficient means of data-processing for our needs. Here, we choose to download the Landsat 8 Surface Reflectance data. 

For a detailed look on how to acquire and pre-process remote sensing data, please refer to the following GitHub repository: https://github.com/AtreyaSh/geeBulkFilter

### 2. Supervised vegetation classification using field data and the Random Forests algorithm

`vegClassification.R` is a generic R-script containing a useful `vegClassify` function: https://github.com/AtreyaSh/vegMonitor/blob/master/vegClassification.R

```{r}
vegClassify(imgVector, baseShapefile, responseCol, predShapefile, bands, undersample, predImg, 
            ntry, genLogs, writePath, format)
```

**Arguments**

1. `imgVector` is a vector containing the absolute string paths with endings (eg. "/path/to/folder/xyz.tif") of single or multi-band images that are to be processed.

2. `baseShapefile` is a string path with ".shp" ending that contains polygons or point data for training the random forest model.

3. `responseCol` is a string that points the algorithm to the feature in `baseShapefile` that is needed for training. Defaults to `OBJECTID`.

4. `predShapefile` is a string path with ".shp" ending that contains polygon(s) which will mask the training image. Resulting masked image can be used for prediction. Will be ignored if no input provided.

5. `bands` is a numerical vector containing the necessary bands used for training. Defaults to all bands in image if no input provided.

6. `undersample` is a boolean which conducts undersampling on the training data to create a balanced training dataset. Defaults to "TRUE".

7. `predImg` is a boolean which uses trained random forest model to predict either the entire training image or a subset of it depending on `predShapefile`. Defaults to "TRUE".

8. `ntry` is a numerical value and represents the number of trees created in the random forests model. Defaults to "500".

9. `genLogs` is a boolean which results in logs of training, testing and variable importance to be created and written into `writePath`. Defaults to "TRUE".

10. `writePath` is a path directory which points the function on where to write the results of the function. Defaults to "./output/vegClassification".

11. `format` is a string which points how the resulting predicted raster should be written. Defaults to "GTiff".

    Other possibilities are listed here: https://www.rdocumentation.org/packages/raster/versions/2.6-7/topics/writeRaster

### 3. Vegetation loss detection using a custom-rasterized Mann-Whitney technique

`vegLossDetection.R` is a generic R-script with a useful function. This is still under development.
