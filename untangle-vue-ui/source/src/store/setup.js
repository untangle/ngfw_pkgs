import api from '@/plugins/api'
import router from '@/router'

const state = () => ({
  steps: [],
  stepper: ['License', 'System', 'Network', 'Internet', 'Interface', 'Autoupgrades', 'Complete'],
  currentStep: 'wizard',
  previousStep: 'wizard',
  system: {
    newPassword: '',
    newPasswordConfirm: '',
    installType: '',
  },
})

const getters = {
  // steps: (state, getters, rootState, rootGetters) => {
  //   const steps = ['license', 'system', 'wan']

  //   const interfaces = rootGetters['settings/interfaces']
  //   const lteStep = interfaces.findIndex(intf => intf.type === 'WWAN')
  //   const wifiStep = interfaces.findIndex(intf => intf.type === 'WIFI')

  //   if (lteStep >= 0) steps.push('lte')
  //   if (wifiStep >= 0) steps.push('wifi')

  //   return steps
  // },
  stepper: state => state.stepper || [],
  steps: state => state.steps, // Getter for steps array
  currentStep: state => state.currentStep, // Getter for currentStep (showStep)
  previousStep: state => state.previousStep, // Getter for currentStep (showStep)
  newPassword: state => state.system.newPassword,
  newPasswordConfirm: state => state.system.newPasswordConfirm,
  installType: state => state.system.installType, // Getter for installType
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
  SET_NEW_PASSWORD(state, password) {
    console.log('Mutation - newPassword:', password) // Log password to check
    state.system.newPassword = password
  },
  SET_NEW_PASSWORD_CONFIRM(state, passwordConfirm) {
    console.log('Mutation - newPasswordConfirm:', passwordConfirm) // Log passwordConfirm to check
    state.system.newPasswordConfirm = passwordConfirm
  },
  SET_INSTALLTYPE(state, installType) {
    console.log('Mutation - installType:', installType)
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
    console.log('Mutation - step:', steps)
    state.step = steps
  },
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
}
