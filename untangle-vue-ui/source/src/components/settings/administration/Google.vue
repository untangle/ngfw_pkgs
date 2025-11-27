<template>
  <settings-google
    :settings="settings"
    @google-drive-configure="googleDriveConfigure"
    @google-drive-disconnect="googleDriveDisconnect"
    @select-directory="selectRootDirectory"
  >
    <template #actions="{ newSettings, isDirty }">
      <u-btn :min-width="null" :disabled="!isDirty" @click="onSaveSettings(newSettings)">{{ $t('save') }}</u-btn>
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
            window.parent.location.protocol,
            window.parent.location.host,
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
       * @param {Object} newSettings - The new Google settings object.
       */
      async onSaveSettings(newSettings) {
        this.$store.commit('SET_LOADER', true)
        await this.$store
          .dispatch('settings/setGoogleSettings', newSettings)
          .finally(() => this.$store.commit('SET_LOADER', false))
      },

      async selectRootDirectory(cb) {
        try {
          const result = await Rpc.asyncPromise('rpc.UvmContext.googleManager.getGoogleCloudApp')()
          if (result && result.clientId) {
            const googlePickerMessageData = {
              action: 'openPicker',
              clientId: result.clientId,
              appId: result.appId,
              scopes: result.scopes,
              apiKey: result.apiKey,
              relayServerUrl: result.relayServerUrl,
              origin: window.location.protocol + '//' + window.location.host,
            }

            cb(googlePickerMessageData)
          } else {
            console.error('getGoogleCloudApp did not return a client ID')
          }
        } catch (ex) {
          console.error('Error in selectRootDirectory:', ex)
        }
      },

      buildGoogleRefreshTask() {
        if (this.refreshGoogleTask) return

        const me = this

        this.refreshGoogleTask = {
          updateFrequency: 3000,
          count: 0,
          maxTries: 40,
          started: false,
          intervalId: null,

          start() {
            this.stop()
            this.count = 0
            this.intervalId = setInterval(() => this.run(), this.updateFrequency)
            this.started = true
          },

          stop() {
            if (this.intervalId) {
              clearInterval(this.intervalId)
              this.intervalId = null
            }
            this.started = false
          },

          run() {
            this.count++
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
    },
  }
</script>
