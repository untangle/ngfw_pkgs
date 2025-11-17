import { set } from 'vue'
import Util from '@/util/setupUtil'

const getDefaultState = () => ({
  systemLogs: {}, // system logs stored by logName
})

const getters = {
  /**
   * Get logs for a given log.
   * Usage: getters.getLogs('uvm')
   */
  getLogsByName: state => logName => state.systemLogs[logName] || null,
}

const mutations = {
  /**
   * Dynamically set logs for an app
   * Usage: commit('SET_LOGS', { logName: 'uvm', value: data })
   */
  SET_LOGS(state, { logName, value }) {
    if (!state.systemLogs) {
      set(state, 'systemLogs', {})
    }
    set(state.systemLogs, logName, value)
  },
}

const actions = {
  getLogsByName({ commit, state }, { logName, refetch }) {
    let logs
    try {
      if (state.systemLogs && state.systemLogs[logName] && !refetch) {
        // just return logs from store
        logs = state.systemLogs[logName]
        return { success: true, logs }
      }

      if (logName === 'uvm') {
        logs = window.rpc.systemManager.getUvmLogs()
      }
      commit('SET_LOGS', { logName, value: logs })
      return { success: true, logs }
    } catch (err) {
      Util.handleException(err)
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
