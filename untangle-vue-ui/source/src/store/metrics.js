/**
 * Metrics Store Module
 *
 * Manages real-time metrics polling
 *
 * Architecture:
 * - Centralized state for all app metrics
 * - Updated by MetricsPollingService every 10 seconds
 * - Components subscribe via Vuex getters
 * - NOT persisted to localStorage (transient data)
 *
 * Key Difference from apps.js:
 * - apps.js: On-demand app configuration (persisted)
 * - metrics.js: Continuous polling data (transient)
 */

const state = () => ({
  /**
   * App metrics keyed by instance.id
   * Structure matches backend response from metricManager.getMetricsAndStatsV2()
   */
  appMetrics: {},

  systemStats: {}, // System level statistics
  isPolling: false, // Polling state flags
  lastUpdate: null,
  error: null,
  expertMode: false, // When false, metrics with expert: true are hidden
})

const getters = {
  /**
   * Get raw metrics for a specific app instance
   *
   * @param {string|number} instanceId - App instance ID (e.g., 12345)
   * @returns {Object|null} Metrics object with list array, or null if not found
   */
  getAppMetrics: state => instanceId => {
    if (!instanceId) return null
    return state.appMetrics[String(instanceId)] || null
  },

  /**
   * Get a specific metric value for an app
   *
   * @param {string|number} instanceId - App instance ID
   * @param {string} metricName - Metric name (e.g., 'live-sessions')
   * @returns {Object|null} Metric object or null
   */
  getAppMetric: state => (instanceId, metricName) => {
    if (!instanceId || !metricName) return null

    const appMetrics = state.appMetrics[String(instanceId)]
    if (!appMetrics) return null

    return appMetrics.find(m => m.name === metricName) || null
  },

  /**
   * Get formatted metrics for UI display
   *
   * Transforms backend metrics into UI-ready format:
   * - Filters out expert metrics if expertMode is false
   * - Concatenates value + displayUnits
   * - Returns array in UAppStatusMetrics component format
   *
   * @param {string|number} instanceId - App instance ID
   * @returns {Array} Array of {key, value, formatter} objects for UAppStatusMetrics
   */
  getFormattedMetrics: state => instanceId => {
    if (!instanceId) return []

    const appMetrics = state.appMetrics[String(instanceId)]
    if (!appMetrics) return []

    return appMetrics
      .filter(metric => !metric.expert || state.expertMode)
      .map(metric => ({
        key: metric.displayName,
        value: metric.value + (metric.displayUnits ? ' ' + metric.displayUnits : ''),
        formatter: null,
      }))
  },

  /**
   * Get live sessions count for an app
   * Convenience getter for the 'live-sessions' metric
   * Used by sessions chart component
   *
   * @param {string|number} instanceId - App instance ID
   * @returns {number} Live sessions count (0 if not found)
   */
  getLiveSessions: (state, getters) => instanceId => {
    if (!instanceId) return 0

    const metric = getters.getAppMetric(instanceId, 'live-sessions')
    return metric ? metric.value : 0
  },

  /**
   * Check if polling is currently active
   * @returns {boolean} True if polling is running
   */
  isPollingActive: state => state.isPolling,

  /**
   * Get last update timestamp
   * @returns {number|null} Timestamp of last successful update, or null
   */
  lastUpdateTime: state => state.lastUpdate,

  /**
   * Get system statistics
   * @returns {Object} System stats object
   */
  systemStats: state => state.systemStats,

  /**
   * Get expert mode state
   * @returns {boolean} True if expert mode is enabled
   */
  expertMode: state => state.expertMode,

  /**
   * Get current error (if any)
   * @returns {string|null} Error message or null
   */
  error: state => state.error,
}

const mutations = {
  /**
   * Set all metrics data (called by polling service)
   * This is the primary mutation for updating metrics
   * Called by MetricsPollingService every 10 seconds
   *
   * @param {Object} state - Vuex state
   * @param {Object} payload - { appMetrics, systemStats }
   */
  SET_METRICS_DATA(state, { appMetrics, systemStats }) {
    // Update both metrics and stats
    state.appMetrics = appMetrics || {}
    state.systemStats = systemStats || {}

    // Update metadata
    state.lastUpdate = Date.now()
    state.error = null
  },

  /**
   * Set polling state
   * @param {Object} state - Vuex state
   * @param {boolean} isPolling - True if polling is active
   */
  SET_POLLING_STATE(state, isPolling) {
    state.isPolling = isPolling
  },

  /**
   * Set error state
   * @param {Object} state - Vuex state
   * @param {string} error - Error message
   */
  SET_ERROR(state, error) {
    state.error = error
  },

  /**
   * Set expert mode
   * @param {Object} state - Vuex state
   * @param {boolean} expertMode - True if expert mode is enabled
   */
  SET_EXPERT_MODE(state, expertMode) {
    state.expertMode = expertMode
  },

  /**
   * Clear all metrics (on logout/cleanup)
   * Resets state to initial values
   */
  CLEAR_METRICS(state) {
    state.appMetrics = {}
    state.systemStats = {}
    state.lastUpdate = null
    state.error = null
  },
}

const actions = {
  /**
   * Initialize expert mode from RPC
   *
   * Should be called once during app initialization
   * Fetches expert mode state from backend
   */
  async initExpertMode({ commit }) {
    try {
      const expertMode = await window.rpc.isExpertMode
      commit('SET_EXPERT_MODE', expertMode)
      return { success: true, expertMode }
    } catch (err) {
      commit('SET_EXPERT_MODE', false)
      return { success: false, error: err }
    }
  },

  /**
   * Update metrics data (called by polling service)
   *
   * This is the primary action for updating metrics
   * Should ONLY be called by MetricsPollingService
   *
   * @param {Object} context - Vuex context
   * @param {Object} data - { appMetrics, systemStats }
   */
  updateMetrics({ commit }, data) {
    commit('SET_METRICS_DATA', data)
  },

  /**
   * Set polling state
   *
   * @param {Object} context - Vuex context
   * @param {boolean} isPolling - True if polling is active
   */
  setPollingState({ commit }, isPolling) {
    commit('SET_POLLING_STATE', isPolling)
  },

  /**
   * Handle error
   *
   * @param {Object} context - Vuex context
   * @param {string} error - Error message
   */
  setError({ commit }, error) {
    commit('SET_ERROR', error)
  },

  /**
   * Clear metrics
   *
   * Should be called on logout or when stopping polling
   */
  clearMetrics({ commit }) {
    commit('CLEAR_METRICS')
  },
}

export default {
  namespaced: true,
  state,
  getters,
  mutations,
  actions,
}
