"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = void 0;

var _mapElement = _interopRequireDefault(require("../factories/map-element"));

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

var props = {
  options: {
    type: Object,
    twoWay: false,
    default: function _default() {}
  },
  data: {
    type: Array,
    twoWay: true
  }
};
var events = [];
/**
 * @class Heatmap Layer
 *
 * Heatmap Layer class
 */

var _default = (0, _mapElement.default)({
  mappedProps: props,
  events: events,
  name: 'heatmapLayer',
  ctr: function ctr() {
    return google.maps.visualization.HeatmapLayer;
  }
});

exports.default = _default;