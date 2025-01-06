"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = watchPrimitiveProperties;

/**
 * Watch the individual properties of a PoD object, instead of the object
 * per se. This is different from a deep watch where both the reference
 * and the individual values are watched.
 *
 * In effect, it throttles the multiple $watch to execute at most once per tick.
 */
function watchPrimitiveProperties(vueInst, propertiesToTrack, handler) {
  var immediate = arguments.length > 3 && arguments[3] !== undefined ? arguments[3] : false;
  var isHandled = false;

  function requestHandle() {
    if (!isHandled) {
      isHandled = true;
      vueInst.$nextTick(function () {
        isHandled = false;
        handler();
      });
    }
  }

  propertiesToTrack.forEach(function (prop) {
    vueInst.$watch(prop, requestHandle, {
      immediate: immediate
    });
  });
}