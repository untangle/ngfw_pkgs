/**
 * Context Module - Application context (ADMIN vs REPORTS)
 *
 * Reads ?context=REPORTS from the URL query string at startup, defaulting to ADMIN.
 * All context-dependent branching reads from this single store value.
 */

const ADMIN = 'ADMIN'
const REPORTS = 'REPORTS'

const state = () => ({
  context: ADMIN,
})

const getters = {
  context: state => state.context,
  isAdmin: state => state.context === ADMIN,
  isReports: state => state.context === REPORTS,

  rpcEndpoint: state => (state.context === REPORTS ? '/reports/JSON-RPC' : '/admin/JSON-RPC'),

  downloadEndpoint: state => (state.context === REPORTS ? '/reports/csv' : '/admin/download'),
}

const mutations = {
  SET_CONTEXT(state, context) {
    state.context = context === REPORTS ? REPORTS : ADMIN
  },
}

const actions = {
  initContext({ commit }) {
    const params = new URLSearchParams(window.location.search)
    const ctx = params.get('context')
    if (ctx) {
      commit('SET_CONTEXT', ctx.toUpperCase())
    }
  },
}

export default {
  namespaced: true,
  state,
  getters,
  mutations,
  actions,
}
