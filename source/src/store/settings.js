// import vuntangle from '@/plugins/vuntangle'
// // import i18n from '@/plugins/vue-i18n'

// const getDefaultState = () => ({
//   networkSettings: null,
// })

// const getters = {
//   networkSettings: state => state.networkSettings,
//   lanInterfaces: state => state.networkSettings.interfaces.list.filter(intf => !intf.isWan),
// }

// const mutations = {
//   RESET: state => Object.assign(state, getDefaultState()),
//   SET_NETWORK_SETTINGS: (state, value) => (state.networkSettings = value),
// }

// const actions = {
//   async fetchNetworkSettings({ commit, state }) {
//     if (state.networkSettings !== null) return
//     commit('SET_FETCHING', true, { root: true })
//     const data = await window.rpc.networkManager.getNetworkSettings()
//     commit('SET_FETCHING', false, { root: true })
//     if (data) {
//       commit('SET_NETWORK_SETTINGS', data)
//     }
//   },

//   saveNetworkSettings({ commit }, settings) {
//     return new Promise((resolve, reject) => {
//       commit('SET_FETCHING', true, { root: true })
//       window.rpc.networkManager.setNetworkSettings((response, exception) => {
//         commit('SET_FETCHING', false, { root: true })
//         if (exception) {
//           vuntangle.toast.add(exception.message, 'error')
//           reject(exception)
//           return
//         }
//         commit('SET_NETWORK_SETTINGS', settings)
//         vuntangle.toast.add(vuntangle.$t('saved_successfully', ['Settings']))
//         resolve()
//       }, settings)
//     })
//   },
// }

// export default {
//   namespaced: true,
//   state: getDefaultState,
//   getters,
//   mutations,
//   actions,
// }
