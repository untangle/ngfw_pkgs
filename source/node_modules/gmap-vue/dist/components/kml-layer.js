"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = void 0;

var _mapElement = _interopRequireDefault(require("../factories/map-element"));

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

var props = {
  url: {
    twoWay: false,
    type: String
  },
  map: {
    twoWay: true,
    type: Object
  }
};
var events = ['click', 'rightclick', 'dblclick', 'mouseup', 'mousedown', 'mouseover', 'mouseout'];
/**
 * @class KML Layer
 *
 * KML Layer class (experimental)
 */

var _default = (0, _mapElement.default)({
  mappedProps: props,
  events: events,
  name: 'kmlLayer',
  ctr: function ctr() {
    return google.maps.KmlLayer;
  }
});

exports.default = _default;