"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.getPropsValues = getPropsValues;
exports.bindProps = bindProps;

var _watchPrimitiveProperties = _interopRequireDefault(require("./watch-primitive-properties"));

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

function capitalizeFirstLetter(string) {
  return string.charAt(0).toUpperCase() + string.slice(1);
}

function getPropsValues(vueInst, props) {
  return Object.keys(props).reduce(function (acc, prop) {
    if (vueInst[prop] !== undefined) {
      acc[prop] = vueInst[prop];
    }

    return acc;
  }, {});
}
/**
 * Binds the properties defined in props to the google maps instance.
 * If the prop is an Object type, and we wish to track the properties
 * of the object (e.g. the lat and lng of a LatLng), then we do a deep
 * watch. For deep watch, we also prevent the _changed event from being
 * emitted if the data source was external.
 */


function bindProps(vueInst, googleMapsInst, props) {
  Object.keys(props).forEach(function (attribute) {
    var _props$attribute = props[attribute],
        twoWay = _props$attribute.twoWay,
        type = _props$attribute.type,
        trackProperties = _props$attribute.trackProperties,
        noBind = _props$attribute.noBind;

    if (!noBind) {
      var setMethodName = "set".concat(capitalizeFirstLetter(attribute));
      var getMethodName = "get".concat(capitalizeFirstLetter(attribute));
      var eventName = "".concat(attribute.toLowerCase(), "_changed");
      var initialValue = vueInst[attribute];

      if (typeof googleMapsInst[setMethodName] === 'undefined') {
        throw new Error( // TODO: Analyze all disabled rules in the file
        // eslint-disable-next-line no-underscore-dangle -- old code should be analyzed
        "".concat(setMethodName, " is not a method of (the Maps object corresponding to) ").concat(vueInst.$options._componentTag));
      } // We need to avoid an endless
      // propChanged -> event emitted -> propChanged -> event emitted loop
      // although this may really be the user's responsibility


      if (type !== Object || !trackProperties) {
        // Track the object deeply
        vueInst.$watch(attribute, function () {
          var attributeValue = vueInst[attribute];
          googleMapsInst[setMethodName](attributeValue);
        }, {
          immediate: typeof initialValue !== 'undefined',
          deep: type === Object
        });
      } else {
        (0, _watchPrimitiveProperties.default)(vueInst, trackProperties.map(function (prop) {
          return "".concat(attribute, ".").concat(prop);
        }), function () {
          googleMapsInst[setMethodName](vueInst[attribute]);
        }, vueInst[attribute] !== undefined);
      }

      if (twoWay && (vueInst.$gmapOptions.autobindAllEvents || vueInst.$listeners[eventName])) {
        googleMapsInst.addListener(eventName, function () {
          vueInst.$emit(eventName, googleMapsInst[getMethodName]());
        });
      }
    }
  });
}