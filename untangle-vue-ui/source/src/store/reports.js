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

  // Cached reports manager instance — acquired once at boot, reused on every data fetch
  reportsManager: null,

  // Timestamp of last load (for cache invalidation if needed)
  lastLoaded: null,

  // Policy list from backend — populated lazily on first EVENT_LIST view
  policiesInfo: [],

  // Global conditions applied across all reports — persists across route navigation
  // Each condition: { column, operator, value, autoFormatValue }
  globalConditions: [],
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

  /**
   * Maps policy ID (integer) → "name [id]" display string.
   * Populated lazily by fetchPoliciesInfo when an EVENT_LIST report is opened.
   * Returns an empty map when no policy-manager is installed.
   */
  globalConditions: state => state.globalConditions,

  policyNameMap: state => {
    const map = {}
    state.policiesInfo.forEach(p => {
      if (p.policyId != null) {
        map[p.policyId] = p.name ? `${p.name} [${p.policyId}]` : String(p.policyId)
      }
    })
    return map
  },
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

  SET_REPORTS_MANAGER(state, manager) {
    state.reportsManager = manager
  },

  SET_LAST_LOADED(state, timestamp) {
    state.lastLoaded = timestamp
  },

  SET_POLICIES_INFO(state, policies) {
    state.policiesInfo = policies
  },

  SET_GLOBAL_CONDITIONS(state, conditions) {
    state.globalConditions = conditions
  },

  ADD_GLOBAL_CONDITION(state, condition) {
    state.globalConditions.push(condition)
  },

  REMOVE_GLOBAL_CONDITION(state, index) {
    state.globalConditions.splice(index, 1)
  },

  CLEAR_GLOBAL_CONDITIONS(state) {
    state.globalConditions = []
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
      commit('SET_REPORTS_MANAGER', reportsManager)

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

  /**
   * Fetches policy name/ID pairs from the backend for EVENT_LIST detail rendering.
   * Only runs once — returns immediately if policiesInfo is already populated.
   * Returns an empty list when no policy-manager is installed.
   */
  async fetchPoliciesInfo({ state, commit }) {
    if (state.policiesInfo.length) return
    if (!state.reportsManager) return
    try {
      const result = await Rpc.asyncData(state.reportsManager, 'getPoliciesInfo')
      if (result?.list) commit('SET_POLICIES_INFO', result.list)
    } catch (error) {
      Util.handleException(error)
    }
  },

  /**
   * Fetches report data from the backend for a given report entry and time range.
   *
   * The backend returns a type-aware JSONObject:
   *   { series: [...] }  for TIME_GRAPH / TIME_GRAPH_DYNAMIC
   *   { slices: [...] }  for PIE_GRAPH
   *   { list:   [...] }  for EVENT_LIST / TEXT
   *
   * @param {Object} payload
   * @param {Object} payload.entry       - full ReportEntry object
   * @param {Array}  payload.conditions  - SQL filter conditions excluding time range entries
   * @param {Date}   payload.startDate   - query start date
   * @param {Date}   payload.endDate     - query end date; null means open-ended
   * @param {Number} payload.limit       - maximum rows to return; -1 for unlimited
   * @returns {Object} backend payload with either a `data` key (chart) or `list` key (events)
   */
  async fetchReportData({ state, dispatch }, { entry, conditions = [], startDate, endDate, limit = -1 }) {
    const callRpc = manager =>
      Rpc.asyncData(manager, 'getDataForReportEntryV2', entry, startDate, endDate, null, conditions, null, limit)

    let result
    try {
      result = await callRpc(state.reportsManager)
    } catch (error) {
      // Jabsorb session can expire after inactivity, making the cached reportsManager
      // proxy invalid ("No such method"). Re-acquire the manager and retry once.
      const isStaleProxy = error?.message?.includes('No such method') || error?.message?.includes('no such object')

      if (!isStaleProxy) {
        Util.handleException(error)
        return { list: [] }
      }

      // Re-initialise the reports manager and retry the request
      await dispatch('loadReports')
      try {
        result = await callRpc(state.reportsManager)
      } catch (retryError) {
        Util.handleException(retryError)
        return { list: [] }
      }
    }

    if (!result) return { list: [] }

    // Chart types return { series: [...] } or { slices: [...] } at the root level
    if (result.series || result.slices) {
      return { data: result }
    }

    // TEXT returns a pre-substituted string from the backend
    if (result.text !== undefined) {
      return { text: result.text }
    }

    return { list: result.list ?? [] }
  },
}

export default {
  namespaced: true,
  state: getDefaultState,
  getters,
  mutations,
  actions,
}
