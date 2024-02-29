import Vue from 'vue'
import Vuex, { Store } from 'vuex'
import settings from './settings'

Vue.use(Vuex)

const getDefaultState = () => ({
  fetching: false,
  data: undefined,
})

const mutations = {
  RESET: state => Object.assign(state, getDefaultState()),
  SET_FETCHING: (state, value) => (state.fetching = value),
  SET_DATA: (state, value) => (state.data = value),
}

const actions = {
  /**
   * Resets entire store and it's modules to an initial state. Usually after user logs out
   * @param {Function} commit
   */
  resetState({ commit }) {
    commit('RESET')
  },
}

export default new Store({
  modules: {
    settings,
  },
  state: getDefaultState,
  mutations,
  actions,
})
