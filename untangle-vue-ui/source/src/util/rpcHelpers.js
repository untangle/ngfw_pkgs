import Util from './setupUtil'

const ERROR_MODES = new Set(['ignore', 'handle', 'propagate'])
const SESSION_TRANSPORT_CODES = new Set([550, 12029, 12019, 0, 595])

/**
 * Classifies session and transport failures independently from the selected
 * error mode. The mode decides whether an error is ignored, handled, or
 * propagated; this classifier preserves the information needed for session
 * expiry, timeout, connection-loss, and service-unavailable handling.
 *
 * @param {object} error - RPC error
 * @returns {boolean} true when the error is session or transport related
 */
export function isSessionOrTransportError(error) {
  if (!error) return false
  if (SESSION_TRANSPORT_CODES.has(error.code)) return true
  if (typeof error.message === 'string' && error.message.includes('Invalid security nonce')) return true
  if (typeof error.response === 'string' && error.response.includes('loginPage')) return true
  if (error.name === 'JSONRpcClientException' && error.fileName?.includes('jsonrpc')) return true

  const message = typeof error.message === 'string' ? error.message : ''
  return (
    message.includes('Service Unavailable') ||
    message.includes('Service Temporarily Unavailable') ||
    message.includes('This application is not currently available')
  )
}

/**
 * Normalizes the requested error mode.
 *
 * Error handling is intentionally explicit at the helper boundary:
 *
 * - `ignore`: suppress the error and return the configured fallback. Use for
 *   optional/non-user-facing data where no notification is useful.
 * - `handle`: call Util.handleException(), then return the fallback. This is
 *   the default for normal UI RPC calls.
 * - `propagate`: reject/throw the original application error without calling
 *   Util. Transport/session errors are handled centrally and resolve/return
 *   the fallback instead. Use this when the component needs custom backend
 *   recovery and make sure the caller catches application errors.
 *
 * Invalid or missing modes use `handle` so existing callers remain safe.
 *
 * @param {string} mode - requested error handling mode
 * @returns {'ignore'|'handle'|'propagate'} normalized mode
 */
function normalizeMode(mode) {
  return ERROR_MODES.has(mode) ? mode : 'handle'
}

/**
 * Applies the shared error policy and reports whether the original error should
 * be propagated. Promise settlement and direct-call return/throw behavior stay
 * in their respective public helpers.
 *
 * Transport/session failures are always sent to Util.handleException() and are
 * never propagated. For application/backend failures, only `handle` sends a
 * notification and only `propagate` returns true.
 */
function handleRpcError(error, mode) {
  const normalizedMode = normalizeMode(mode)
  const isTransportError = isSessionOrTransportError(error)

  if (isTransportError) {
    Util.handleException(error)
    return false
  }

  if (normalizedMode === 'handle') {
    Util.handleException(error)
  }

  return normalizedMode === 'propagate'
}

/**
 * Calls a callback-based JSON-RPC method.
 *
 * The callback error is treated as a failure even when the HTTP request itself
 * succeeded (for example, a Java exception returned in an HTTP 200 response).
 * See normalizeMode() for the three supported error modes. The fallback is
 * used only on failure; successful null/false/0/empty values are preserved.
 *
 * @param {Function} rpcMethod - RPC method; callback is prepended to arguments
 * @param {Array} args - RPC method arguments
 * @param {object} options - error behavior options
 * @param {'ignore'|'handle'|'propagate'} options.mode - error handling mode
 * @param {*} options.fallback - value returned when the call fails
 * @returns {Promise<*>} RPC result or fallback value
 *
 * @example
 * // Optional data: fail silently and keep an empty list.
 * rpcCall(method, [], { mode: 'ignore', fallback: [] })
 *
 * @example
 * // Normal UI request: show the centralized error UI and use a fallback.
 * rpcCall(method, [], { mode: 'handle', fallback: null })
 *
 * @example
 * // Component-specific recovery: catch the original backend error locally.
 * try {
 *   await rpcCall(method, [], { mode: 'propagate' })
 * } catch (error) {
 *   // Recover in the component; application errors are not globally notified.
 *   // Transport/session errors are handled centrally and do not reach this catch.
 * }
 */
export function rpcCall(rpcMethod, args = [], { mode = 'handle', fallback } = {}) {
  return new Promise((resolve, reject) => {
    if (typeof rpcMethod !== 'function') {
      const error = new Error('RPC method is not available')
      if (handleRpcError(error, mode)) reject(error)
      else resolve(fallback)
      return
    }

    try {
      rpcMethod((result, error) => {
        if (error !== undefined && error !== null) {
          if (handleRpcError(error, mode)) reject(error)
          else resolve(fallback)
          return
        }
        resolve(result)
      }, ...args)
    } catch (error) {
      if (handleRpcError(error, mode)) reject(error)
      else resolve(fallback)
    }
  })
}

/**
 * Calls a synchronous/direct RPC method with the same three error modes as
 * rpcCall(). `ignore` and `handle` return the fallback after failure;
 * `propagate` throws the original application error for the caller to catch.
 * A transport/session error is handled centrally and returns the fallback.
 *
 * @param {Function} rpcMethod - synchronous RPC method
 * @param {Array} args - RPC method arguments
 * @param {object} options - error behavior options
 * @param {'ignore'|'handle'|'propagate'} options.mode - error handling mode
 * @param {*} options.fallback - value returned when the call fails
 * @returns {*} RPC result or fallback value
 */
export function directRpcCall(rpcMethod, args = [], { mode = 'handle', fallback } = {}) {
  try {
    if (typeof rpcMethod !== 'function') {
      throw new TypeError('RPC method is not available')
    }
    return rpcMethod(...args)
  } catch (error) {
    if (handleRpcError(error, mode)) throw error
    return fallback
  }
}
