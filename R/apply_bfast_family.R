require(raster)
require(plyr)
require(tidyverse)
require(bfastSpatial)   # See http://www.loicdutrieux.net/bfastSpatial/
require(sp)
require(rgrowth)
require(bfastPlot)


# The Landsat NDMI time stack
list.files("rds")
NDMI.DG1 <- read_rds("data/data3/rds/NDMITimeStack_L578_KalArea1_selectDG_1.rds")
NDMI.DG2 <- read_rds("data/data3/rds/NDMITimeStack_L578_KalArea1_selectDG_2.rds")

# Go to arcmap, make mesh polygons and points from the Landsat pixels, select example polygons (= pixels) [DONE]
# Now import the selected mesh points (= pixels) to extract the time series
selectLandsatPixels.DG1 <- readOGR(dsn = "data/data3/shp", layer = "meshSelect_prevDG1_label_ok")
selectLandsatPixels.DG2 <- readOGR(dsn = "data/data3/shp", layer = "meshSelect_prevDG2_label_ok")


#################################################################################################################
# Extract the NDMI at select Landsat pixels --------------------------------
##################################################################################################################

extrNDMI.DG1 <- raster::extract(x = NDMI.DG1, y = selectLandsatPixels.DG1,                                 # DG1
                                  method = "simple",            # no need buffer to account geometric error cause we are concerned with pixel-specific time series and relative changes
                                  cellnumbers = TRUE, df = TRUE)

extrNDMI.DG2 <- raster::extract(x = NDMI.DG2, y = selectLandsatPixels.DG2, method = "simple",              # DG2    
                                cellnumbers = TRUE, df = TRUE)


extrNDMI.DG1$pixId <- selectLandsatPixels.DG1$Id_1    # Add pixel ID
extrNDMI.DG2$pixId <- selectLandsatPixels.DG2$Id_1

extrNDMI.DG1$Visual <- selectLandsatPixels.DG1$Visual  # Add pixel visual interpretation
extrNDMI.DG2$Visual <- selectLandsatPixels.DG2$Visual


#################################################################################################################
# Plot and print the time series --------------------------------
##################################################################################################################

plot.extrTS <- function(which.extrTS, which.x, my.ylab, my.ylim) {
  
  temp.TS <- unlist(which.extrTS[which.x, -c(1,2,ncol(which.extrTS),ncol(which.extrTS)-1)])
  pixel.ID <- unlist(which.extrTS[which.x, "pixId"])
  temp.TS.df <- tibble(date = getSceneinfo(names(temp.TS))$date,
                       value = unname(temp.TS))
  
  # There can be several observations for same date, just take the mean
  temp.TS.df.unique <- temp.TS.df %>% group_by(date) %>% summarize(value = mean(value, na.rm = TRUE))
  
  # Create zoo time series object
  zoo.TS <- zoo(x = temp.TS.df.unique$value, order.by = temp.TS.df.unique$date)
  plot(zoo.TS, type = 'p', cex = 1, ylim = my.ylim, pch = 19, xlim = c(start(zoo.TS), end(zoo.TS)),
       xlab = "Date", ylab = my.ylab, main = paste("pixel ID ", pixel.ID, sep = ""))
  v <- as.numeric(as.Date(paste0(seq(1988,2018,by=1),'-01-01')))
  abline(v = v,lty = "dotted",col = "gray20",lwd = 1)

}


# Loop through time series and plot 4 time series in one page
# Here 12 time series. Do manually for the rest time series not in 1-4,5-8,...
for(k in seq(1, 12, by = 4)) {                                                                   
  filename <- paste(k, "_", k+3, ".pdf", sep = "")
  pdf(paste("figures/", filename, sep = ""),    # Change output dir here
      width = 7, height = 9, pointsize = 10)  
  par(mfrow = c(4,1))
  for(x in k:(k+3)) plot.extrTS(extrNDMI.DG1, x, "NDMI", c(-0.4,0.8))                            # Function called here, change arguments
  dev.off()
}  



#################################################################################################################
# Apply BFAST to individual time series  --------------------------------
##################################################################################################################
which.extrTS <- extrNDMI.DG1                   # time series in Which DG scene?
which.pixId <- 677                             # which pixel ID?  

temp.TS <- unlist(which.extrTS[which.extrTS$pixId == which.pixId, -c(1,2,ncol(which.extrTS),ncol(which.extrTS)-1)])
temp.TS.df <- tibble(date = getSceneinfo(names(temp.TS))$date,
                     value = unname(temp.TS))

# There can be several observations for same date, just take the mean
temp.TS.df.unique <- temp.TS.df %>% group_by(date) %>% summarize(value = mean(value, na.rm = TRUE))

# Create zoo time series object
zoo.TS <- zoo(x = temp.TS.df.unique$value, order.by = temp.TS.df.unique$date)

# Cut time series until 31 Dec 2015
zoo.TS <- window(zoo.TS, start = start(zoo.TS), end = as.Date("2015-12-31"))

# Interpolate time steps.
bts <- bfastts(zoo.TS, dates = time(zoo.TS), type = "irregular")

# Run bfastmonitor with different model formulations
bfm.H <- bfastmonitor(bts, start = c(2005,1), formula = response~harmon, order = 1, plot = TRUE, h = 0.25, history = "all")  
bfm.T <- bfastmonitor(bts, start = c(2005,1), formula = response~trend, order = 1, plot = TRUE, h = 0.25, history = "all")
bfm.TH <- bfastmonitor(bts, start = c(2005,1), formula = response~harmon+trend, order = 1, plot = TRUE, h = 0.25, history = "all")   

# Check bfm result
bfm.H
bfm.H$magnitude
summary(bfm.H$model)
plot(bfm.H$mefp, functional = NULL)
plot(bfm.H, ylim = c(-0.4,0.8), cex = 1, xlab = "Date", ylab = "NDMI")


#################################################################################################################
# Apply REGROWTH --------------------------------
##################################################################################################################
which.bfm <- bfm.H                   
reg <- tsreg(zoo.TS, change = which.bfm$breakpoint, h = 0.5, plot = TRUE)            # input is raw time series, not interpolated one (bts)
print(reg)

#################################################################################################################
# Apply sequential-BFAST  --------------------------------
##################################################################################################################
p <- 2; years <- seq(2000, 2015, by = p)              

bfmSeq.H <- lapply(years, 
                    FUN = function(z) bfastmonitor(window(bts, end = c(z + p, 1)), start = c(z, 1), history = "ROC", 
                                                   formula = response ~ harmon, order = 1, h = 0.25))

# Plot the result
plot.bfmSeq <- bfmPlot(bfmSeq.TH, plotlabs = years, displayTrend = TRUE, displayMagn = TRUE, displayResiduals = "monperiod") + 
  theme_bw() + scale_y_continuous(limits = c(-0.4,0.8))
plot.bfmSeq



#################################################################################################################
# Run BFAST Spatial to all pixels --------------------------------
##################################################################################################################
# Need to make each raster layer is unique data, so average (na.rm = T) the raster when date is same

temp <- table(getZ(NDMI.DG1)); temp <- as_tibble(temp)           # There are dates with multiple layers
temp2 <- names(NDMI.DG1)                # the layer names are unique
temp3 <- temp[temp$n > 1,]              # Z attribute = dates with multiple layers
temp4 <- which(as.character(getZ(NDMI.DG1)) %in% temp3$Var1)    # Which layer number (ordered) belongs to the dates with multiple layers?
temp5 <- subset(NDMI.DG1, temp4)
temp6 <- which(!as.character(getZ(NDMI.DG1)) %in% temp3$Var1)   # Which layer number (ordered) NOT belongs to the dates with multiple layers?
temp7 <- subset(NDMI.DG1, temp6)

# Take the mean of duplicated dates
k12.init <- temp5[[1]]; k12.init <- setZ(k12.init, z =  getZ(temp5)[1])      # Initialize storage variable
k12.init[] <- NA
names(k12.init) <- "init"

for(k in seq(1, nlayers(temp5), by = 2)) {     
  
  k1 <- temp5[[k]]; k1 <- setZ(k1, z = getZ(temp5)[k])
  k2 <- temp5[[k+1]]; k2 <- setZ(k2, z =  getZ(temp5)[k+1])                           # This works because each dates have exactly two scenes
  k12 <- stack(k1, k2)
  k12.mean <- mean(k12, na.rm = TRUE)
  names(k12.mean) <- names(k1); k12.mean <- setZ(k12.mean, z =  getZ(temp5)[k]) 
  k12.init <- stack(k12.init, k12.mean)
  
}


k12.init <- subset(k12.init, 2:nlayers(k12.init))   # Remove the first layer i.e. init


NDMI.DG1.uniqueDates <- stack(temp7, k12.init)      # Merge back with images with one date (temp7)

# SetZ and Re-order layers by dates
NDMI.DG1.uniqueDates <- setZ(NDMI.DG1.uniqueDates, getSceneinfo(names(NDMI.DG1.uniqueDates))$date, name = 'time')   
View(table(getZ(NDMI.DG1.uniqueDates)))

NDMI.DG1.uniqueDates <- subset(NDMI.DG1.uniqueDates, order(getZ(NDMI.DG1.uniqueDates)))
getZ(NDMI.DG1.uniqueDates)


# Run BFAST Spatial 
time.DG1 <- system.time(
  bfmArea.DG1 <- bfmSpatial(NDMI.DG1.uniqueDates, start = c(2005, 1), order = 1, h = 0.25, 
                            formula = response ~ harmon, history = "all",                    
                            monend = c(2015,221))                                            # Set end monitoring period to 8 Aug 2015
)


# Change date
change <- raster(bfmArea.DG1, 1)
x11()
plot(change)

# Change magnitude
magn <- raster(bfmArea.DG1, 2)                                    
magn.bkp <- magn                    # make a version showing only breakpoint pixels
magn.bkp[is.na(change)] <- NA

x11()
op <- par(mfrow=c(1, 2))
plot(magn.bkp, main="Magnitude: breakpoints")
plot(magn, main="Magnitude: all pixels")



#################################################################################################################
# Apply REGROWTH to all pixels  --------------------------------
##################################################################################################################
# TODO: Cut NDMI.DG1.uniqueDates raster time stack to 8 Aug 2015

time.DG1.reg <- system.time(
  regrowArea.DG1 <- regSpatial(NDMI.DG1.uniqueDates, change = bfmArea.DG1$breakpoint, h = 0.5, type = "16-day") 
)

plot(regrowArea.DG1)



