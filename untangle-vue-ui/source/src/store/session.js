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
})

const getters = {
  isAdminContextInitialized: state => state.adminContextInitialized,
}

const mutations = {
  SET_ADMIN_CONTEXT_INITIALIZED(state, value) {
    state.adminContextInitialized = value
  },

  RESET(state) {
    state.adminContextInitialized = false
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
        dispatch('apps/getAppViews', true, { root: true }),
        dispatch('apps/loadAppData', 'policy-manager', { root: true }),
        dispatch('reports/loadReports', null, { root: true }),
      ])

      commit('SET_ADMIN_CONTEXT_INITIALIZED', true)
      return { success: true }
    } catch (error) {
      Util.handleException(error, 'Failed to initialize admin context')
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
