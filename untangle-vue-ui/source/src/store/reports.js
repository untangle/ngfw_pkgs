/**
 * Reports Module - Global state for all reports
 *
 * Loads reports once at boot, stores globally, filters per-app by category.
 */

import Rpc from '@/util/Rpc'
import Util from '@/util/setupUtil'
import { getReportIcon, urlEncode } from '@/util/reports'

let cachedReportsManager = null

async function getReportsManager() {
  if (cachedReportsManager) return cachedReportsManager
  const reportsApp = await Rpc.asyncData('rpc.appManager.app', 'reports')
  if (!reportsApp) return null
  cachedReportsManager = await Rpc.asyncData(reportsApp, 'getReportsManager')
  return cachedReportsManager
}

const getDefaultState = () => ({
  // Raw reports array from backend
  allReports: [],

  // Normalized map for O(1) lookup by category
  // { 'Application Control Lite': [...reports], 'Web Filter': [...reports] }
  reportsByCategory: {},

  // Categories from getCurrentApplications (app categories only)
  categories: [],

  // All categories from getAllCategoriesV2 (system + app)
  allCategories: [],

  // Loading state
  loading: false,

  // Error state
  error: null,

  // Whether Reports app is installed
  isReportsInstalled: false,

  // Timestamp of last load (for cache invalidation if needed)
  lastLoaded: null,

  // Per-entry fetched data, keyed by uniqueId: { [uniqueId]: { list: [...], fetchedAt, loading, error } }
  reportData: {},
})

const getters = {
  allReports: state => state.allReports,

  // O(1) lookup by category
  getReportsByCategory: state => category => {
    return state.reportsByCategory[category] || []
  },

  isReportsInstalled: state => state.isReportsInstalled,
  categories: state => state.categories,
  allCategories: state => state.allCategories,
  loading: state => state.loading,
  error: state => state.error,
  isLoaded: state => state.allReports.length > 0 || state.lastLoaded !== null,

  /**
   * Reports keyed by category displayName, ordered by viewPosition.
   * Each entry is shaped like a vuntangle "view" so the same MFW template
   * can render it without branching:
   *   { [displayName]: [{ id, name, reports: [uniqueId] }] }
   */
  cardItems: state => {
    const ordered = [...state.allCategories].sort((a, b) => (a.viewPosition || 0) - (b.viewPosition || 0))
    const result = {}
    ordered.forEach(cat => {
      const reports = (state.reportsByCategory[cat.displayName] || [])
        .slice()
        .sort((a, b) => (a.displayOrder || 0) - (b.displayOrder || 0))
      result[cat.displayName] = reports.map(r => ({
        id: r.uniqueId,
        name: r.title,
        reports: [r.uniqueId],
      }))
    })
    return result
  },

  /**
   * Lookup map of report metadata keyed by uniqueId, matching the shape
   * vuntangle/Reports expects from its `reports` prop:
   *   { [uniqueId]: { icon, title } }
   */
  reportsLookup: state =>
    state.allReports.reduce((acc, r) => {
      acc[r.uniqueId] = {
        icon: getReportIcon(r.type),
        title: r.description,
      }
      return acc
    }, {}),

  // Resolves route slugs (/reports/:cat/:rep) back to the raw report entry
  getReportBySlug: state => (catSlug, repSlug) =>
    state.allReports.find(r => urlEncode(r.category) === catSlug && urlEncode(r.title) === repSlug) || null,

  getReportData: state => uniqueId => state.reportData[uniqueId] || null,
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

  SET_ALL_CATEGORIES(state, categories) {
    state.allCategories = categories
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

  SET_REPORT_DATA(state, { uniqueId, payload }) {
    state.reportData = { ...state.reportData, [uniqueId]: payload }
  },

  RESET(state) {
    cachedReportsManager = null
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
      cachedReportsManager = reportsManager

      // Parallel RPC calls
      const [reportsResult, categoriesResult, allCategoriesResult] = await Promise.all([
        Rpc.asyncData(reportsManager, 'getReportEntriesV2'),
        Rpc.asyncData(reportsManager, 'getCurrentApplications').catch(() => null),
        Rpc.asyncData(reportsManager, 'getAllCategoriesV2').catch(() => null),
      ])
      console.log('reportsResult', reportsResult)
      console.log('categoriesResult', categoriesResult)
      console.log('allCategoriesV2Result', allCategoriesResult)

      if (reportsResult) {
        commit('SET_REPORTS', reportsResult)
      }

      if (categoriesResult && categoriesResult.list) {
        commit('SET_CATEGORIES', categoriesResult.list)
      }

      if (Array.isArray(allCategoriesResult)) {
        commit('SET_ALL_CATEGORIES', allCategoriesResult)
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
   * Fetch data for a single report entry via getDataForReportEntryV2.
   * Result is cached in state under reportData[uniqueId]. Safe to call
   * before loadReports — resolves the reports manager on demand.
   *
   * @param {Object} payload
   * @param {string} payload.uniqueId - report entry uniqueId
   * @param {Date}   [payload.startDate]
   * @param {Date}   [payload.endDate]
   * @param {Array}  [payload.extraConditions]
   * @param {number} [payload.limit=-1]
   * @returns {Promise<{ list: Array, loading: boolean, error: ?string, fetchedAt: ?number }>}
   */
  async fetchReportData(
    { commit, state },
    { uniqueId, startDate = null, endDate = null, extraConditions = [], limit = -1 } = {},
  ) {
    if (!uniqueId) return null
    const entry = state.allReports.find(r => r.uniqueId === uniqueId)
    if (!entry) return null

    commit('SET_REPORT_DATA', { uniqueId, payload: { list: [], loading: true, error: null, fetchedAt: null } })

    try {
      const reportsManager = await getReportsManager()
      if (!reportsManager) throw new Error('Reports app not available')

      const now = new Date()
      const effectiveStart = startDate || new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0)

      const result = await Rpc.asyncData(
        reportsManager,
        'getDataForReportEntryV2',
        entry,
        effectiveStart,
        endDate,
        null,
        extraConditions,
        null,
        limit,
      )

      // Chart types return { metadata, series[] } or { metadata, slices[] }
      // Event/Text types return { list: [...] }
      const payload =
        result?.series || result?.slices
          ? { data: result, loading: false, error: null, fetchedAt: Date.now() }
          : { list: Array.isArray(result?.list) ? result.list : [], loading: false, error: null, fetchedAt: Date.now() }
      commit('SET_REPORT_DATA', { uniqueId, payload })
      return payload
    } catch (error) {
      const payload = { list: [], loading: false, error: error.message || 'Fetch failed', fetchedAt: Date.now() }
      commit('SET_REPORT_DATA', { uniqueId, payload })
      Util.handleException(error, `Failed to fetch report data for ${uniqueId}`)
      return payload
    }
  },
}

export default {
  namespaced: true,
  state: getDefaultState,
  getters,
  mutations,
  actions,
}
