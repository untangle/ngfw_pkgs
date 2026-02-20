/**
 * Vuex module for global reports state
 *
 * This module manages report definitions loaded from the Reports app.
 * Reports are loaded once at application boot and stored globally,
 * then filtered per-app by category (app display name).
 *
 * This matches the ExtJS pattern where reports are loaded via
 * Application.reportscheck() and stored in global memory stores.
 */

import Rpc from '@/util/Rpc'

const getDefaultState = () => ({
  // Raw reports array from backend
  allReports: [],

  // Normalized map for O(1) lookup by category
  // { 'Application Control Lite': [...reports], 'Web Filter': [...reports] }
  reportsByCategory: {},

  // Categories list (for future use)
  categories: [],

  // Loading state
  loading: false,

  // Error state
  error: null,

  // Whether Reports app is installed
  isReportsInstalled: false,

  // Timestamp of last load (for cache invalidation if needed)
  lastLoaded: null,
})

const getters = {
  /**
   * Get all reports
   * @param {Object} state
   * @returns {Array} All reports
   */
  allReports: state => state.allReports,

  /**
   * Get reports by category (app display name)
   * @param {Object} state
   * @returns {Function} Function that takes category and returns reports array
   */
  getReportsByCategory: state => category => {
    return state.reportsByCategory[category] || []
  },

  /**
   * Check if Reports app is installed
   * @param {Object} state
   * @returns {Boolean}
   */
  isReportsInstalled: state => state.isReportsInstalled,

  /**
   * Get all categories
   * @param {Object} state
   * @returns {Array}
   */
  categories: state => state.categories,

  /**
   * Get loading state
   * @param {Object} state
   * @returns {Boolean}
   */
  loading: state => state.loading,

  /**
   * Get error
   * @param {Object} state
   * @returns {String|null}
   */
  error: state => state.error,

  /**
   * Check if reports are loaded
   * @param {Object} state
   * @returns {Boolean}
   */
  isLoaded: state => state.allReports.length > 0 || state.lastLoaded !== null,
}

const mutations = {
  /**
   * Set reports and normalize by category
   * @param {Object} state
   * @param {Array} reports - Reports array from backend
   */
  SET_REPORTS(state, reports) {
    state.allReports = reports

    // Normalize by category for O(1) filtering
    // This matches the ExtJS pattern where AppReports filters from global store
    state.reportsByCategory = reports.reduce((acc, report) => {
      const category = report.category
      if (!acc[category]) {
        acc[category] = []
      }
      acc[category].push(report)
      return acc
    }, {})
  },

  /**
   * Set categories
   * @param {Object} state
   * @param {Array} categories
   */
  SET_CATEGORIES(state, categories) {
    state.categories = categories
  },

  /**
   * Set loading state
   * @param {Object} state
   * @param {Boolean} loading
   */
  SET_LOADING(state, loading) {
    state.loading = loading
  },

  /**
   * Set error
   * @param {Object} state
   * @param {String|null} error
   */
  SET_ERROR(state, error) {
    state.error = error
  },

  /**
   * Set whether Reports app is installed
   * @param {Object} state
   * @param {Boolean} installed
   */
  SET_REPORTS_INSTALLED(state, installed) {
    state.isReportsInstalled = installed
  },

  /**
   * Set last loaded timestamp
   * @param {Object} state
   * @param {Number} timestamp
   */
  SET_LAST_LOADED(state, timestamp) {
    state.lastLoaded = timestamp
  },

  /**
   * Reset state to default
   * @param {Object} state
   */
  RESET(state) {
    Object.assign(state, getDefaultState())
  },
}

const actions = {
  /**
   * Load all reports from backend
   * This matches ExtJS Application.reportscheck() which makes parallel RPC calls:
   * - rpc.reportsManager.getReportEntries()
   * - rpc.reportsManager.getCurrentApplications()
   *
   * Called once at application boot via router guard.
   *
   * @param {Object} context - Vuex context
   * @returns {Promise<Object>} Result object with success status
   */
  async loadReports({ commit }) {
    commit('SET_LOADING', true)
    commit('SET_ERROR', null)

    try {
      // Check if Reports app is installed
      // Matches: Rpc.directData('rpc.appManager.app', 'reports')
      const reportsApp = await Rpc.asyncData('rpc.appManager.app', 'reports')

      if (!reportsApp) {
        commit('SET_REPORTS_INSTALLED', false)
        commit('SET_LOADING', false)
        return { success: false, reason: 'not_installed' }
      }

      commit('SET_REPORTS_INSTALLED', true)

      // Get reports manager
      // Matches: Rpc.directData('rpc.appManager.app("reports").getReportsManager')
      const reportsManager = await Rpc.asyncData(reportsApp, 'getReportsManager')

      // Parallel RPC calls (matches ExtJS Ext.Deferred.parallel pattern)
      // - getReportEntries: Get all report definitions
      // - getCurrentApplications: Get app categories (optional)
      const [reportsResult, categoriesResult] = await Promise.all([
        Rpc.asyncData(reportsManager, 'getReportEntries'),
        Rpc.asyncData(reportsManager, 'getCurrentApplications').catch(() => null),
      ])

      // Process reports
      if (reportsResult && reportsResult.list) {
        commit('SET_REPORTS', reportsResult.list)
      }

      // Process categories (optional, for future use)
      if (categoriesResult && categoriesResult.list) {
        commit('SET_CATEGORIES', categoriesResult.list)
      }

      commit('SET_LAST_LOADED', Date.now())
      commit('SET_LOADING', false)

      return { success: true }
    } catch (error) {
      commit('SET_ERROR', error.message || 'Failed to load reports')
      commit('SET_LOADING', false)
      return { success: false, error }
    }
  },

  /**
   * Refresh reports (reload from backend)
   * @param {Object} context - Vuex context
   * @returns {Promise<Object>}
   */
  refreshReports({ dispatch }) {
    return dispatch('loadReports')
  },

  /**
   * Reset reports state
   * @param {Object} context - Vuex context
   */
  resetReports({ commit }) {
    commit('RESET')
  },
}

export default {
  namespaced: true,
  state: getDefaultState,
  getters,
  mutations,
  actions,
}
