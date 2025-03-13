import http from '@/plugins/http'
import api from '@/plugins/api'

export const state = () => ({
  isAuth: false,
})

const mutations = {
  SET_IS_AUTH: (state, value) => (state.isAuth = value),
}

const actions = {
  /**
   * Check the authentication by calling 'getSettings' to see if the user is authorized or not.
   *
   * @param {Object}   state
   * @param {Function} commit
   * @param {Function} dispatch
   */
  async checkAuth({ rootState, commit, dispatch }) {
    await dispatch('settings/getSettings', true, { root: true })
    commit('SET_IS_AUTH', !!rootState.settings.settings)

    if (rootState.settings.settings) {
      await dispatch('hardware/getHardware', true, { root: true })
    }
  },

  /**
   * Try to login the user.  Check authentication after.
   *
   * @param {Function} dispatch
   * @param {string}   username
   * @param {string}   password
   *
   * @returns {Promise<boolean>}
   */
  async login({ dispatch }, { username, password }) {
    // post as form data
    const data = new FormData()
    data.append('username', username)
    data.append('password', password)

    let response
    try {
      response = await http({ url: '/account/login', method: 'post', data })
    } catch (ex) {
      response = ex.response
    }

    // check for success response
    if (response?.status === 200) {
      await dispatch('checkAuth')
      return true
    }

    return false
  },

  /**
   * Logout the user.
   *
   * @param {Function} commit
   */
  async logout({ commit }) {
    await api.get('/account/logout')
    commit('SET_IS_AUTH', false)
  },
}

export default {
  namespaced: true,
  state,
  mutations,
  actions,
}
