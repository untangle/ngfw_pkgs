import vuntangle from '@/plugins/vuntangle'

const getDefaultState = () => ({
  setupWizardData: null, // Holds the wizard data (could be steps, configurations, etc.)
  currentStep: 1, // Keeps track of the current step
})

const getters = {
  setupWizardData: state => state.setupWizardData,
  currentStep: state => state.currentStep,
  currentStepData: state => stepNumber => {
    // Assuming you have a specific data structure for each step
    return state.setupWizardData ? state.setupWizardData[stepNumber] : null
  },
}

const mutations = {
  RESET: state => Object.assign(state, getDefaultState()),

  SET_SETUP_WIZARD_DATA: (state, value) => {
    state.setupWizardData = value
  },

  SET_CURRENT_STEP: (state, stepNumber) => {
    state.currentStep = stepNumber
  },

  UPDATE_STEP_DATA: (state, { stepNumber, data }) => {
    if (state.setupWizardData && state.setupWizardData[stepNumber]) {
      state.setupWizardData[stepNumber] = data
    }
  },
}

const actions = {
  async fetchSetupWizardData({ commit, state }) {
    if (state.setupWizardData !== null) return
    commit('SET_FETCHING', true, { root: true })
    const data = await window.rpc.setupWizard.getWizardData() // Replace with your API call
    commit('SET_FETCHING', false, { root: true })
    if (data) {
      commit('SET_SETUP_WIZARD_DATA', data)
    }
  },

  saveSetupWizardData({ commit }, { stepNumber, data }) {
    return new Promise((resolve, reject) => {
      commit('SET_FETCHING', true, { root: true })
      window.rpc.setupWizard.saveWizardData(
        (response, exception) => {
          commit('SET_FETCHING', false, { root: true })
          if (exception) {
            vuntangle.toast.add(exception.message, 'error')
            reject(exception)
            return
          }
          commit('UPDATE_STEP_DATA', { stepNumber, data }) // Updates the data for the current step
          vuntangle.toast.add(vuntangle.$t('saved_successfully', ['Wizard Data']))
          resolve()
        },
        { stepNumber, data },
      ) // Send step-specific data
    })
  },

  // Optional action to go to the next step
  nextStep({ commit, state }) {
    const nextStep = state.currentStep + 1
    commit('SET_CURRENT_STEP', nextStep)
  },

  // Optional action to go to the previous step
  previousStep({ commit, state }) {
    const prevStep = state.currentStep - 1
    commit('SET_CURRENT_STEP', prevStep)
  },

  // Optionally reset the wizard
  resetSetupWizard({ commit }) {
    commit('RESET')
  },
}

export default {
  namespaced: true,
  state: getDefaultState,
  getters,
  mutations,
  actions,
}
