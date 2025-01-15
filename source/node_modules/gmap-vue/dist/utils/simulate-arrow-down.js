"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = simulateArrowDown;

// This piece of code was orignally written by amirnissim and can be seen here
// http://stackoverflow.com/a/11703018/2694653
// This has been ported to Vanilla.js by GuillaumeLeclerc
function simulateArrowDown(input) {
  // TODO: Analyze disabled eslint rules in the file
  // eslint-disable-next-line no-underscore-dangle -- Is old style should be analyzed
  var _addEventListener = input.addEventListener ? input.addEventListener : input.attachEvent;

  function addEventListenerWrapper(type, listener) {
    // Simulate a 'down arrow' keypress on hitting 'return' when no pac suggestion is selected,
    // and then trigger the original listener.
    if (type === 'keydown') {
      var origListener = listener; // eslint-disable-next-line no-param-reassign -- Is old style this should be analyzed

      listener = function (event) {
        var suggestionSelected = document.getElementsByClassName('pac-item-selected').length > 0;

        if (event.which === 13 && !suggestionSelected) {
          var simulatedEvent = document.createEvent('Event');
          simulatedEvent.keyCode = 40;
          simulatedEvent.which = 40;
          origListener.apply(input, [simulatedEvent]);
        }

        origListener.apply(input, [event]);
      };
    }

    _addEventListener.apply(input, [type, listener]);
  } // eslint-disable-next-line no-param-reassign -- Is old style this should be analyzed[]


  input.addEventListener = addEventListenerWrapper; // eslint-disable-next-line no-param-reassign -- Is old style this should be analyzed[]

  input.attachEvent = addEventListenerWrapper;
}