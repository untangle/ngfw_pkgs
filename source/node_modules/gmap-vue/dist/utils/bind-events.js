"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = bindEvents;

function bindEvents(vueInst, googleMapsInst, events) {
  events.forEach(function (eventName) {
    if (vueInst.$gmapOptions.autobindAllEvents || vueInst.$listeners[eventName]) {
      googleMapsInst.addListener(eventName, function (ev) {
        vueInst.$emit(eventName, ev);
      });
    }
  });
}