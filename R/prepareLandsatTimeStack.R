## This code takes the Landsat image time stack downloaded from GEE and prepare them to be ready for running BFAST Spatial
# Test data in folder data/data2

require(raster)
require(plyr)
require(tidyverse)
require(bfastSpatial)


# Read the image time stack downloaded from GEE
imgTimeStack_L5 <- brick("landsat5NDMI_square_15.tif")   # Landsat-5, "square 15" is just      

imgTimeStack_L7 <- brick("landsat7NDMI_square_15.tif")   # Landsat-7    

imgTimeStack_L8 <- brick("landsat8NDMI_square_15.tif")   # Landsat-8     


# Read the scene ID saved by copy-pasting from GEE console
sceneId_L5 <- read_csv("square_15_L5.csv")
sceneId_L5 <- sceneId_L5[seq(2,nrow(sceneId_L5),by=2),]

sceneId_L7 <- read_csv("square_15_L7.csv")
sceneId_L7 <- sceneId_L7[seq(2,nrow(sceneId_L7),by=2),]

sceneId_L8 <- read_csv("square_15_L8.csv")
sceneId_L8 <- sceneId_L8[seq(2,nrow(sceneId_L8),by=2),]

names(imgTimeStack_L5) <- sceneId_L5$header             ## Rename the brick with scene id
names(imgTimeStack_L7) <- sceneId_L7$header
names(imgTimeStack_L8) <- sceneId_L8$header

# Stack across sensors
imgTimeStack_L578 <- addLayer(imgTimeStack_L5, imgTimeStack_L7, imgTimeStack_L8)

imgTimeStack_L578 <- setZ(imgTimeStack_L578, getSceneinfo(names(imgTimeStack_L578))$date, name = 'time')    # Set time attribute in z slot

# Sort raster layers by dates
imgTimeStack_L578 <- subset(imgTimeStack_L578, order(getZ(imgTimeStack_L578)))
getZ(imgTimeStack_L578)

# Write to disk, change the output file name
write_rds(imgTimeStack_L578, 
          "NDMITimeStack_L578_sq_15.rds")
