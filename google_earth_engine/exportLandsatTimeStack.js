
// Case study area for image stack export
var square_1 = ee.FeatureCollection("users/hadicu06/square_1");  // square_1 is polygon (shp) imported into GEE Assets
Map.addLayer(square_1, {}, 'square_1');

var caseStudyArea = square_1;                          // Change study area here!!!
Map.addLayer(caseStudyArea, {}, 'caseStudyArea');
Map.centerObject(caseStudyArea);

var Landsat_5_BANDS = ['B1',   'B2',    'B3',  'B4',  'B5',  'B7', 'cfmask'];
var Landsat_7_BANDS = ['B1',   'B2',    'B3',  'B4',  'B5',  'B7', 'cfmask'];
var Landsat_8_BANDS = ['B2',   'B3',    'B4',  'B5',  'B6',  'B7', 'cfmask'];
var STD_NAMES = ['blue', 'green', 'red', 'nir', 'swir1', 'swir2', 'cfmask'];

// create function to mask clouds, cloud shadows, snow using the cfmask layer in SR products
var maskClouds = function(image){
  var cfmask = image.select('cfmask');    
  return image.updateMask(cfmask.lt(1))   // keep only clear pixels (cfmask = 0)
              .clip(caseStudyArea);       // clip image to case study area
};


// Function to calculate Vegetation Indices
function addVI(image) {
  // var nbr = image.normalizedDifference(['nir', 'swir2']);
  var ndmi = image.normalizedDifference(['nir', 'swir1']);          // nbr or ndmi or ndvi
  // var ndvi = image.normalizedDifference(['nir', 'red']);
  // var evi = image.expression(
  //  '2.5 * (0.0001*NIR - 0.0001*R) / (0.0001*NIR + 6*0.0001*R - 7.5*0.0001*B + 1)',
  //  {
  //    R: image.select('red'),     
  //   NIR: image.select('nir'),     
  //    B: image.select('blue')     
  //  });
  
  return image.select([]) // Need to return same image as input
              .addBands([ndmi])                                         // nbr or ndmi or ndvi or evi
              .rename(['ndmi']) // rename bands                         // nbr or 'ndmi' or ndvi or evi
              .copyProperties(image, image.propertyNames());
} 


// Function to get scene id
var scene_ids = function(coll) {
    return coll.toList(coll.size(), 0).map(function(im) {
      // Get the image ID and strip off the first four chars '1_1_'
      // Untested other than this script 
      return ee.String(ee.Image(im).id());
    });
  };


////////////////////////////////////////////////////////////////////////////////////
// Landsat-5
////////////////////////////////////////////////////////////////////////////////////
// Import L5 collections 
var landsat5 = ee.ImageCollection('LANDSAT/LT5_SR')
    .filterDate('1984-01-01', '2012-05-05')               
    .select(Landsat_5_BANDS, STD_NAMES)                               
    .filterBounds(caseStudyArea).map(maskClouds);                       
print(landsat5.size(), 'landsat5.size()');  

// Calculate Vegetation Indices
var landsat5addVI = landsat5.map(addVI); 
print(landsat5addVI.first(), 'landsat5addVI.first()');

var vis = {palette: ['green', 'red'], min: 0.5};
Map.addLayer(ee.Image(landsat5addVI.first()), vis, 'landsat5addVI.first()'); // this shows nothing cause the first date image is entirely not clear in the clip area

// From image collection to multiband image, rename bands as image dates
var empty = ee.Image().select();
var landsat5VImultiband = landsat5addVI.iterate(function(image, result) {
  return ee.Image(result).addBands(image.select(['ndmi'], [ee.Date(image.get('system:time_start')).format('YYYY-MM-dd')]));    
    }, empty);                            // above nbr or ndmi or ndvi or evi 

print(landsat5VImultiband, 'landsat5VImultiband');
// Map.addLayer(ee.Image(landsat5VImultiband).select('2010-08-30'), {}, 'landsat5VImultiband_oneDate');

// Export multiband (multidates) image
Export.image.toDrive({  // or toDrive
  image: landsat5VImultiband,
  description: 'landsat5NDMI_square_1',   // NBR or NDMI or NDVI or EVI; KalArea1 or KalArea2
  region: caseStudyArea,
  maxPixels: 1e12,
  scale: 30             // Important! 30 meter in this case of Landsat
});


// The exported TIF loses band names (= dates), so need to save the band names
var sceneId = scene_ids(landsat5addVI);
print(sceneId, "sceneIdLandsat5");
// Not yet figure out how to export the list to Drive, so just copy from console to excel for now 


////////////////////////////////////////////////////////////////////////////////////
// Landsat-7
////////////////////////////////////////////////////////////////////////////////////

// Import L7 collections 
var landsat7 = ee.ImageCollection('LANDSAT/LE7_SR')
    .filterDate('1999-01-01', '2017-08-31')                            
    .select(Landsat_7_BANDS, STD_NAMES)                                
    .filterBounds(caseStudyArea).map(maskClouds);                       
print(landsat7.size(), 'landsat7.size()');          // 291


// Calculate Vegetation Indices
var landsat7addVI = landsat7.map(addVI); 
print(landsat7addVI.first(), 'landsat7addVI.first()');

var vis = {palette: ['green', 'red'], min: 0.5};
Map.addLayer(ee.Image(landsat7addVI.first()), vis, 'landsat7addVI.first()'); // this shows nothing cause the first date image is entirely not clear in the clip area

// From image collection to multiband image, rename bands as image dates
var empty = ee.Image().select();
var landsat7VImultiband = landsat7addVI.iterate(function(image, result) {
  return ee.Image(result).addBands(image.select(['ndmi'], [ee.Date(image.get('system:time_start')).format('YYYY-MM-dd')]));    
    }, empty);                              // above ndmi or nbr or ndvi or evi

print(landsat7VImultiband, 'landsat7VImultiband');
// Map.addLayer(ee.Image(landsat7VImultiband).select('2016-12-28'), {}, 'landsat7VImultiband_oneDate');

// Export multiband (multidates) image
Export.image.toDrive({  // or toDrive
  image: landsat7VImultiband,
  description: 'landsat7NDMI_square_1',        // NBR or NDMI or NDVI or Nir; KalArea1 or KalArea2
  region: caseStudyArea,
  maxPixels: 1e12,
  scale: 30             // Important! 30 meter in this case of Landsat
});


// The exported TIF loses band names (= dates), so need to save the band names
var sceneId = scene_ids(landsat7addVI);
print(sceneId, "sceneIdLandsat7");


////////////////////////////////////////////////////////////////////////////////////
// Landsat-8
////////////////////////////////////////////////////////////////////////////////////
// Import L8 collections 
var landsat8 = ee.ImageCollection('LANDSAT/LC8_SR')
    .filterDate('2013-04-11', '2017-08-31')    // ('2013-04-11', '2017-06-01') // ('2014-04-11', '2016-06-01')
    .select(Landsat_8_BANDS, STD_NAMES)
    .filterBounds(caseStudyArea).map(maskClouds);
print(landsat8.size(), 'landsat8.size()');     // 137
print(landsat8, 'landsat8');


// Calculate Vegetation Indices
var landsat8addVI = landsat8.map(addVI); 
print(landsat8addVI.first(), 'landsat8addVI.first()');

var vis = {palette: ['green', 'red'], min: 0.5};
Map.addLayer(ee.Image(landsat8addVI.first()), vis, 'landsat8addVI.first()'); // this shows nothing cause the first date image is entirely not clear in the clip area

// From image collection to multiband image, rename bands as image dates
var empty = ee.Image().select();
var landsat8VImultiband = landsat8addVI.iterate(function(image, result) {
  return ee.Image(result).addBands(image.select(['ndmi'], [ee.Date(image.get('system:time_start')).format('YYYY-MM-dd')]));    
    }, empty);                           // above nbr or ndmi or ndvi or evi

print(landsat8VImultiband, 'landsat8VImultiband');
// Map.addLayer(ee.Image(landsat8VImultiband).select('2017-03-10'), {}, 'landsat8VImultiband_oneDate');

// Export multiband (multidates) image
Export.image.toDrive({  // or toDrive
  image: landsat8VImultiband,
  description: 'landsat8NDMI_square_1',     // NBR or NDMI or NDVI or EVI; KalArea1 or KalArea2
  region: caseStudyArea,
  maxPixels: 1e12,
  scale: 30             // Important! 30 meter in this case of Landsat
});

// The exported TIF loses band names (= dates), so need to save the band names
var sceneId = scene_ids(landsat8addVI);
print(sceneId, "sceneIdLandsat8");