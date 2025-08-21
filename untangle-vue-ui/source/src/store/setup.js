import api from '@/plugins/api'
import router from '@/router'
import Util from '@/util/setupUtil'

const state = () => ({
  steps: [],
  stepper: ['License', 'System', 'Network', 'Internet', 'Interface', 'Autoupgrades', 'Complete'],
  currentStep: '',
  previousStep: '',
  system: {
    newPassword: '',
    newPasswordConfirm: '',
    installType: '',
  },
  wizardSettings: {
    steps: [],
  },
  isLoading: false,
  loadingMessage: 'Loading...',
})

const getters = {
  stepper: state => state.stepper || [],
  steps: state => state.steps,
  currentStep: state => state.currentStep,
  previousStep: state => state.previousStep,
  newPassword: state => state.system.newPassword,
  newPasswordConfirm: state => state.system.newPasswordConfirm,
  installType: state => state.system.installType,
  wizardSettings: state => state.wizardSettings.steps,
  wizardSteps: state => state.wizardSettings.steps,
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

  // Refactored to handle setting the wizard steps based on conditions
  async initializeWizard({ commit }) {
    try {
      const rpc = await Util.setRpcJsonrpc('setup')
      let steps = []

      if (!rpc.wizardSettings.steps || rpc.wizardSettings.steps.length === 0) {
        if (!rpc.remote) {
          steps = ['Welcome', 'License', 'ServerSettings', 'Interfaces', 'Internet', 'InternalNetwork']

          if (rpc.isWirelessInterface) {
            steps.push('Wireless')
          }

          steps.push('AutoUpgrades', 'Complete')
        } else {
          steps = ['Welcome', 'Internet', 'Complete']
        }

        rpc.wizardSettings.steps = steps
      } else {
        steps = rpc.wizardSettings.steps
      }
      commit('SET_SHOW_STEP', steps[0])
      commit('SET_SHOW_PREVIOUS_STEP', steps[0])
      commit('SET_WIZARDSETTINGS', { steps })
      return rpc
    } catch (error) {
      console.error('Error initializing wizard:', error)
    }
  },

  setShowStep({ commit }, value) {
    commit('SET_SHOW_STEP', value) // Commit mutation to set currentStep
  },
  setShowPreviousStep({ commit }, value) {
    commit('SET_SHOW_PREVIOUS_STEP', value) // Commit mutation to set currentStep
  },
  setNewPassword({ commit }, password) {
    commit('SET_NEW_PASSWORD', password)
  },
  setNewPasswordConfirm({ commit }, passwordConfirm) {
    commit('SET_NEW_PASSWORD_CONFIRM', passwordConfirm)
  },
  setInstallType({ commit }, installType) {
    commit('SET_INSTALLTYPE', installType)
  },
  setStep({ commit }, steps) {
    commit('SET_STEP', steps)
  },

  // Actions for Loader
  showLoader({ commit }, message) {
    commit('SHOW_LOADER', message)
  },
  hideLoader({ commit }) {
    commit('HIDE_LOADER')
  },
}
const mutations = {
  SET_SHOW_STEP(state, value) {
    state.currentStep = value // Mutate currentStep
  },
  SET_SHOW_PREVIOUS_STEP(state, value) {
    state.previousStep = value // Mutate currentStep
  },
  SET_NEW_PASSWORD(state, password) {
    state.system.newPassword = password
  },
  SET_NEW_PASSWORD_CONFIRM(state, passwordConfirm) {
    state.system.newPasswordConfirm = passwordConfirm
  },
  SET_INSTALLTYPE(state, installType) {
    state.system.installType = installType
  },
  RESET_SYSTEM(state) {
    state.system = {
      newPassword: '',
      newPasswordConfirm: '',
      installType: '',
    }
  },
  SET_STEP(state, steps) {
    state.wizardSettings.steps = steps // Update the wizardSettings.steps array in state
  },

  SET_WIZARDSETTINGS(state, { steps }) {
    state.wizardSettings.steps = steps
  },
  // For Loader
  SHOW_LOADER(state, message) {
    state.isLoading = true
    state.loadingMessage = message || 'Loading...' // Default message
  },
  HIDE_LOADER(state) {
    state.isLoading = false
  },
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
}
