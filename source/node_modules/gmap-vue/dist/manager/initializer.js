"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = void 0;

function _typeof(obj) { "@babel/helpers - typeof"; if (typeof Symbol === "function" && typeof Symbol.iterator === "symbol") { _typeof = function (obj) { return typeof obj; }; } else { _typeof = function (obj) { return obj && typeof Symbol === "function" && obj.constructor === Symbol && obj !== Symbol.prototype ? "symbol" : typeof obj; }; } return _typeof(obj); }

/**
 * @param apiKey    API Key, or object with the URL parameters. For example
 *                  to use Google Maps Premium API, pass
 *                    `{ client: <YOUR-CLIENT-ID> }`.
 *                  You may pass the libraries and/or version (as `v`) parameter into
 *                  this parameter and skip the next two parameters
 * @param version   Google Maps version
 * @param libraries Libraries to load (@see
 *                  https://developers.google.com/maps/documentation/javascript/libraries)
 * @param loadCn    Boolean. If set to true, the map will be loaded from google maps China
 *                  (@see https://developers.google.com/maps/documentation/javascript/basics#GoogleMapsChina)
 *
 * Example:
 * ```
 *      import {load} from 'vue-google-maps'
 *
 *      load(<YOUR-API-KEY>)
 *
 *      load({
 *              key: <YOUR-API-KEY>,
 *      })
 *
 *      load({
 *              client: <YOUR-CLIENT-ID>,
 *              channel: <YOUR CHANNEL>
 *      })
 * ```
 */
var _default = function () {
  var isApiSetUp = false;
  return function (options, loadCn) {
    if (typeof document === 'undefined') {
      // Do nothing if run from server-side
      return;
    }

    if (!isApiSetUp) {
      isApiSetUp = true;
      var googleMapScript = document.createElement('SCRIPT'); // Allow options to be an object.
      // This is to support more esoteric means of loading Google Maps,
      // such as Google for business
      // https://developers.google.com/maps/documentation/javascript/get-api-key#premium-auth

      if (_typeof(options) !== 'object') {
        throw new Error('options should  be an object');
      } // libraries


      if (Object.prototype.isPrototypeOf.call(Array.prototype, options.libraries)) {
        // TODO: all eslint disabled rules in this file should be analyzed
        // eslint-disable-next-line no-param-reassign -- old style should be analyzed
        options.libraries = options.libraries.join(',');
      } // eslint-disable-next-line no-param-reassign -- old style should be analyzed


      options.callback = 'vueGoogleMapsInit';
      var baseUrl = 'https://maps.googleapis.com/';

      if (typeof loadCn === 'boolean' && loadCn === true) {
        baseUrl = 'https://maps.google.cn/';
      }

      var query = Object.keys(options).map(function (key) {
        return "".concat(encodeURIComponent(key), "=").concat(encodeURIComponent(options[key]));
      }).join('&');
      var url = "".concat(baseUrl, "maps/api/js?").concat(query);
      googleMapScript.setAttribute('src', url);
      googleMapScript.setAttribute('async', '');
      googleMapScript.setAttribute('defer', '');
      document.head.appendChild(googleMapScript);
    } else {
      throw new Error('You already started the loading of google maps');
    }
  };
}();

exports.default = _default;