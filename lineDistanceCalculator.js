var fs = require('fs');
var turfLineDistance = require('turf-line-distance');

var geojsonString = fs.readFileSync('combined.geojson', {encoding: 'utf8'});
var featureCollection = JSON.parse(geojsonString);
var totalMiles = 0;
for(var i = 0; i< featureCollection.features.length; i++) {
  var feature = featureCollection.features[i];
  totalMiles += turfLineDistance(feature);
}
console.log(totalMiles);
