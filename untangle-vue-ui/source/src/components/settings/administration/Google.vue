<template>
  <settings-google
    :settings="settings"
    @google-drive-configure="googleDriveConfigure"
    @google-drive-disconnect="googleDriveDisconnect"
  >
    <template #actions="{ newSettings, isDirty, validate }">
      <u-btn :min-width="null" :disabled="!isDirty" @click="onSaveSettings(newSettings, validate)">{{
        $t('save')
      }}</u-btn>
    </template>
  </settings-google>
</template>

<script>
  import { SettingsGoogle } from 'vuntangle'
  import Rpc from '@/util/Rpc'
  export default {
    components: { SettingsGoogle },

    data() {
      return {
        refreshGoogleTask: null,
      }
    },

    computed: {
      /**
       * Retrieves Google settings from the Vuex store.
       * @returns {Object} Google settings object.
       */
      googleSettings: ({ $store }) => $store.getters['settings/googleSettings'],

      /* Checks if Google Drive is connected from the Vuex store */
      isGoogleDriveConnected: ({ $store }) => $store.getters['settings/isGoogleDriveConnected'],

      /**
       * Returns the current Google settings.
       * @returns {Object} Current Google settings object.
       */
      settings({ googleSettings, isGoogleDriveConnected }) {
        console.log('Google Settings Computed:', isGoogleDriveConnected)
        return {
          ...googleSettings,
          googleDriveIsConfigured: isGoogleDriveConnected,
        }
      },
    },

    /** Fetches initial admin and system settings. */
    created() {
      this.$store.dispatch('settings/getGoogleSettings', false)
      this.$store.dispatch('settings/getIsGoogleDriveConnected')
      this.buildGoogleRefreshTask()
    },

    methods: {
      /**
       * Retrieves the root directory for Google Drive via the Rpc api call.
       * @returns {string} Root directory path.
       */
      getRootDirectory() {
        const googleManager = Rpc.directData('rpc.UvmContext.googleManager')
        const rootDirectory = googleManager.getAppSpecificGoogleDrivePath(null)
        return rootDirectory
      },

      /**
       * Handles Google Drive configuration event.
       */
      googleDriveConfigure() {
        this.refreshGoogleTask.start()
        window.open(
          Rpc.directData(
            'rpc.UvmContext.googleManager.getAuthorizationUrl',
            window.location.protocol,
            window.location.host,
          ),
        )
      },

      /**
       * Handles Google Drive disconnection event.
       */
      googleDriveDisconnect() {
        Rpc.directData('rpc.UvmContext.googleManager.disconnectGoogleDrive')
        this.refreshGoogleTask.run()
      },

      /**
       * Handles saving of new Google settings.
       * Validates settings and logs the new settings to the console.
       * @param {Object} newSettings - The new Google settings object.
       * @param {Function} validate - Validation function for the settings form.
       */
      onSaveSettings(newSettings, validate) {
        console.log('Saving Google Settings:', newSettings, validate)
      },

      buildGoogleRefreshTask() {
        if (this.refreshGoogleTask) return

        const me = this

        this.refreshGoogleTask = {
          updateFrequency: 3000,
          count: 0,
          // TODO Max attempts should be 40
          maxTries: 10,
          started: false,
          intervalId: null,

          start() {
            console.log('Starting Google Refresh Task')
            this.stop()
            this.count = 0
            this.intervalId = setInterval(() => this.run(), this.updateFrequency)
            this.started = true
          },

          stop() {
            console.log('Stopping Google Refresh Task')
            if (this.intervalId) {
              clearInterval(this.intervalId)
              this.intervalId = null
            }
            this.started = false
          },

          run() {
            this.count++
            console.log('Running Google Refresh Task, attempt:', this.count)
            if (this.count > this.maxTries) {
              this.stop()
              return
            }

            try {
              // Run async RPC calls (native Promise)
              me.$store.dispatch('settings/getIsGoogleDriveConnected')
              me.$store.dispatch('settings/getGoogleSettings', true)

              // Stop task when connected
              const isGoogleDriveConnected = me.$store.getters['settings/isGoogleDriveConnected']
              if (isGoogleDriveConnected) {
                this.stop()
              }
            } catch (ex) {
              console.error(ex)
            }
          },
        }
      },

      /**
       * Optional hook triggered on browser refresh.
       * Fetches updated Admin settings and updates the store.
       */
      onBrowserRefresh() {
        console.log('Google Settings Page Refreshed')
      },
    },
  }
</script>
