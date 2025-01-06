"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = promiseLazy;

var _lazyValue = _interopRequireDefault(require("../utils/lazy-value"));

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

function promiseLazy(loadGmapApi, GmapApi) {
  return function (options) {
    // Things to do once the API is loaded
    function onApiLoaded() {
      // TODO: All disabled eslint rules should be analyzed
      // eslint-disable-next-line no-param-reassign -- old style this should be analyzed;
      GmapApi.gmapApi = {};
      return window.google;
    }

    if (options.load) {
      // If library should load the API
      return (0, _lazyValue.default)(function () {
        // Load the
        // This will only be evaluated once
        if (typeof window === 'undefined') {
          // server side -- never resolve this promise
          return new Promise(function () {}).then(onApiLoaded);
        }

        return new Promise(function (resolve, reject) {
          try {
            window.vueGoogleMapsInit = resolve;
            loadGmapApi(options.load, options.loadCn);
          } catch (err) {
            reject(err);
          }
        }).then(onApiLoaded);
      });
    } // If library should not handle API, provide
    // end-users with the global `vueGoogleMapsInit: () => undefined`
    // when the Google Maps API has been loaded


    var promise = new Promise(function (resolve) {
      if (typeof window === 'undefined') {
        // Do nothing if run from server-side
        return;
      }

      window.vueGoogleMapsInit = resolve;
    }).then(onApiLoaded);
    return (0, _lazyValue.default)(function () {
      return promise;
    });
  };
}