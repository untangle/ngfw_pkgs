"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = void 0;

var _mapElement = _interopRequireDefault(require("../factories/map-element"));

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

var mappedProps = {
  circleOptions: {
    type: Object,
    twoWay: false,
    noBind: true
  },
  markerOptions: {
    type: Object,
    twoWay: false,
    noBind: true
  },
  polygonOptions: {
    type: Object,
    twoWay: false,
    noBind: true
  },
  polylineOptions: {
    type: Object,
    twoWay: false,
    noBind: true
  },
  rectangleOptions: {
    type: Object,
    twoWay: false,
    noBind: true
  }
};
var props = {
  position: {
    type: String
  },
  shapes: {
    type: Array,
    required: true
  }
};

var _default = (0, _mapElement.default)({
  name: 'drawingManager',
  ctr: function ctr() {
    return google.maps.drawing.DrawingManager;
  },
  options: {
    drawingControl: true,
    drawingControlOptions: {},
    drawingMode: null
  },
  mappedProps: mappedProps,
  props: props,
  events: [],
  beforeCreate: function beforeCreate(options) {
    var drawingModes = Object.keys(options).reduce(function (modes, opt) {
      var val = opt.split('Options');

      if (val.length > 1) {
        modes.push(val[0]);
      }

      return modes;
    }, []);
    var position = this.position && google.maps.ControlPosition[this.position] ? google.maps.ControlPosition[this.position] : google.maps.ControlPosition.TOP_LEFT; // TODO: should be analyzed after this PR

    /* eslint-disable no-param-reassign -- needed to add options */

    options.drawingMode = null;
    options.drawingControl = !this.$scopedSlots.default;
    options.drawingControlOptions = {
      drawingModes: drawingModes,
      position: position
    };
    /* eslint-enable no-param-reassign */

    return options;
  },
  afterCreate: function afterCreate() {
    var _this = this;

    this.$drawingManagerObject.addListener('overlaycomplete', function (e) {
      return _this.addShape(e);
    });
    this.$map.addListener('click', this.clearSelection);

    if (this.shapes.length > 0) {
      this.drawAll();
    }
  },
  destroyed: function destroyed() {
    this.clearAll();
    this.$drawingManagerObject.setMap(null);
  },
  data: function data() {
    return {
      selectedShape: null
    };
  },
  watch: {
    position: function position(_position) {
      if (this.$drawingManagerObject) {
        var drawingControlOptions = {
          position: _position && google.maps.ControlPosition[_position] ? google.maps.ControlPosition[_position] : google.maps.ControlPosition.TOP_LEFT
        };
        this.$drawingManagerObject.setOptions({
          drawingControlOptions: drawingControlOptions
        });
      }
    },
    circleOptions: function circleOptions(_circleOptions) {
      if (this.$drawingManagerObject) {
        this.$drawingManagerObject.setOptions({
          circleOptions: _circleOptions
        });
      }
    },
    markerOptions: function markerOptions(_markerOptions) {
      if (this.$drawingManagerObject) {
        this.$drawingManagerObject.setOptions({
          markerOptions: _markerOptions
        });
      }
    },
    polygonOptions: function polygonOptions(_polygonOptions) {
      if (this.$drawingManagerObject) {
        this.$drawingManagerObject.setOptions({
          polygonOptions: _polygonOptions
        });
      }
    },
    polylineOptions: function polylineOptions(_polylineOptions) {
      if (this.$drawingManagerObject) {
        this.$drawingManagerObject.setOptions({
          polylineOptions: _polylineOptions
        });
      }
    },
    rectangleOptions: function rectangleOptions(_rectangleOptions) {
      if (this.$drawingManagerObject) {
        this.$drawingManagerObject.setOptions({
          rectangleOptions: _rectangleOptions
        });
      }
    }
  },
  methods: {
    setDrawingMode: function setDrawingMode(mode) {
      this.$drawingManagerObject.setDrawingMode(mode);
    },
    drawAll: function drawAll() {
      var _this2 = this;

      var shapeType = {
        circle: google.maps.Circle,
        marker: google.maps.Marker,
        polygon: google.maps.Polygon,
        polyline: google.maps.Polyline,
        rectangle: google.maps.Rectangle
      };
      var self = this;
      this.shapes.forEach(function (shape) {
        var shapeDrawing = new shapeType[shape.type](shape.overlay);
        shapeDrawing.setMap(_this2.$map); // TODO: analyze if exists a better way to do the below assignment
        // eslint-disable-next-line no-param-reassign -- we need to assign properties to this shape

        shape.overlay = shapeDrawing;
        google.maps.event.addListener(shapeDrawing, 'click', function () {
          self.setSelection(shape);
        });
      });
    },
    clearAll: function clearAll() {
      this.clearSelection();
      this.shapes.forEach(function (shape) {
        shape.overlay.setMap(null);
      });
    },
    clearSelection: function clearSelection() {
      if (this.selectedShape) {
        this.selectedShape.overlay.set('fillColor', '#777');
        this.selectedShape.overlay.set('strokeColor', '#999');
        this.selectedShape.overlay.setEditable(false);
        this.selectedShape.overlay.setDraggable(false);
        this.selectedShape = null;
      }
    },
    setSelection: function setSelection(shape) {
      this.clearSelection();
      this.selectedShape = shape;
      shape.overlay.setEditable(true);
      shape.overlay.setDraggable(true);
      this.selectedShape.overlay.set('fillColor', '#555');
      this.selectedShape.overlay.set('strokeColor', '#777');
    },
    deleteSelection: function deleteSelection() {
      if (this.selectedShape) {
        this.selectedShape.overlay.setMap(null);
        var index = this.shapes.indexOf(this.selectedShape);

        if (index > -1) {
          this.shapes.splice(index, 1);
        }
      }
    },
    addShape: function addShape(shape) {
      this.setDrawingMode(null);
      this.shapes.push(shape);
      var self = this;
      google.maps.event.addListener(shape.overlay, 'click', function () {
        self.setSelection(shape);
      });
      this.setSelection(shape);
    }
  }
});

exports.default = _default;