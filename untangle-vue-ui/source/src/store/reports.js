/**
 * Reports Module - Global state for all reports
 *
 * Loads reports once at boot, stores globally, filters per-app by category.
 */

import Rpc from '@/util/Rpc'
import Util from '@/util/setupUtil'
import { baseCategories, urlEncode } from '@/util/reports'

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
  allReports: state => state.allReports,

  // O(1) lookup by category name
  getReportsByCategory: state => category => {
    return state.reportsByCategory[category] || []
  },

  // Merges built-in system categories with installed app categories from the backend,
  // then sorts the combined list by viewPosition so categories render in the correct order.
  allCategories: state => {
    const appCategories = state.categories.map(cat => ({ ...cat, type: 'app' }))
    return [...baseCategories, ...appCategories].sort((a, b) => a.viewPosition - b.viewPosition)
  },

  // Normalized categories shape for the ReportsNav dropdown.
  // Filters out empty categories and projects only the fields the dropdown needs.
  categoriesForNav: (state, getters) => {
    return getters.allCategories
      .filter(cat => (state.reportsByCategory[cat.displayName] || []).length)
      .map(cat => ({
        id: urlEncode(cat.displayName),
        displayName: cat.displayName,
        reports: (state.reportsByCategory[cat.displayName] || []).map(r => ({
          id: r.uniqueId,
          name: r.title,
          type: r.type,
          timeStyle: r.timeStyle,
          pieStyle: r.pieStyle,
          description: r.description,
        })),
      }))
  },

  isReportsInstalled: state => state.isReportsInstalled,
  categories: state => state.categories,
  loading: state => state.loading,
  error: state => state.error,
  isLoaded: state => state.allReports.length > 0 || state.lastLoaded !== null,
}

const mutations = {
  SET_REPORTS(state, reports) {
    state.allReports = reports

    // Normalize by category for O(1) filtering
    state.reportsByCategory = reports.reduce((acc, report) => {
      const category = report.category
      if (!acc[category]) {
        acc[category] = []
      }
      acc[category].push(report)
      return acc
    }, {})
  },

  SET_CATEGORIES(state, categories) {
    state.categories = categories
  },

  SET_LOADING(state, loading) {
    state.loading = loading
  },

  SET_ERROR(state, error) {
    state.error = error
  },

  SET_REPORTS_INSTALLED(state, installed) {
    state.isReportsInstalled = installed
  },

  SET_LAST_LOADED(state, timestamp) {
    state.lastLoaded = timestamp
  },

  RESET(state) {
    Object.assign(state, getDefaultState())
  },
}

const actions = {
  /**
   * Load all reports from backend
   * Called once at application boot via router guard
   */
  async loadReports({ commit }) {
    commit('SET_LOADING', true)
    commit('SET_ERROR', null)

    try {
      // Check if Reports app installed
      const reportsApp = await Rpc.asyncData('rpc.appManager.app', 'reports')

      if (!reportsApp) {
        commit('SET_REPORTS_INSTALLED', false)
        commit('SET_LOADING', false)
        return { success: false, reason: 'not_installed' }
      }

      commit('SET_REPORTS_INSTALLED', true)

      const reportsManager = await Rpc.asyncData(reportsApp, 'getReportsManager')

      // Parallel RPC calls
      const [reportsResult, categoriesResult] = await Promise.all([
        Rpc.asyncData(reportsManager, 'getReportEntriesV2'),
        Rpc.asyncData(reportsManager, 'getCurrentApplications').catch(() => null),
      ])

      if (reportsResult) {
        commit('SET_REPORTS', reportsResult)
      }

      if (categoriesResult && categoriesResult.list) {
        commit('SET_CATEGORIES', categoriesResult.list)
      }

      commit('SET_LAST_LOADED', Date.now())
      commit('SET_LOADING', false)

      return { success: true }
    } catch (error) {
      commit('SET_ERROR', error.message || 'Failed to load reports')
      commit('SET_LOADING', false)
      Util.handleException(error, 'Failed to load reports')
      return { success: false, error }
    }
  },

  refreshReports({ dispatch }) {
    return dispatch('loadReports')
  },

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
