import Vue from 'vue'
import Vuex, { Store } from 'vuex'
import settings from './settings'
import setup from './setup'
import auth from './auth'

Vue.use(Vuex)

const getDefaultState = () => ({
  // changes for layout
  pageLoad: false,
  cachedComponents: ['ReportDetails'],
  helpContext: null,

  fetching: false,
  data: undefined,
})

const mutations = {
  RESET: state => Object.assign(state, getDefaultState()),
  SET_FETCHING: (state, value) => (state.fetching = value),
  SET_DATA: (state, value) => (state.data = value),
  /// changes after the
  SET_HELP_CONTEXT: (state, value) => (state.helpContext = value),
  SET_LOADER: (state, value) => (state.pageLoad = value),
  SET_MINI_DRAWER: (state, value) => {
    state.miniDrawer = value
    localStorage.setItem('mini-drawer', value)
  },
  ADD_UNIQUE_CACHED_COMPONENT: (state, value) => {
    if (!state.cachedComponents.includes(value)) {
      state.cachedComponents.push(value)
    }
  },
  DELETE_CACHED_COMPONENT: (state, value) => {
    const index = state.cachedComponents.indexOf(value)
    if (index !== -1) {
      state.cachedComponents.splice(index, 1)
    }
  },
}

const actions = {
  /**
   * Resets entire store and it's modules to an initial state. Usually after user logs out
   * @param {Function} commit
   */
  resetState({ commit }) {
    commit('RESET')
    commit('settings/RESET')
  },
}

export default new Store({
  modules: {
    auth,
    settings,
    setup,
  },
  state: getDefaultState,
  mutations,
  actions,
})