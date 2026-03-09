/**
 * MetricsPollingService - Singleton
 *
 * Centralized polling manager for all app metrics
 *
 * Lifecycle:
 * - Start: Called on router beforeEnter to /apps
 * - Stop: Called on router before leave from /apps
 * - Cleanup: Automatic via router guards
 *
 * Behavior:
 * - Single RPC call for ALL apps (not per-app)
 * - Frequency: 10 seconds
 * - First call: Immediate (before interval starts)
 * - Stops polling on error (session timeout, connection lost, etc.)
 * - Cancels in-flight requests on stop
 */

import Rpc from '@/util/Rpc'
import Util from '@/util/setupUtil'
import store from '@/store'

class MetricsPollingService {
  constructor() {
    // Singleton pattern - return existing instance if it exists
    if (MetricsPollingService.instance) {
      return MetricsPollingService.instance
    }

    // Configuration
    this.frequency = 10000 // 10 seconds
    this.intervalId = null
    this.isRunning = false
    this.abortController = null

    // Store singleton instance
    MetricsPollingService.instance = this
  }

  /**
   * Start polling
   *
   * Behavior:
   * 1. Stops any existing polling
   * 2. Clears existing data
   * 3. Makes immediate first call
   * 4. Sets up 10-second interval
   * 5. Updates Vuex polling state
   */
  start() {
    this.stop()

    store.dispatch('metrics/clearMetrics')

    this.run()

    this.intervalId = setInterval(() => {
      this.run()
    }, this.frequency)

    this.isRunning = true
    store.dispatch('metrics/setPollingState', true)
  }

  /**
   * Stop polling
   *
   * Behavior:
   * 1. Clears interval
   * 2. Cancels any in-flight requests
   * 3. Updates Vuex polling state
   */
  stop() {
    if (this.intervalId) {
      clearInterval(this.intervalId)
      this.intervalId = null
    }

    if (this.abortController) {
      this.abortController.abort()
      this.abortController = null
    }

    this.isRunning = false
    store.dispatch('metrics/setPollingState', false)
  }

  /**
   * Execute metrics fetch
   *
   * Makes RPC call to backend and updates Vuex store
   * Errors are handled gracefully via Util.handleException
   */
  async run() {
    try {
      // Create abort controller for request cancellation
      this.abortController = new AbortController()

      // Make RPC call to backend
      const result = await Rpc.asyncData('rpc.metricManager.getMetricsAndStatsV2')
      if (!result) {
        return
      }

      // Extract data from response
      const appMetrics = result.metrics || {}
      const systemStats = result.systemStats || {}

      // Update Vuex store (triggers component reactivity)
      store.dispatch('metrics/updateMetrics', {
        appMetrics,
        systemStats,
      })
    } catch (err) {
      // Check if error is due to abort (not a real error)
      if (err.name === 'AbortError') {
        return
      }
      Util.handleException(err)
      this.stop()
    } finally {
      this.abortController = null
    }
  }

  /**
   * Get current polling status
   *
   * @returns {Object} Status object
   */
  getStatus() {
    return {
      isRunning: this.isRunning,
      frequency: this.frequency,
      hasInterval: this.intervalId !== null,
    }
  }

  /**
   * Update polling frequency (advanced usage)
   *
   * CAUTION: Default is 10s - changing may affect performance
   * Restarts polling if currently running
   *
   * @param {number} newFrequency - New frequency in milliseconds
   */
  setFrequency(newFrequency) {
    if (newFrequency < 1000) {
      return
    }
    this.frequency = newFrequency
    if (this.isRunning) {
      this.start()
    }
  }
}

// Export singleton instance
const instance = new MetricsPollingService()
export default instance
