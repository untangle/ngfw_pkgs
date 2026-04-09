import uris from '@/util/uris'
import { EVENT_ACTIONS } from '@/constants/actions'
import { sendEvent } from '@/utils/event'

export default {
  inject: ['embedded'],

  data() {
    return {
      isLicensed: undefined,
      manageLicenseUri: undefined,
    }
  },

  computed: {
    // Get the apps view for the selected policy from the store
    appsViewByPolicy: ({ $store }) => $store.getters['apps/getAppsViewByPolicy'](1),

    // Determine if the app is currently installed based on the apps view for the selected policy
    isInstalled() {
      return this.appsViewByPolicy?.instances?.some(i => i.appName === this.serviceName) ?? undefined
    },
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

    /** Installs the dynamic-blocklists app */
    async onInstallService() {
      this.$store.commit('SET_LOADER', true)
      try {
        await this.$store.dispatch('apps/installApp', { appName: this.serviceName })
        await this.$store.dispatch('apps/loadAppData', { appName: this.licenseNodeName })
        await this.checkLicense()
      } finally {
        this.$store.commit('SET_LOADER', false)
      }
    },

    /**
     * Handles the removal of the service app. It first sets a loader state to true, then finds the app instance
     * corresponding to the serviceName in the current policy's apps view. It dispatches an action to destroy the app instance,
     * and if the component is embedded, it sends an event to the parent indicating that the app has been removed. Finally, it sets the loader state back to false.
     */
    async onRemoveService() {
      this.$store.commit('SET_LOADER', true)
      try {
        const instance = this.appsViewByPolicy?.instances?.find(i => i.appName === this.serviceName)
        await this.$store.dispatch('apps/destroyApp', {
          instanceId: instance?.id,
          policyId: 1,
        })
        if (this.embedded) {
          // If embedded, just send event to parent
          // TODO Remove this once all apps are migrated to Vue UI and Parent Layout is changed
          sendEvent({ type: EVENT_ACTIONS.REMOVE_APP, appName: this.serviceName })
        }
      } finally {
        this.$store.commit('SET_LOADER', false)
      }
    },
  },
}
