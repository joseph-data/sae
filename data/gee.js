// ====================================================================
// ANNUAL GEOINDICATORS FOR SWEDEN (COUNTY LEVEL) – 2024
// Computes yearly averages for 2024, falling back to the most recent available year if needed
// Updated : 2025-05-11
// ====================================================================

// PARAMETERS
var targetYear   = '2024',
    fallbackYear = '2023',
    startDate    = targetYear   + '-01-01',
    endDate      = targetYear   + '-12-31',
    fbStart      = fallbackYear + '-01-01',
    fbEnd        = fallbackYear + '-12-31';

// 0. ADMINISTRATIVE UNITS
var counties = ee.FeatureCollection('projects/geodata-458113/assets/SWE_adm1');
var simplifiedCounties = counties.map(function(f) {
  return f.simplify({maxError: 100});
});

// ====================================================================
// 1. INDICATORS – YEARLY AVERAGES
// ====================================================================

// NIGHTTIME LIGHTS (VIIRS DNB Monthly)
// Dataset: NOAA/VIIRS/DNB/MONTHLY_V1/VCMCFG
// Definition: Average radiance (avg_rad) from nighttime lights
// Purpose: Proxy for human activity & economic development
// Period: January 1 – December 31 (annual)
// Resolution: ~500 m
// More info: https://developers.google.com/earth-engine/datasets/catalog/NOAA_VIIRS_DNB_MONTHLY_V1_VCMCFG
var viirsCol         = ee.ImageCollection('NOAA/VIIRS/DNB/MONTHLY_V1/VCMCFG')
                          .filterDate(startDate, endDate)
                          .select('avg_rad');
var viirsAvail       = viirsCol.size().gt(0);
var viirsFallbackCol = ee.ImageCollection('NOAA/VIIRS/DNB/MONTHLY_V1/VCMCFG')
                          .filterDate(fbStart, fbEnd)
                          .select('avg_rad');
var viirsImg         = ee.Image(ee.Algorithms.If(
                          viirsAvail,
                          viirsCol.mean(),
                          viirsFallbackCol.mean()
                        )).rename('VIIRS_avg_2024');
var viirsYear        = ee.String(ee.Algorithms.If(viirsAvail, targetYear, fallbackYear));

// URBAN COVER (Dynamic World)
// Dataset: GOOGLE/DYNAMICWORLD/V1
// Definition: Pixel-level classification; class 6 = built area
// Purpose: Proxy for built-up extent
// Period: January 1 – December 31 (annual)
// Resolution: 10 m
// More info: https://developers.google.com/earth-engine/datasets/catalog/GOOGLE_DYNAMICWORLD_V1
var dwCol         = ee.ImageCollection('GOOGLE/DYNAMICWORLD/V1')
                          .filterDate(startDate, endDate)
                          .select('label');
var dwAvail       = dwCol.size().gt(0);
var dwFallbackCol = ee.ImageCollection('GOOGLE/DYNAMICWORLD/V1')
                          .filterDate(fbStart, fbEnd)
                          .select('label');
var urbanBinary   = ee.Image(ee.Algorithms.If(
                          dwAvail,
                          dwCol.mode().eq(6),
                          dwFallbackCol.mode().eq(6)
                        ));
var urbanImg      = urbanBinary.multiply(100).rename('Urban_pct_2024');
var urbanYear     = ee.String(ee.Algorithms.If(dwAvail, targetYear, fallbackYear));

// NDVI (MODIS Terra)
// Dataset: MODIS/006/MOD13A2
// Definition: NDVI at 1 km; scale factor ×0.0001
// Purpose: Vegetation greenness proxy
// Period: January 1 – December 31 (annual)
// Resolution: 1 km
// More info: https://developers.google.com/earth-engine/datasets/catalog/MODIS_006_MOD13A2
var ndviCol         = ee.ImageCollection('MODIS/006/MOD13A2')
                          .filterDate(startDate, endDate)
                          .select('NDVI');
var ndviAvail       = ndviCol.size().gt(0);
var ndviFallbackCol = ee.ImageCollection('MODIS/006/MOD13A2')
                          .filterDate(fbStart, fbEnd)
                          .select('NDVI');
var ndviImg         = ee.Image(ee.Algorithms.If(
                          ndviAvail,
                          ndviCol.mean(),
                          ndviFallbackCol.mean()
                        )).multiply(0.0001)
                          .rename('NDVI_avg_2024');
var ndviYear        = ee.String(ee.Algorithms.If(ndviAvail, targetYear, fallbackYear));

// LAND-SURFACE TEMPERATURE (MODIS)
// Dataset: MODIS/061/MOD11A2
// Definition: 8-day mean daytime LST at 1 km; scale factor ×0.02; convert to °C by subtracting 273.15
// Purpose: Thermal anomaly proxy
// Period: January 1 – December 31 (annual)
// Resolution: 1 km
// More info: https://developers.google.com/earth-engine/datasets/catalog/MODIS_061_MOD11A2
var lstCol         = ee.ImageCollection('MODIS/061/MOD11A2')
                          .filterDate(startDate, endDate)
                          .select('LST_Day_1km');
var lstAvail       = lstCol.size().gt(0);
var lstFallbackCol = ee.ImageCollection('MODIS/061/MOD11A2')
                          .filterDate(fbStart, fbEnd)
                          .select('LST_Day_1km');
var lstImg         = ee.Image(ee.Algorithms.If(
                          lstAvail,
                          lstCol.mean(),
                          lstFallbackCol.mean()
                        )).multiply(0.02)
                          .subtract(273.15)
                          .rename('LST_C_2024');
var lstYear        = ee.String(ee.Algorithms.If(lstAvail, targetYear, fallbackYear));

// PRECIPITATION TOTAL (CHIRPS)
// Dataset: UCSB-CHG/CHIRPS/DAILY
// Definition: Daily precipitation sum (mm)
// Purpose: Wet/dry anomaly proxy
// Period: January 1 – December 31 (annual)
// Resolution: ~5 km
// More info: https://developers.google.com/earth-engine/datasets/catalog/UCSB_CHG_CHIRPS_DAILY
var prcpCol         = ee.ImageCollection('UCSB-CHG/CHIRPS/DAILY')
                            .filterDate(startDate, endDate);
var prcpAvail       = prcpCol.size().gt(0);
var prcpFallbackCol = ee.ImageCollection('UCSB-CHG/CHIRPS/DAILY')
                            .filterDate(fbStart, fbEnd);
var prcpImg         = ee.Image(ee.Algorithms.If(
                            prcpAvail,
                            prcpCol.sum(),
                            prcpFallbackCol.sum()
                          )).rename('Precip_mm_2024');
var prcpYear        = ee.String(ee.Algorithms.If(prcpAvail, targetYear, fallbackYear));

// TROPOSPHERIC NO₂ (Sentinel-5P)
// Dataset: COPERNICUS/S5P/OFFL/L3_NO2
// Definition: Tropospheric NO₂ column density (µmol/m²)
// Purpose: Emissions proxy
// Period: January 1 – December 31 (annual)
// Resolution: ~7 km
// More info: https://developers.google.com/earth-engine/datasets/catalog/COPERNICUS_S5P_OFFL_L3_NO2
var no2Col         = ee.ImageCollection('COPERNICUS/S5P/OFFL/L3_NO2')
                          .filterDate(startDate, endDate)
                          .select('tropospheric_NO2_column_number_density');
var no2Avail       = no2Col.size().gt(0);
var no2FallbackCol = ee.ImageCollection('COPERNICUS/S5P/OFFL/L3_NO2')
                          .filterDate(fbStart, fbEnd)
                          .select('tropospheric_NO2_column_number_density');
var no2Img         = ee.Image(ee.Algorithms.If(
                          no2Avail,
                          no2Col.mean(),
                          no2FallbackCol.mean()
                        )).rename('NO2_mol_m2_2024');
var no2Year        = ee.String(ee.Algorithms.If(no2Avail, targetYear, fallbackYear));

// SOIL-MOISTURE (GLDAS-2.1 NOAH)
// Dataset: NASA/GLDAS/V021/NOAH/G025/T3H
// Definition: Soil moisture top 10 cm (SoilMoi0_10cm_inst)
// Purpose: Surface soil-water proxy
// Period: January 1 – December 31 (annual)
// Resolution: ~25 km
// More info: https://developers.google.com/earth-engine/datasets/catalog/NASA_GLDAS_V021_NOAH_G025_T3H
var smCol         = ee.ImageCollection('NASA/GLDAS/V021/NOAH/G025/T3H')
                          .filterDate(startDate, endDate)
                          .select('SoilMoi0_10cm_inst');
var smAvail       = smCol.size().gt(0);
var smFallbackCol = ee.ImageCollection('NASA/GLDAS/V021/NOAH/G025/T3H')
                          .filterDate(fbStart, fbEnd)
                          .select('SoilMoi0_10cm_inst');
var smImg         = ee.Image(ee.Algorithms.If(
                          smAvail,
                          smCol.mean(),
                          smFallbackCol.mean()
                        )).rename('SoilM_m3m3_2024');
var smYear        = ee.String(ee.Algorithms.If(smAvail, targetYear, fallbackYear));

// ELEVATION & SLOPE (Copernicus GLO-30 Latest)
// Dataset: COPERNICUS/DEM/GLO30
// Definition: Digital elevation model; Slope derived from DEM
// Purpose: Terrain ruggedness proxy
// Epoch: 2024 (latest GLO-30 mosaic)
// Resolution: 30 m
// More info: https://developers.google.com/earth-engine/datasets/catalog/COPERNICUS_DEM_GLO30
var demImg        = ee.ImageCollection('COPERNICUS/DEM/GLO30')
                          .select('DEM')
                          .mosaic()
                          .rename('Elevation_m_2024');
var slopeImg      = ee.Terrain.slope(demImg)
                          .rename('Slope_deg_2024');
var topoYear      = targetYear;

// ====================================================================
// 2. COMBINE & REDUCE
// ====================================================================
var multi = ee.Image.cat([
  viirsImg, urbanImg, ndviImg,
  lstImg, prcpImg, no2Img, smImg,
  demImg, slopeImg
]);

var countiesWithMeta = simplifiedCounties.map(function(f) {
  return f.set({
    'VIIRS_year' : viirsYear,
    'Urban_year' : urbanYear,
    'NDVI_year'  : ndviYear,
    'LST_year'   : lstYear,
    'Precip_year': prcpYear,
    'NO2_year'   : no2Year,
    'SoilM_year' : smYear,
    'Topo_year'  : topoYear
  });
});

var stats = multi.reduceRegions({
  collection: countiesWithMeta,
  reducer: ee.Reducer.mean(),
  scale: 1000,
  crs: 'EPSG:4326'
});

// ====================================================================
// 3. EXPORT & VISUALISE
// ====================================================================
Export.table.toDrive({
  collection : stats,
  description: 'Sweden_Annual_Geoindicators_2024',
  folder     : 'unsae',
  fileFormat : 'CSV'
});

Map.centerObject(simplifiedCounties);
Map.addLayer(viirsImg, {min:0, max:50}, 'VIIRS 2024');
Map.addLayer(urbanImg, {min:0, max:100}, 'Urban % 2024');
Map.addLayer(ndviImg, {min:0, max:0.8}, 'NDVI 2024');
Map.addLayer(lstImg, {min:-10, max:35}, 'LST 2024');
Map.addLayer(prcpImg, {}, 'Precip 2024');
Map.addLayer(no2Img, {}, 'NO2 2024');
Map.addLayer(smImg, {}, 'SoilM 2024');
Map.addLayer(demImg, {}, 'Elevation 2024');
Map.addLayer(slopeImg, {}, 'Slope 2024');
