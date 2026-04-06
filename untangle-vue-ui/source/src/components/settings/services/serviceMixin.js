import { mapGetters } from 'vuex'
import uris from '@/util/uris'
export default {
  data() {
    return {
      isLicensed: undefined,
      manageLicenseUri: undefined,
      appManager: null,
      toggling: false,
    }
  },

  computed: {
    ...mapGetters('apps', ['getServiceAppStatus']),

    powerState: ({ appManager, getServiceAppStatus, toggling }) => {
      const vuexPowerState = getServiceAppStatus({
        appManager,
      })

      return {
        ...vuexPowerState,
        power: toggling,
      }
    },
  },

  async created() {
    this.checkLicense()
    this.getManageLicenseUri()
    const app = await this.$store.dispatch('apps/getApp', { appName: this.licenseNodeName })
    this.appManager = app || null
  },

  methods: {
    /**
     * Toggle app state. Starts or stops the app based on the 'enabled' parameter.
     * @param {boolean} enabled - Target state (true = starting, false = stopping)
     */
    async toggleAppState(enabled) {
      if (!this.appManager) return

      this.toggling = true
      try {
        const rpcMethod = enabled ? 'start' : 'stop'

        await new Promise((resolve, reject) => {
          this.appManager[rpcMethod]((ex, res) => {
            if (ex || res?.code) {
              reject(ex || new Error(res?.message || `Failed to ${rpcMethod} app`))
            } else {
              resolve(res)
            }
          })
        })
      } finally {
        this.toggling = false
      }
    },
    /**
     * PROP: is-licensed
     * Checks for TP license status
     */
    async checkLicense() {
      if (!this.licenseNodeName) return
      this.isLicensed = await this.$store.dispatch('apps/checkLicenseStatus', this.licenseNodeName)
    },

    /**
     * PROP: manage-license-uri
     * Fetches the URI for license management
     */
    async getManageLicenseUri() {
      this.manageLicenseUri = await this.$store.dispatch('apps/fetchManageLicenseUri', uris.list.subscriptions)
    },

    /**
     * Check if a specific app's license is valid
     * @param {String} appName - The app name to check
     * @returns {Boolean} true if license is valid, false otherwise
     */
    isAppLicenseValid(appName) {
      return this.$store.dispatch('apps/checkAppLicense', appName)
    },
    /**
     * Check if a daemon is running
     * @param {String} daemonName - The daemon name to check
     * @returns {Boolean} true if daemon is running, false otherwise
     */
    isDaemonRunning(daemonName) {
      return this.$store.dispatch('apps/checkDaemonStatus', daemonName)
    },
  },
}
