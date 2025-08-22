/**
 * Posts a message to the parent window.
 * This is used to communicate events from the iframe to the main application.
 *
 * @param {string} action - The action to be sent to the parent window.
 */
export const sendEvent = action => {
  if (window.parent) {
    window.parent.postMessage({ action }, window.location.origin)
  }
}
