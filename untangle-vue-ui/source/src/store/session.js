/**
 * Session Module - NOT persisted to localStorage
 *
 * Tracks initialization state per session. Resets on page load/hard refresh,
 * ensuring RPC calls run fresh on every session.
 */

import Util from '@/util/setupUtil'

const state = () => ({
  // Tracks if admin context initialized this session
  adminContextInitialized: false,
  // Tracks if reports context initialized this session
  reportsContextInitialized: false,
})

const getters = {
  isAdminContextInitialized: state => state.adminContextInitialized,
}

const mutations = {
  SET_ADMIN_CONTEXT_INITIALIZED(state, value) {
    state.adminContextInitialized = value
  },

  SET_REPORTS_CONTEXT_INITIALIZED(state, value) {
    state.reportsContextInitialized = value
  },

  RESET(state) {
    state.adminContextInitialized = false
    state.reportsContextInitialized = false
  },
}

const actions = {
  /**
   * Initialize admin context - loads apps, policy-manager, reports
   */
  async initializeAdminContext({ commit, state, dispatch }) {
    if (state.adminContextInitialized) {
      return { success: true, cached: true }
    }

    try {
      await Promise.all([
        dispatch('apps/getAppsViews', true, { root: true }),
        dispatch('apps/loadAppData', { appName: 'policy-manager' }, { root: true }),
        dispatch('reports/loadReports', null, { root: true }),
        // Required for server-timezone-aware date/time in Reports date picker.
        // Must run at boot so DateTimeRangePresets receives the correct offset via $serverTimezoneOffsetMs.
        dispatch('config/getTimeZoneOffSet', null, { root: true }),
        // Compute server-vs-browser wall-clock delta so maxDate and presets use server time, not browser time.
        dispatch('config/getServerClockOffsetMs', null, { root: true }),
      ])

      commit('SET_ADMIN_CONTEXT_INITIALIZED', true)
      return { success: true }
    } catch (error) {
      Util.handleException(error, 'Failed to initialize admin context')
      return { success: false, error }
    }
  },

  /**
   * Initialize standalone reports context - loads only reports, timezone, and clock offset.
   * Skips apps and policy-manager which are not available via the Reports RPC endpoint.
   */
  async initializeReportsContext({ commit, state, dispatch }) {
    if (state.reportsContextInitialized) {
      return { success: true, cached: true }
    }

    try {
      await Promise.all([
        dispatch('reports/loadReports', null, { root: true }),
        dispatch('config/getTimeZoneOffSet', null, { root: true }),
        dispatch('config/getServerClockOffsetMs', null, { root: true }),
      ])

      commit('SET_REPORTS_CONTEXT_INITIALIZED', true)
      return { success: true }
    } catch (error) {
      Util.handleException(error, 'Failed to initialize reports context')
      return { success: false, error }
    }
  },

  reset({ commit }) {
    commit('RESET')
  },
}

export default {
  namespaced: true,
  state,
  getters,
  mutations,
  actions,
}
