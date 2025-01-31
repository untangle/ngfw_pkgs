import api from '@/plugins/api'
import router from '@/router'

const state = () => ({
  steps: [],
  currentStep: 'wizard',
  previousStep: 'wizard',
})

const getters = {
  steps: (state, getters, rootState, rootGetters) => {
    const steps = ['license', 'system', 'wan']

    const interfaces = rootGetters['settings/interfaces']
    const lteStep = interfaces.findIndex(intf => intf.type === 'WWAN')
    const wifiStep = interfaces.findIndex(intf => intf.type === 'WIFI')

    if (lteStep >= 0) steps.push('lte')
    if (wifiStep >= 0) steps.push('wifi')

    return steps
  },
  currentStep: state => state.currentStep, // Getter for currentStep (showStep)
  previousStep: state => state.previousStep, // Getter for currentStep (showStep)
}

const actions = {
  async getStatus({ commit }) {
    const status = await api.get('/api/settings/system/setupWizard')
    commit('settings/SET_SETUP_WIZARD', status, { root: true })
    return status
  },
  async setStatus({ commit, getters, rootGetters }, currentStep) {
    const steps = getters.steps
    const completedStep = rootGetters['settings/setupWizard'].step
    const nextStep = steps[steps.indexOf(currentStep) + 1]
    if (!completedStep || currentStep === completedStep) {
      const completed = steps[steps.length - 1] === currentStep
      const status = {
        completed,
      }
      // the step must not be included in config if status is completed
      if (!completed) {
        status.step = nextStep
      }
      const response = await api.post('/api/settings/system/setupWizard', status)
      if (response.result) {
        commit('settings/SET_SETUP_WIZARD', status, { root: true })
        if (completed) {
          router.push('/')
        } else {
          return nextStep
        }
      }
    } else {
      return nextStep
    }
  },
  async resetStatus({ state, commit }) {
    const status = { completed: false }
    const response = await api.post('/api/settings/system/setupWizard', status)
    if (response.result) {
      commit('settings/SET_SETUP_WIZARD', status, { root: true })
      return state.steps[0]
    }
  },
  setShowStep({ commit }, value) {
    commit('SET_SHOW_STEP', value) // Commit mutation to set currentStep
  },
  setShowPreviousStep({ commit }, value) {
    commit('SET_SHOW_PREVIOUS_STEP', value) // Commit mutation to set currentStep
  },
}
const mutations = {
  SET_SHOW_STEP(state, value) {
    console.log('Setting showStep to:', value) // Log the value being set
    state.currentStep = value // Mutate currentStep
  },
  SET_SHOW_PREVIOUS_STEP(state, value) {
    console.log('Setting  previous show Step to:', value) // Log the value being set
    state.previousStep = value // Mutate currentStep
  },
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
}
