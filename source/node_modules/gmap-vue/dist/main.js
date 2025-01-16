"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.install = install;
exports.gmapApi = gmapApi;
Object.defineProperty(exports, "loadGmapApi", {
  enumerable: true,
  get: function get() {
    return _initializer.default;
  }
});
Object.defineProperty(exports, "KmlLayer", {
  enumerable: true,
  get: function get() {
    return _kmlLayer.default;
  }
});
Object.defineProperty(exports, "HeatmapLayer", {
  enumerable: true,
  get: function get() {
    return _heatmapLayer.default;
  }
});
Object.defineProperty(exports, "Marker", {
  enumerable: true,
  get: function get() {
    return _marker.default;
  }
});
Object.defineProperty(exports, "Polyline", {
  enumerable: true,
  get: function get() {
    return _polyline.default;
  }
});
Object.defineProperty(exports, "Polygon", {
  enumerable: true,
  get: function get() {
    return _polygon.default;
  }
});
Object.defineProperty(exports, "Circle", {
  enumerable: true,
  get: function get() {
    return _circle.default;
  }
});
Object.defineProperty(exports, "Rectangle", {
  enumerable: true,
  get: function get() {
    return _rectangle.default;
  }
});
Object.defineProperty(exports, "DrawingManager", {
  enumerable: true,
  get: function get() {
    return _drawingManager.default;
  }
});
Object.defineProperty(exports, "InfoWindow", {
  enumerable: true,
  get: function get() {
    return _infoWindow.default;
  }
});
Object.defineProperty(exports, "Map", {
  enumerable: true,
  get: function get() {
    return _map.default;
  }
});
Object.defineProperty(exports, "StreetViewPanorama", {
  enumerable: true,
  get: function get() {
    return _streetViewPanorama.default;
  }
});
Object.defineProperty(exports, "PlaceInput", {
  enumerable: true,
  get: function get() {
    return _placeInput.default;
  }
});
Object.defineProperty(exports, "Autocomplete", {
  enumerable: true,
  get: function get() {
    return _autocomplete.default;
  }
});
Object.defineProperty(exports, "MapElementMixin", {
  enumerable: true,
  get: function get() {
    return _mapElement.default;
  }
});
Object.defineProperty(exports, "MapElementFactory", {
  enumerable: true,
  get: function get() {
    return _mapElement2.default;
  }
});
Object.defineProperty(exports, "MountableMixin", {
  enumerable: true,
  get: function get() {
    return _mountable.default;
  }
});
exports.Cluster = void 0;

var _initializer = _interopRequireDefault(require("./manager/initializer"));

var _promiseLazy = _interopRequireDefault(require("./factories/promise-lazy"));

var _kmlLayer = _interopRequireDefault(require("./components/kml-layer"));

var _heatmapLayer = _interopRequireDefault(require("./components/heatmap-layer"));

var _marker = _interopRequireDefault(require("./components/marker"));

var _polyline = _interopRequireDefault(require("./components/polyline"));

var _polygon = _interopRequireDefault(require("./components/polygon"));

var _circle = _interopRequireDefault(require("./components/circle"));

var _rectangle = _interopRequireDefault(require("./components/rectangle"));

var _drawingManager = _interopRequireDefault(require("./components/drawing-manager.vue"));

var _infoWindow = _interopRequireDefault(require("./components/info-window.vue"));

var _map = _interopRequireDefault(require("./components/map.vue"));

var _streetViewPanorama = _interopRequireDefault(require("./components/street-view-panorama.vue"));

var _placeInput = _interopRequireDefault(require("./components/place-input.vue"));

var _autocomplete = _interopRequireDefault(require("./components/autocomplete.vue"));

var _mapElement = _interopRequireDefault(require("./mixins/map-element"));

var _mapElement2 = _interopRequireDefault(require("./factories/map-element"));

var _mountable = _interopRequireDefault(require("./mixins/mountable"));

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

function ownKeys(object, enumerableOnly) { var keys = Object.keys(object); if (Object.getOwnPropertySymbols) { var symbols = Object.getOwnPropertySymbols(object); if (enumerableOnly) symbols = symbols.filter(function (sym) { return Object.getOwnPropertyDescriptor(object, sym).enumerable; }); keys.push.apply(keys, symbols); } return keys; }

function _objectSpread(target) { for (var i = 1; i < arguments.length; i++) { var source = arguments[i] != null ? arguments[i] : {}; if (i % 2) { ownKeys(Object(source), true).forEach(function (key) { _defineProperty(target, key, source[key]); }); } else if (Object.getOwnPropertyDescriptors) { Object.defineProperties(target, Object.getOwnPropertyDescriptors(source)); } else { ownKeys(Object(source)).forEach(function (key) { Object.defineProperty(target, key, Object.getOwnPropertyDescriptor(source, key)); }); } } return target; }

function _defineProperty(obj, key, value) { if (key in obj) { Object.defineProperty(obj, key, { value: value, enumerable: true, configurable: true, writable: true }); } else { obj[key] = value; } return obj; }

// HACK: Cluster should be loaded conditionally
// However in the web version, it's not possible to write
// `import 'vue2-google-maps/src/components/cluster'`, so we need to
// import it anyway (but we don't have to register it)
// Therefore we use babel-plugin-transform-inline-environment-variables to
// set BUILD_DEV to truthy / falsy
var Cluster = undefined; // TODO: This should be checked if it must be GmapVue, Gmap.api or something else

exports.Cluster = Cluster;
var GmapApi = null; // export everything

function install(Vue, options) {
  // Set defaults
  // TODO: All disabled eslint rules should be analyzed
  // eslint-disable-next-line no-param-reassign -- this should be analyzed;
  options = _objectSpread({
    installComponents: true,
    autobindAllEvents: false
  }, options); // Update the global `GmapApi`. This will allow
  // components to use the `google` global reactively
  // via:
  //   import { gmapApi } from 'gmap-vue'
  //   export default {  computed: { google: gmapApi }  }

  GmapApi = new Vue({
    data: {
      gmapApi: null
    }
  });
  var defaultResizeBus = new Vue(); // Use a lazy to only load the API when
  // a VGM component is loaded

  var promiseLazyCreator = (0, _promiseLazy.default)(_initializer.default, GmapApi);
  var gmapApiPromiseLazy = promiseLazyCreator(options);
  Vue.mixin({
    created: function created() {
      this.$gmapDefaultResizeBus = defaultResizeBus;
      this.$gmapOptions = options;
      this.$gmapApiPromiseLazy = gmapApiPromiseLazy;
    }
  }); // eslint-disable-next-line no-param-reassign -- old style this should be analyzed;

  Vue.$gmapDefaultResizeBus = defaultResizeBus; // eslint-disable-next-line no-param-reassign -- old style this should be analyzed;

  Vue.$gmapApiPromiseLazy = gmapApiPromiseLazy;

  if (options.installComponents) {
    Vue.component('GmapMap', _map.default);
    Vue.component('GmapMarker', _marker.default);
    Vue.component('GmapInfoWindow', _infoWindow.default);
    Vue.component('GmapHeatmapLayer', _heatmapLayer.default);
    Vue.component('GmapKmlLayer', _kmlLayer.default);
    Vue.component('GmapPolyline', _polyline.default);
    Vue.component('GmapPolygon', _polygon.default);
    Vue.component('GmapCircle', _circle.default);
    Vue.component('GmapRectangle', _rectangle.default);
    Vue.component('GmapDrawingManager', _drawingManager.default);
    Vue.component('GmapAutocomplete', _autocomplete.default);
    Vue.component('GmapPlaceInput', _placeInput.default);
    Vue.component('GmapStreetViewPanorama', _streetViewPanorama.default);
  }
}

function gmapApi() {
  return GmapApi.gmapApi && window.google;
}