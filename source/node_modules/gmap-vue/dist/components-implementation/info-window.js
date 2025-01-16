"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = void 0;

var _mapElement = _interopRequireDefault(require("../factories/map-element"));

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

function _objectWithoutProperties(source, excluded) { if (source == null) return {}; var target = _objectWithoutPropertiesLoose(source, excluded); var key, i; if (Object.getOwnPropertySymbols) { var sourceSymbolKeys = Object.getOwnPropertySymbols(source); for (i = 0; i < sourceSymbolKeys.length; i++) { key = sourceSymbolKeys[i]; if (excluded.indexOf(key) >= 0) continue; if (!Object.prototype.propertyIsEnumerable.call(source, key)) continue; target[key] = source[key]; } } return target; }

function _objectWithoutPropertiesLoose(source, excluded) { if (source == null) return {}; var target = {}; var sourceKeys = Object.keys(source); var key, i; for (i = 0; i < sourceKeys.length; i++) { key = sourceKeys[i]; if (excluded.indexOf(key) >= 0) continue; target[key] = source[key]; } return target; }

var props = {
  options: {
    type: Object,
    required: false,
    default: function _default() {
      return {};
    }
  },
  position: {
    type: Object,
    twoWay: true
  },
  zIndex: {
    type: Number,
    twoWay: true
  }
};
var events = ['domready', 'closeclick', 'content_changed'];

var _default = (0, _mapElement.default)({
  mappedProps: props,
  events: events,
  name: 'infoWindow',
  ctr: function ctr() {
    return google.maps.InfoWindow;
  },
  props: {
    opened: {
      type: Boolean,
      default: true
    }
  },
  inject: {
    $markerPromise: {
      default: null
    }
  },
  mounted: function mounted() {
    var el = this.$refs.flyaway;
    el.parentNode.removeChild(el);
  },
  beforeCreate: function beforeCreate(options) {
    var _this = this;

    // TODO: Analyze a better way to do this
    // eslint-disable-next-line no-param-reassign -- needed to add properties to option object
    options.content = this.$refs.flyaway;

    if (this.$markerPromise) {
      var _options = options,
          position = _options.position,
          cleanedOptions = _objectWithoutProperties(_options, ["position"]); // eslint-disable-next-line no-param-reassign -- needed to add properties to option object


      options = cleanedOptions;
      return this.$markerPromise.then(function (mo) {
        _this.$markerObject = mo;
        return mo;
      });
    } // this return is to follow the consistent-return rule of eslint, https://eslint.org/docs/rules/consistent-return


    return undefined;
  },
  methods: {
    // TODO: we need to analyze the following method name
    // eslint-disable-next-line no-underscore-dangle -- old code
    _openInfoWindow: function _openInfoWindow() {
      if (this.opened) {
        if (this.$markerObject !== null) {
          this.$infoWindowObject.open(this.$map, this.$markerObject);
        } else {
          this.$infoWindowObject.open(this.$map);
        }
      } else {
        this.$infoWindowObject.close();
      }
    }
  },
  afterCreate: function afterCreate() {
    var _this2 = this;

    // TODO: This function names should be analyzed

    /* eslint-disable no-underscore-dangle -- old style */
    this._openInfoWindow();

    this.$watch('opened', function () {
      _this2._openInfoWindow();
    });
    /* eslint-enable no-underscore-dangle */
  }
});

exports.default = _default;