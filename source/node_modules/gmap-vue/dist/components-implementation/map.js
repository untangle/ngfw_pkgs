"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = void 0;

var _bindEvents = _interopRequireDefault(require("../utils/bind-events"));

var _bindProps = require("../utils/bind-props");

var _mountable = _interopRequireDefault(require("../mixins/mountable"));

var _twoWayBindingWrapper = _interopRequireDefault(require("../utils/two-way-binding-wrapper"));

var _watchPrimitiveProperties = _interopRequireDefault(require("../utils/watch-primitive-properties"));

var _mappedPropsToVueProps = _interopRequireDefault(require("../utils/mapped-props-to-vue-props"));

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

function _objectWithoutProperties(source, excluded) { if (source == null) return {}; var target = _objectWithoutPropertiesLoose(source, excluded); var key, i; if (Object.getOwnPropertySymbols) { var sourceSymbolKeys = Object.getOwnPropertySymbols(source); for (i = 0; i < sourceSymbolKeys.length; i++) { key = sourceSymbolKeys[i]; if (excluded.indexOf(key) >= 0) continue; if (!Object.prototype.propertyIsEnumerable.call(source, key)) continue; target[key] = source[key]; } } return target; }

function _objectWithoutPropertiesLoose(source, excluded) { if (source == null) return {}; var target = {}; var sourceKeys = Object.keys(source); var key, i; for (i = 0; i < sourceKeys.length; i++) { key = sourceKeys[i]; if (excluded.indexOf(key) >= 0) continue; target[key] = source[key]; } return target; }

function ownKeys(object, enumerableOnly) { var keys = Object.keys(object); if (Object.getOwnPropertySymbols) { var symbols = Object.getOwnPropertySymbols(object); if (enumerableOnly) symbols = symbols.filter(function (sym) { return Object.getOwnPropertyDescriptor(object, sym).enumerable; }); keys.push.apply(keys, symbols); } return keys; }

function _objectSpread(target) { for (var i = 1; i < arguments.length; i++) { var source = arguments[i] != null ? arguments[i] : {}; if (i % 2) { ownKeys(Object(source), true).forEach(function (key) { _defineProperty(target, key, source[key]); }); } else if (Object.getOwnPropertyDescriptors) { Object.defineProperties(target, Object.getOwnPropertyDescriptors(source)); } else { ownKeys(Object(source)).forEach(function (key) { Object.defineProperty(target, key, Object.getOwnPropertyDescriptor(source, key)); }); } } return target; }

function _defineProperty(obj, key, value) { if (key in obj) { Object.defineProperty(obj, key, { value: value, enumerable: true, configurable: true, writable: true }); } else { obj[key] = value; } return obj; }

var props = {
  center: {
    required: true,
    twoWay: true,
    type: Object,
    noBind: true
  },
  zoom: {
    required: false,
    twoWay: true,
    type: Number,
    noBind: true
  },
  heading: {
    type: Number,
    twoWay: true
  },
  mapTypeId: {
    twoWay: true,
    type: String
  },
  tilt: {
    twoWay: true,
    type: Number
  },
  options: {
    type: Object,
    default: function _default() {
      return {};
    }
  }
};
var events = ['bounds_changed', 'click', 'dblclick', 'drag', 'dragend', 'dragstart', 'idle', 'mousemove', 'mouseout', 'mouseover', 'resize', 'rightclick', 'tilesloaded']; // Plain Google Maps methods exposed here for convenience

var linkedMethods = ['panBy', 'panTo', 'panToBounds', 'fitBounds'].reduce(function (all, methodName) {
  // TODO: analyze if the following anonymous function can be an arrow function or a defined name
  // eslint-disable-next-line no-param-reassign, func-names -- false positive
  all[methodName] = function () {
    if (this.$mapObject) {
      var _this$$mapObject;

      // TODO: analyze behavior we replace apply with spread operator
      (_this$$mapObject = this.$mapObject)[methodName].apply(_this$$mapObject, arguments);
    }
  };

  return all;
}, {}); // Other convenience methods exposed by Vue Google Maps

var customMethods = {
  resize: function resize() {
    if (this.$mapObject) {
      google.maps.event.trigger(this.$mapObject, 'resize');
    }
  },
  resizePreserveCenter: function resizePreserveCenter() {
    if (!this.$mapObject) {
      return;
    }

    var oldCenter = this.$mapObject.getCenter();
    google.maps.event.trigger(this.$mapObject, 'resize');
    this.$mapObject.setCenter(oldCenter);
  },
  /// Override mountableMixin::_resizeCallback
  /// because resizePreserveCenter is usually the
  /// expected behaviour
  // TODO: analyze the following disabled rule
  // eslint-disable-next-line no-underscore-dangle -- old code
  _resizeCallback: function _resizeCallback() {
    this.resizePreserveCenter();
  }
};
var recyclePrefix = '__gmc__';
var _default = {
  mixins: [_mountable.default],
  props: (0, _mappedPropsToVueProps.default)(props),
  provide: function provide() {
    var _this = this;

    this.$mapPromise = new Promise(function (resolve, reject) {
      _this.$mapPromiseDeferred = {
        resolve: resolve,
        reject: reject
      };
    });
    return {
      $mapPromise: this.$mapPromise
    };
  },
  computed: {
    finalLat: function finalLat() {
      return this.center && typeof this.center.lat === 'function' ? this.center.lat() : this.center.lat;
    },
    finalLng: function finalLng() {
      return this.center && typeof this.center.lng === 'function' ? this.center.lng() : this.center.lng;
    },
    finalLatLng: function finalLatLng() {
      return {
        lat: this.finalLat,
        lng: this.finalLng
      };
    }
  },
  watch: {
    zoom: function zoom(_zoom) {
      if (this.$mapObject) {
        this.$mapObject.setZoom(_zoom);
      }
    }
  },
  beforeDestroy: function beforeDestroy() {
    var recycleKey = this.getRecycleKey();

    if (window[recycleKey]) {
      window[recycleKey].div = this.$mapObject.getDiv();
    }
  },
  mounted: function mounted() {
    var _this2 = this;

    return this.$gmapApiPromiseLazy().then(function () {
      // getting the DOM element where to create the map
      var element = _this2.$refs['vue-map']; // creating the map

      var initialOptions = _objectSpread({}, _this2.options, {}, (0, _bindProps.getPropsValues)(_this2, props)); // don't use delete keyword in order to create a more predictable code for the engine


      var extraOptions = initialOptions.options,
          finalOptions = _objectWithoutProperties(initialOptions, ["options"]);

      var options = finalOptions;

      var recycleKey = _this2.getRecycleKey();

      if (_this2.options.recycle && window[recycleKey]) {
        element.appendChild(window[recycleKey].div);
        _this2.$mapObject = window[recycleKey].map;

        _this2.$mapObject.setOptions(options);
      } else {
        // console.warn('[vue2-google-maps] New google map created')
        _this2.$mapObject = new google.maps.Map(element, options);
        window[recycleKey] = {
          map: _this2.$mapObject
        };
      } // binding properties (two and one way)


      (0, _bindProps.bindProps)(_this2, _this2.$mapObject, props); // binding events

      (0, _bindEvents.default)(_this2, _this2.$mapObject, events); // manually trigger center and zoom

      (0, _twoWayBindingWrapper.default)(function (increment, decrement, shouldUpdate) {
        _this2.$mapObject.addListener('center_changed', function () {
          if (shouldUpdate()) {
            _this2.$emit('center_changed', _this2.$mapObject.getCenter());
          }

          decrement();
        });

        (0, _watchPrimitiveProperties.default)(_this2, ['finalLat', 'finalLng'], function updateCenter() {
          increment();

          _this2.$mapObject.setCenter(_this2.finalLatLng);
        });
      });

      _this2.$mapObject.addListener('zoom_changed', function () {
        _this2.$emit('zoom_changed', _this2.$mapObject.getZoom());
      });

      _this2.$mapObject.addListener('bounds_changed', function () {
        _this2.$emit('bounds_changed', _this2.$mapObject.getBounds());
      });

      _this2.$mapPromiseDeferred.resolve(_this2.$mapObject);

      return _this2.$mapObject;
    }).catch(function (error) {
      throw error;
    });
  },
  methods: _objectSpread({}, customMethods, {}, linkedMethods, {
    getRecycleKey: function getRecycleKey() {
      return this.options.recycle ? recyclePrefix + this.options.recycle : recyclePrefix;
    }
  })
};
exports.default = _default;