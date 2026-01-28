import { set } from 'vue'
import { cloneDeep } from 'lodash'
import Util from '@/util/setupUtil'
import util from '@/util/util'
import Rpc from '@/util/Rpc'

const getDefaultState = () => ({
  editCallback: null,
  mailSender: {},
  networkSetting: null,
  systemSetting: null,
  eventSettings: null,
  templateParameters: null,
  defaultEmailSettings: null,
  classFieldsData: null,
  deviceTemperatureInfo: '',
  radiusLogsInfo: null,
  enabledWanInterfaces: [],
  uriSettings: null,
  systemTimeZones: [],
  shieldSettings: null,
  languageSettings: null,
  accessRuleSshEnabled: false,
  adminSetting: null,
  googleSettings: null,
  isGoogleDriveConnected: false,
  systemLogs: {}, // system logs stored by logName
  certificatesInformation: null,
  rootCertificates: null,
  serverCertificateVerification: null,
  serverCertificates: null,
  publicUrl: null,
})

const getters = {
  publicUrl: state => state.publicUrl,
  mailSender: state => state.mailSender || {},
  languageSettings: state => state.languageSettings,
  networkSetting: state => state.networkSetting || [],
  interfaces: state => state?.networkSetting?.interfaces || [],
  interface: state => device => {
    return state.networkSetting?.interfaces?.find(intf => intf.device === device)
  },
  systemSetting: state => state.systemSetting || {},
  eventSettings: state => state.eventSettings || {},
  templateParameters: state => state.templateParameters || [],
  defaultEmailSettings: state => state.defaultEmailSettings || {},
  classFieldsData: state => state.classFieldsData || {},
  deviceTemperatureInfo: state => state.deviceTemperatureInfo || '',
  users: state => state.users || [],
  timeZoneOffset: state => state.timeZoneOffset || 0,
  radiusLogsInfo: state => state.radiusLogsInfo || '',
  systemTimeZones: state => state.systemTimeZones || [],
  enabledWanInterfaces: state => state.enabledWanInterfaces || [],
  staticRoutes: state => state?.networkSetting?.staticRoutes || [],
  dnsSettings: state => state?.networkSetting?.dnsSettings || {},
  uriSettings: state => state?.uriSettings || {},
  /**
   * Check expert mode is enabled via RPC.
   * Avoids using Rpc.directData method by getting the value directly from window.rpc.
   */
  isExpertMode: () => window?.rpc?.isExpertMode || false,
  dynamicRoutingSettings: state => state?.networkSetting?.dynamicRoutingSettings || {},
  shieldSettings: state => state?.shieldSettings || {},
  accessRuleSshEnabled: state => state.accessRuleSshEnabled,
  adminSetting: state => state.adminSetting || {},
  googleSettings: state => state.googleSettings || {},
  isGoogleDriveConnected: state => state.isGoogleDriveConnected || false,
  /**
   * Get logs for a given log.
   * Usage: getters.getLogs('uvm')
   */
  getLogsByName: state => logName => state.systemLogs[logName] || null,

  /* Retrieves the certificates information from the state. */
  certificatesInformation: state => state.certificatesInformation || {},
  /* Retrieves the list of root certificates from the state. */
  rootCertificates: state => state.rootCertificates || [],
  /* Retrieves the server certificate verification from the state. */
  serverCertificateVerification: state => state.serverCertificateVerification || [],
  /* Retrieves the server certificates from the state. */
  serverCertificates: state => state.serverCertificates || [],
}

const mutations = {
  setEditCallback(state, cb) {
    state.editCallback = cb
  },
  SET_PUBLIC_URL: (state, value) => set(state, 'publicUrl', value),
  SET_MAIL_SENDER: (state, value) => set(state, 'mailSender', value),
  SET_INTERFACES: (state, value) => set(state.networkSetting, 'interfaces', value),
  SET_NETWORK_SETTINGS: (state, value) => set(state, 'networkSetting', value),
  SET_SYSTEM_SETTINGS: (state, value) => set(state, 'systemSetting', value),
  SET_EVENT_SETTINGS: (state, value) => set(state, 'eventSettings', value),
  SET_TEMPLATE_PARAMETERS: (state, value) => set(state, 'templateParameters', value),
  SET_DEFAULT_EMAIL_SETTINGS: (state, value) => set(state, 'defaultEmailSettings', value),
  SET_CLASS_FIELDS_DATA: (state, value) => set(state, 'classFieldsData', value),
  SET_USERS: (state, value) => set(state, 'users', value),
  SET_TIME_ZONE_OFF_SET: (state, value) => set(state, 'timeZoneOffset', value),
  SET_DEVICE_TEMP_INFO: (state, value) => set(state, 'deviceTemperatureInfo', value),
  SET_RADIUS_LOGS: (state, value) => set(state, 'radiusLogsInfo', value),
  SET_SYSTEM_TIMEZONES: (state, value) => set(state, 'systemTimeZones', value),
  SET_ENABLED_WAN_INTERFACES: (state, value) => set(state, 'enabledWanInterfaces', value),
  SET_URI_SETTINGS: (state, value) => set(state, 'uriSettings', value),
  SET_SHIELD_SETTINGS: (state, value) => set(state, 'shieldSettings', value),
  SET_LANGUAGE_SETTINGS: (state, value) => set(state, 'languageSettings', value),
  SET_ACCESS_RULE_SSH_ENABLED: (state, value) => set(state, 'accessRuleSshEnabled', value),
  SET_ADMIN_SETTINGS: (state, value) => set(state, 'adminSetting', value),
  SET_GOOGLE_SETTINGS: (state, value) => set(state, 'googleSettings', value),
  SET_IS_GOOGLE_DRIVE_CONNECTED: (state, value) => set(state, 'isGoogleDriveConnected', value),
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
  SET_CERTIFICATES_INFORMATION: (state, value) => set(state, 'certificatesInformation', value),
  /* Set Root Certificates */
  SET_ROOT_CERTIFICATES: (state, value) => set(state, 'rootCertificates', value),
  SET_SERVER_CERTIFICATE_VERIFICATION: (state, value) => set(state, 'serverCertificateVerification', value),
  SET_SERVER_CERTIFICATES: (state, value) => set(state, 'serverCertificates', value),
}

const actions = {
  async getPublicUrl({ commit }, refetch) {
    try {
      if (!refetch) {
        return
      }
      const data = await window.rpc.UvmContext.networkManager().getPublicUrl()
      commit('SET_PUBLIC_URL', data)
    } catch (err) {
      Util.handleException(err)
    }
  },

  async getMailSender({ state, commit }, refetch) {
    try {
      if (state.mailSender && !refetch) {
        return
      }
      const data = await window.rpc.UvmContext.mailSender().getSettingsV2()
      commit('SET_MAIL_SENDER', data)
    } catch (err) {
      Util.handleException(err)
    }
  },

  async setMailSender({ dispatch }, emailServerSettings) {
    try {
      const apiMethod = Rpc.asyncPromise('rpc.UvmContext.mailSender().setSettingsV2', emailServerSettings)
      const result = await apiMethod()
      if (result?.code && result?.message) {
        Util.handleException(result.message)
        return { success: false, message: result.message.slice(0, 100) }
      }
      // fetch updated settings after successful save
      await dispatch('getMailSender', true)
      return { success: true }
    } catch (err) {
      Util.handleException(err)
      return { success: false, message: err?.toString()?.slice(0, 100) || 'Unknown error' }
    }
  },

  async getLanguageSettings({ commit }) {
    if (!window.rpc || !window.rpc.languageManager) {
      return
    }
    try {
      const data = await window.rpc.languageManager.getLanguageSettings()
      commit('SET_LANGUAGE_SETTINGS', data)
    } catch (err) {
      Util.handleException(err)
    }
  },

  async getInterfaces({ commit }) {
    try {
      const data = await window.rpc.networkManager.getNetworkSettingsV2().interfaces
      commit('SET_INTERFACES', await data)
    } catch (err) {
      Util.handleException(err)
    }
  },

  async getNetworkSettings({ state, commit, dispatch }, refetch) {
    try {
      if (state.networkSetting && !refetch) {
        return
      }
      const data = await window.rpc.networkManager.getNetworkSettingsV2()
      commit('SET_NETWORK_SETTINGS', data)
      dispatch('setAccessRuleSshEnabled')
    } catch (err) {
      Util.handleException(err)
    }
  },

  /* get system settings configuration */
  getSystemSettings({ state, commit }, refetch) {
    try {
      if (state.systemSetting && !refetch) {
        return
      }
      const data = window.rpc.systemManager.getSystemSettingsV2()
      commit('SET_SYSTEM_SETTINGS', data)
      return { success: true, message: null, data } //  success
    } catch (err) {
      Util.handleException(err)
    }
  },

  /* get event settings configuration */
  getEventSettings({ state, commit }, refetch) {
    try {
      if (state.eventSettings && !refetch) {
        return
      }
      const data = window.rpc.eventManager.getSettingsV2()
      commit('SET_EVENT_SETTINGS', data)
      return { success: true, message: null, data } //  success
    } catch (err) {
      Util.handleException(err)
    }
  },

  /* Get the class fields condition data for event rules */
  getClassFieldsData({ commit }) {
    try {
      const data = window.rpc.eventManager.getClassFields()
      commit('SET_CLASS_FIELDS_DATA', data)
      return { success: true, message: null, data } //  success
    } catch (err) {
      Util.handleException(err)
    }
  },

  /* get template parameters */
  getTemplateParameters({ state, commit }, refetch) {
    try {
      if (state.templateParameters && !refetch) {
        return
      }
      const data = window.rpc.eventManager.getTemplateParameters()
      commit('SET_TEMPLATE_PARAMETERS', data)
      return { success: true, message: null, data } //  success
    } catch (err) {
      Util.handleException(err)
    }
  },

  /* get default email settings */
  getDefaultEmailSettings({ state, commit }, refetch) {
    try {
      if (state.defaultEmailSettings && !refetch) {
        return
      }
      const data = window.rpc.eventManager.defaultEmailSettingsV2()
      commit('SET_DEFAULT_EMAIL_SETTINGS', data)
      return { success: true, message: null, data } //  success
    } catch (err) {
      Util.handleException(err)
    }
  },

  /** get timeZoneOffset */
  getTimeZoneOffSet({ commit }) {
    try {
      const data = window.rpc.timeZoneOffset
      commit('SET_TIME_ZONE_OFF_SET', data)
      return { success: true, message: null, data } //  success
    } catch (err) {
      Util.handleException(err)
    }
  },

  /* get users configuration */
  getUsers({ state, commit }, refetch) {
    try {
      if (state.users && !refetch) {
        return
      }
      const result = window.rpc.UvmContext.localDirectory()
      const data = result.getUsersV2()
      commit('SET_USERS', data)
      return { success: true, message: null, data } //  success
    } catch (err) {
      Util.handleException(err)
    }
  },

  /* get device temperature information configuration */
  async getDeviceTemperatureInfo({ commit }) {
    try {
      const data = await window.rpc.systemManager.getDeviceTemperatureInfo()
      commit('SET_DEVICE_TEMP_INFO', data)
      return { success: true, message: null, data } //  success
    } catch (err) {
      Util.handleException(err)
    }
  },

  /** get radius logs information */
  async getRadiusLogFile({ commit }) {
    try {
      const data = await window.rpc.UvmContext.localDirectory().getRadiusLogFile()
      commit('SET_RADIUS_LOGS', data)
      return { success: true, message: null, data }
    } catch (err) {
      Util.handleException(err)
    }
  },

  /*
   * Retrieve system timezones and transform them into the list item format
   * required by Vuntangle components.
   */
  getSystemTimeZones({ commit }) {
    try {
      const timeZones = []
      const systemTimeZones = window.rpc.systemManager.getTimeZones()
      const jsonStr = systemTimeZones.replace(/'/g, '"')
      const timezonesArray = JSON.parse(jsonStr)

      if (timezonesArray && Array.isArray(timezonesArray)) {
        for (let i = 0; i < timezonesArray.length; i++) {
          const [zone, offset] = timezonesArray[i]

          const tzObject = {
            text: `(${offset}) ${zone}`,
            value: zone,
          }
          timeZones.push(tzObject)
        }
      }
      commit('SET_SYSTEM_TIMEZONES', timeZones)
      return { success: true, message: null, timeZones }
    } catch (err) {
      Util.handleException(err)
    }
  },

  /*
   * get list of all enabled interfaces
   * it is used in the hostname for listing interface list
   */
  async getEnabledInterfaces({ commit }) {
    try {
      const enabledWanname = ['Default']
      const interfaces = await window.rpc.networkManager.getEnabledInterfaces()
      interfaces.list.forEach(intf => {
        if (intf.isWan) {
          enabledWanname.push(intf.name)
        }
      })
      commit('SET_ENABLED_WAN_INTERFACES', enabledWanname)
      return { success: true, message: null, enabledWanname } //  success
    } catch (err) {
      Util.handleException(err)
    }
  },

  /* get Admin settings configuration */
  async getAdminSettings({ state, commit }, refetch) {
    try {
      if (state.adminSetting && !refetch) {
        return
      }
      const data = await window.rpc.adminManager.getSettingsV2()
      commit('SET_ADMIN_SETTINGS', data)
      return { success: true, message: null, data } //  success
    } catch (err) {
      Util.handleException(err)
    }
  },

  /* get Google Settings configuration */
  async getGoogleSettings({ state, commit }, refetch) {
    try {
      if (state.googleSettings && !refetch) {
        return
      }
      const result = Rpc.asyncPromise('rpc.UvmContext.googleManager.getSettings')
      const data = await result()
      commit('SET_GOOGLE_SETTINGS', data)
      return { success: true, message: null, data }
    } catch (err) {
      Util.handleException(err)
    }
  },

  /* check google drive connection status */
  async getIsGoogleDriveConnected({ commit }) {
    try {
      const result = Rpc.asyncPromise('rpc.UvmContext.googleManager.isGoogleDriveConnected')
      const isConnected = await result()
      commit('SET_IS_GOOGLE_DRIVE_CONNECTED', isConnected)
      return { success: true, message: null, isConnected }
    } catch (err) {
      Util.handleException(err)
    }
  },

  /* setUsers will update users regarding configurations */
  setUsersSettings({ dispatch }, usersSettings) {
    try {
      const data = new Promise(resolve => {
        window.rpc.UvmContext.localDirectory().setUsersV2(async (ex, result) => {
          if (ex) {
            Util.handleException(ex)
            return resolve({ success: false, message: ex?.toString()?.slice(0, 100) || 'Unknown error' })
          }

          if (result?.code && result?.message) {
            Util.handleException(result.message)
            return resolve({ success: false, message: result.message.slice(0, 100) })
          }
          // fetch updated settings after successful save
          await dispatch('getUsers', true)
          return resolve({ success: true })
        }, usersSettings)
      })
      return data
    } catch (err) {
      Util.handleException(err)
      return { success: false, message: err?.toString()?.slice(0, 100) || 'Unknown error' }
    }
  },

  /**
   * setSystemSettings will update system regarding configurations
   * @param {object} { dispatch }
   * @param {object} systemSettings
   * @returns {Promise<object>}
   */
  async setSystemSettings({ dispatch }, systemSettings) {
    try {
      const result = await new Promise(resolve => {
        window.rpc.systemManager.setSystemSettingsV2((ex, res) => {
          if (ex) {
            return resolve({
              success: false,
              message: ex?.toString()?.slice(0, 100) || 'Unknown error',
            })
          }
          if (res?.code && res?.message) {
            return resolve({
              success: false,
              message: res.message.slice(0, 100),
            })
          }
          return resolve({ success: true })
        }, systemSettings)
      })

      if (result.success) {
        // fetch updated settings after successful save
        await dispatch('getSystemSettings', true)
      } else {
        Util.handleException(result.message)
      }

      return result
    } catch (err) {
      Util.handleException(err)
      return {
        success: false,
        message: err?.toString()?.slice(0, 100) || 'Unknown error',
      }
    }
  },

  /**
   * setSystemSettings will update system regarding configurations
   * @param {object} { dispatch }
   * @param {object} systemSettings
   * @param {boolean} dirtyRadiusFields
   * @returns {Promise<object>}
   */
  async setSystemSettingsWithRadius({ dispatch }, { systemSettings, dirtyRadiusFields }) {
    try {
      const result = await new Promise(resolve => {
        window.rpc.systemManager.setSystemSettingsV2(
          (ex, res) => {
            if (ex) {
              return resolve({
                success: false,
                message: ex?.toString()?.slice(0, 100) || 'Unknown error',
              })
            }
            if (res?.code && res?.message) {
              return resolve({
                success: false,
                message: res.message.slice(0, 100),
              })
            }
            return resolve({ success: true })
          },
          systemSettings,
          dirtyRadiusFields,
        )
      })

      if (result.success) {
        // fetch updated settings after successful save
        await dispatch('getSystemSettings', true)
      } else {
        Util.handleException(result.message)
      }

      return result
    } catch (err) {
      Util.handleException(err)
      return {
        success: false,
        message: err?.toString()?.slice(0, 100) || 'Unknown error',
      }
    }
  },
  /**
   * Persists the updated list of network interfaces to the backend using RPC.
   * This action sends a payload to the backend containing all network interfaces
   * and a required Java class identifier. It handles errors from both RPC exceptions
   * and response objects with error codes. On success, it commits the updated interfaces
   * to the Vuex state.
   */
  setNetworkSettingV2({ dispatch }, payload) {
    try {
      payload.javaClass = 'com.untangle.uvm.network.generic.NetworkSettingsGeneric'
      const data = new Promise(resolve => {
        window.rpc.networkManager.setNetworkSettingsV2((ex, result) => {
          if (ex) {
            Util.handleException(ex)
            return resolve({ success: false, message: ex?.toString()?.slice(0, 100) || 'Unknown error' })
          }
          if (result?.code && result?.message) {
            Util.handleException(result.message)
            return resolve({
              success: false,
              message: result.message.slice(0, 100),
            })
          }
          dispatch('getNetworkSettings', true)
          return resolve({ success: true })
        }, payload)
      })
      return data
    } catch (err) {
      Util.handleException(err)
    }
  },

  /**
   * Dispatches admin settings to the backend via RPC.
   * This action sends the provided admin settings to the 'adminManager' service.
   * returning a success or failure status along with an error message if applicable.
   * Upon successful saving, it triggers a refetch of the admin settings to ensure
   * @param {object} { dispatch } - Vuex action context for dispatching other actions.
   * @param {object} adminettings - The administration settings object to be saved.
   * @returns {Promise<object>} A promise that resolves with an object indicating
   */
  setAdminSettings({ dispatch }, adminettings) {
    try {
      const data = new Promise(resolve => {
        window.rpc.adminManager.setSettingsV2(async (ex, result) => {
          if (ex) {
            Util.handleException(ex)
            return resolve({ success: false, message: ex?.toString()?.slice(0, 100) || 'Unknown error' })
          }

          if (result?.code && result?.message) {
            Util.handleException(result.message)
            return resolve({ success: false, message: result.message.slice(0, 100) })
          }
          // fetch updated settings after successful save
          await dispatch('getAdminSettings', true)
          return resolve({ success: true })
        }, adminettings)
      })
      return data
    } catch (err) {
      Util.handleException(err)
      return { success: false, message: err?.toString()?.slice(0, 100) || 'Unknown error' }
    }
  },

  /** Saves Event Settings */
  async setEventSettings({ dispatch }, eventSettings) {
    try {
      const result = await new Promise(resolve => {
        window.rpc.eventManager.setSettingsV2(async (ex, res) => {
          if (ex) return resolve({ success: false, message: ex?.toString()?.slice(0, 100) || 'Unknown error' })
          if (res?.code && res?.message) return resolve({ success: false, message: res.message.slice(0, 100) })

          // Fetch updated settings after successful save
          await dispatch('getEventSettings', true)
          return resolve({ success: true })
        }, eventSettings)
      })

      // Handle RPC-level errors (optional logging)
      if (!result.success) {
        Util.handleException(result.message)
      }

      return result
    } catch (err) {
      Util.handleException(err)
      return { success: false, message: err?.toString()?.slice(0, 100) || 'Unknown error' }
    }
  },

  /**
   * Dispatches google settings to the backend via RPC.
   * @param {object} { dispatch } - Vuex action context for dispatching other actions.
   * @param {object} googleSettings - The googleSettings settings object to be saved.
   * @returns {object} An object indicating success status with message
   */
  async setGoogleSettings({ dispatch }, googleSettings) {
    try {
      const apiMethod = Rpc.asyncPromise('rpc.UvmContext.googleManager.setSettings', googleSettings)
      const result = await apiMethod()
      if (result?.code && result?.message) {
        Util.handleException(result.message)
        return { success: false, message: result.message.slice(0, 100) }
      }
      // fetch updated settings after successful save
      await dispatch('getGoogleSettings', true)
      await dispatch('getIsGoogleDriveConnected')
      return { success: true }
    } catch (err) {
      Util.handleException(err)
      return { success: false, message: err?.toString()?.slice(0, 100) || 'Unknown error' }
    }
  },

  /**
   * Synchronize the system time using the NTP (Network Time Protocol) service
   */
  async doForceTimeSync() {
    try {
      return await new Promise(resolve => {
        window.rpc.UvmContext.forceTimeSync((ex, result) => {
          if (ex) {
            Util.handleException(ex)
            return resolve({ success: false, message: ex?.toString()?.slice(0, 100) || 'Unknown error' })
          }
          if (result?.code && result?.message) {
            Util.handleException(result.message)
            return resolve({
              success: false,
              message: result.message.slice(0, 100),
            })
          }
          return resolve({ success: true })
        })
      })
    } catch (err) {
      Util.handleException(err)
      return { success: false, message: err?.toString()?.slice(0, 100) || 'Unknown error' }
    }
  },

  /* factory reset */
  factoryReset() {
    try {
      window.rpc.UvmContext.configManager().doFactoryReset()
      return { success: true }
    } catch (err) {
      Util.handleException(err)
      return { success: false, message: err?.toString()?.slice(0, 100) || 'Unknown error' }
    }
  },

  /* reboot */
  reboot() {
    try {
      window.rpc.UvmContext.rebootBox()
      return { success: true }
    } catch (err) {
      Util.handleException(err)
      return { success: false, message: err?.toString()?.slice(0, 100) || 'Unknown error' }
    }
  },

  /* shutdown */
  shutdown() {
    try {
      window.rpc.UvmContext.shutdownBox()
      return { success: true }
    } catch (err) {
      Util.handleException(err)
      return { success: false, message: err?.toString()?.slice(0, 100) || 'Unknown error' }
    }
  },

  /* Get Certificate  */

  async getRootCertificateInformation({ state, commit }, refetch) {
    if (state.certificatesInformation && !refetch) {
      return
    }
    try {
      const data = await window.rpc.UvmContext.certificateManager().getRootCertificateInformation()
      commit('SET_CERTIFICATES_INFORMATION', data)
      return { success: true, data }
    } catch (err) {
      Util.handleException(err)
      return { success: false, message: err?.toString()?.slice(0, 100) || 'Unknown error' }
    }
  },

  /* Get Root Certificate List */
  async getRootCertificateList({ state, commit }, refetch) {
    if (state.rootCertificates && !refetch) {
      return
    }
    try {
      const data = await window.rpc.UvmContext.certificateManager().getRootCertificateListV2()
      commit('SET_ROOT_CERTIFICATES', data)
      return { success: true, data }
    } catch (err) {
      Util.handleException(err)
      return { success: false, message: err?.toString()?.slice(0, 100) || 'Unknown error' }
    }
  },

  /* Get ServerCertificateVerification details */
  async getServerCertificateVerification({ state, commit }, refetch) {
    if (state.serverCertificateVerification && !refetch) {
      return
    }
    try {
      const data = await window.rpc.UvmContext.certificateManager().validateActiveInspectorCertificates()
      commit('SET_SERVER_CERTIFICATE_VERIFICATION', data)
      return { success: true, data }
    } catch (err) {
      Util.handleException(err)
      return { success: false, message: err?.toString()?.slice(0, 100) || 'Unknown error' }
    }
  },

  /* Get Server Certificate List */
  async getServerCertificateList({ state, commit }, refetch) {
    if (state.serverCertificates && !refetch) {
      return
    }
    try {
      const data = await window.rpc.UvmContext.certificateManager().getServerCertificateListV2()
      commit('SET_SERVER_CERTIFICATES', data)
      return { success: true, data }
    } catch (err) {
      Util.handleException(err)
      return { success: false, message: err?.toString()?.slice(0, 100) || 'Unknown error' }
    }
  },

  /** update all interfaces */
  async setInterfaces({ state, dispatch }, interfaces) {
    const networkSettings = cloneDeep(state.networkSetting)

    interfaces.forEach(intf => {
      const existing = networkSettings.interfaces.find(i => i.interfaceId === intf.interfaceId)
      if (existing) {
        Object.assign(existing, intf) // update existing
      } else {
        networkSettings.interfaces.push(intf) // add new
      }
    })
    // Save updated interface list
    return await dispatch('setNetworkSettingV2', networkSettings)
  },

  /* Delete selected Interface and update all interfaces */
  async deleteInterface({ state, dispatch }, intf) {
    try {
      const networkSettings = cloneDeep(state.networkSetting)
      const index = networkSettings.interfaces.findIndex(i => i.interfaceId === intf.interfaceId)

      /* Selected interfaces will be removed from the list of interfaces */
      if (index >= 0) {
        networkSettings.interfaces.splice(index, 1)
      }
      return await dispatch('setNetworkSettingV2', networkSettings)
    } catch (err) {
      Util.handleException(err)
      return false
    }
  },

  // fetch uri settings
  async getUriSettings({ state, commit }, refetch) {
    try {
      if (state.uriSettings && !refetch) {
        return
      }
      const data = await window.rpc.uriManager.getSettings()
      commit('SET_URI_SETTINGS', data)
    } catch (err) {
      Util.handleException(err)
      return false
    }
  },

  // Fetch Shield Settings
  async getShieldSettings({ state, commit }, refetch) {
    try {
      if (state.shieldSettings && !refetch) {
        return
      }
      const data = await window.rpc.appManager.app('shield').getSettingsV2()
      commit('SET_SHIELD_SETTINGS', data)
    } catch (err) {
      Util.handleException(err)
      return false
    }
  },

  /* setShieldSettings will update system regarding configurations */
  async setShieldSettings({ dispatch }, shieldSettings) {
    try {
      const result = await new Promise(resolve => {
        window.rpc.appManager.app('shield').setSettingsV2(async (ex, res) => {
          if (ex) return resolve({ success: false, message: ex?.toString()?.slice(0, 100) || 'Unknown error' })
          if (res?.code && res?.message) return resolve({ success: false, message: res.message.slice(0, 100) })

          // Fetch updated settings after successful save
          await dispatch('getShieldSettings', true)
          return resolve({ success: true })
        }, shieldSettings)
      })

      // Handle RPC-level errors (optional logging)
      if (!result.success) {
        Util.handleException(result.message)
      }

      return result
    } catch (err) {
      Util.handleException(err)
      return { success: false, message: err?.toString()?.slice(0, 100) || 'Unknown error' }
    }
  },

  setAccessRuleSshEnabled({ state, commit }) {
    const accessRules = state?.networkSetting?.access_rules || []
    commit('SET_ACCESS_RULE_SSH_ENABLED', util.getRuleEnabledStatus(accessRules, 'Allow SSH'))
  },

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
