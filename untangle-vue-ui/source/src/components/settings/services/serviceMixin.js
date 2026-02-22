import uris from '@/util/uris'
export default {
  data() {
    return {
      isLicensed: undefined,
      manageLicenseUri: undefined,
    }
  },
  created() {
    this.checkLicense()
    this.getManageLicenseUri()
  },
  methods: {
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
