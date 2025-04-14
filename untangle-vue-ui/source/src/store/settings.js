import { set } from 'vue'
// import api from '@/plugins/api'
import Util from '@/util/setupUtil'
const getDefaultState = () => ({
  settings: null,
})
const getters = {
  settings: state => state.settings,
  interfaces: state => state.settings?.network?.interfaces || [],
  interface: state => device => {
    return state.settings.network.interfaces.find(intf => intf.device === device)
  },
}
const mutations = {
  SET_INTERFACES: (state, value) => set(state.settings.network, 'interfaces', value),
}
const actions = {
  async getInterfaces({ commit }) {
    try {
      console.log('call for get Interfaces')
      const rpc = await Util.setRpcJsonrpc('admin')
      console.log('rpc :', rpc)
      const data = rpc.networkManager.getNetworkSettings().interfaces.list
      console.log('interfaces data:', data)
      commit('SET_INTERFACES', data)
    } catch (err) {
      console.error('getInterfaces error:', err)
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
