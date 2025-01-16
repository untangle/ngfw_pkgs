"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = void 0;

// This piece of code was orignally written by sindresorhus and can be seen here
// https://github.com/sindresorhus/lazy-value/blob/master/index.js
var _default = function _default(fn) {
  var called = false;
  var ret;
  return function () {
    if (!called) {
      called = true;
      ret = fn();
    }

    return ret;
  };
};

exports.default = _default;