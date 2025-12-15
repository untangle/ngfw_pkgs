<template>
  <settings-administration
    :settings="commonSettings"
    @google-drive-configure="googleDriveConfigure"
    @google-drive-disconnect="googleDriveDisconnect"
    @select-directory="selectRootDirectory"
    @certificate-generator="certificteGenerator"
    @download-root-certificate="downloadRootCertificate"
    @delete-certificate="deleteCertificate"
    @set-root-certificate="setRootCertificate"
  >
    <template #actions="{ newSettings, isDirty, validate }">
      <u-btn :min-width="null" :disabled="!isDirty" @click="onSaveSettings(newSettings, validate)">{{
        $t('save')
      }}</u-btn>
    </template>
  </settings-administration>
</template>

<script>
  import { SettingsAdministration } from 'vuntangle'
  import settingsMixin from '../settingsMixin'
  import Rpc from '../../../util/Rpc'
  import Util from '@/util/util'

  export default {
    components: { SettingsAdministration },
    mixins: [settingsMixin],

    computed: {
      /**
       * Retrieves admin settings from the Vuex store.
       * @returns {Object} Admin settings object.
       */
      adminSettings: ({ $store }) => $store.getters['config/adminSetting'],
      /**
       * Retrieves system settings from the Vuex store.
       * @returns {Object} System settings object.
       */
      systemSettings: ({ $store }) => $store.getters['config/systemSetting'],
      /**
       * Retrieves Google settings from the Vuex store.
       * @returns {Object} Google settings object.
       */
      googleSettings: ({ $store }) => $store.getters['config/googleSettings'],

      /* Checks if Google Drive is connected from the Vuex store */
      isGoogleDriveConnected: ({ $store }) => $store.getters['config/isGoogleDriveConnected'],

      /**
       * Retrieves certificates information from the Vuex store.
       * @returns {Object} Certificates information object.
       */
      certificatesInformation: ({ $store }) => $store.getters['config/certificatesInformation'],
      /**
       * Retrieves root certificates from the Vuex store.
       * @returns {Array} List of root certificates.
       */
      rootCertificates: ({ $store }) => $store.getters['config/rootCertificates'],

      serverCertificateVerification: ({ $store }) => $store.getters['config/serverCertificateVerification'],

      /**
       * Combines various settings into a single object for the Administration component.
       * @returns {Object} Combined settings object.
       */
      commonSettings() {
        return {
          admin: this.adminSettings,
          system: this.systemSettings,
          googleSettings: this.googleSettings,
          certificatesInformation: this.certificatesInformation,
          rootCertificates: this.rootCertificates,
          googleDriveIsConfigured: this.isGoogleDriveConnected,
          serverCertificateVerification: this.serverCertificateVerification,
        }
      },
    },

    /**
     * Lifecycle hook that fetches initial admin and system settings,
     * builds the Google refresh task, loads certificates, and dispatches
     * actions to get Google settings and Google Drive connection status.
     */
    created() {
      this.fetchAdminSettings(false)
      this.fetchSystemSettings(false)
      this.buildGoogleRefreshTask()
      this.loadCertificates(false)
      this.$store.dispatch('config/getGoogleSettings', false)
      this.$store.dispatch('config/getIsGoogleDriveConnected')
      this.$store.dispatch('config/getServerCertificateVerification', false)
    },

    methods: {
      /* Fetches admin settings from the backend and updates the store. */
      async fetchAdminSettings(refetch) {
        await this.$store.dispatch('config/getAdminSettings', refetch)
      },

      /* Fetches system settings from the backend and updates the store. */
      async fetchSystemSettings(refetch) {
        await this.$store.dispatch('config/getSystemSettings', refetch)
      },

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
       * handler for select root directory
       * Gets google cloud app details from back-end
       * opens google picker iframe in callback implementation
       */
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
            this.$vuntangle.toast.add(this.$t('an_error_occurred'), 'error')
          }
        } catch (ex) {
          Util.handleException(ex)
        }
      },

      /**
       * Builds a refresh task to get the google drive configuration status and google settings
       */
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
              me.$store.dispatch('config/getIsGoogleDriveConnected')
              me.$store.dispatch('config/getGoogleSettings', true)

              // Stop task when connected
              const isGoogleDriveConnected = me.$store.getters['config/isGoogleDriveConnected']
              if (isGoogleDriveConnected) {
                this.stop()
              }
            } catch (ex) {
              this.$vuntangle.toast.add(this.$t('an_error_occurred') + ex.message, 'error')
            }
          },
        }
      },

      /**
       * Handles saving of new administration, system and Google settings.
       * Validates settings, identifies changes, and dispatches actions to update the store.
       * @param {Object} newSettings - The new combined settings object, where system settings are under the 'system' key and google settings are under 'googleSettings' key.
       * @param {Function} validate - Validation function for the settings form.
       */
      async onSaveSettings(newSettings, validate) {
        if (validate && !(await validate())) return

        const { admin: newAdminSettings, system: newSystemSettings, googleSettings: newGoogleSettings } = newSettings
        const changes = []

        if (!this.isEqual(newAdminSettings, this.adminSettings)) {
          changes.push(this.$store.dispatch('config/setAdminSettings', newAdminSettings))
        }

        if (!this.isEqual(newSystemSettings, this.systemSettings)) {
          changes.push(this.$store.dispatch('config/setSystemSettings', newSystemSettings))
        }

        if (!this.isEqual(newGoogleSettings, this.googleSettings)) {
          changes.push(this.$store.dispatch('config/setGoogleSettings', newGoogleSettings))
        }

        if (!changes.length) return

        this.$store.commit('SET_LOADER', true)
        try {
          await Promise.all(changes)
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },
      /**
       * Compares two objects for equality by converting them to JSON strings.
       * @returns {boolean} True if the objects are equal, false otherwise.
       */
      isEqual(obj1, obj2) {
        return JSON.stringify(obj1) === JSON.stringify(obj2)
      },
      /**
       * Loads certificate information from the store.
       * @param {boolean} refetch - Whether to refetch the data from the server.
       */
      async loadCertificates(refetch) {
        await this.$store.dispatch('config/getRootCertificateInformation', refetch)
        await this.$store.dispatch('config/getRootCertificateList', refetch)
      },
      /**
       * Generates a certificate based on the provided details and mode.
       * @param {Object} details - Certificate details.
       * @param {string} certMode - Mode of the certificate (e.g., 'ROOT').
       * @param {Function} cb - Callback function to handle success or error.
       */

      async certificteGenerator({ details, certMode, cb }) {
        const certSubject = Util.createCertSubject(details)

        if (certMode === 'ROOT') {
          try {
            await Rpc.asyncData(
              'rpc.UvmContext.certificateManager.generateCertificateAuthority',
              details.commonName,
              certSubject,
            )
            await this.loadCertificates(true)
            cb(null, true) // success
          } catch (err) {
            Util.handleException(err)
            cb(err, false) // error
          }
        }
      },

      /* download root certificate */
      async downloadRootCertificate(arg) {
        try {
          await Util.downloadFile(
            '/admin/download',
            { type: 'certificate_download', arg1: arg },
            'root_certificate.crt',
          )
        } catch (err) {
          Util.handleException(err)
        }
      },

      /**
       * Sets the active root certificate.
       * @param {string} payload.data.fileName - The name of the certificate file.
       * @param {Function} payload.cb - Callback function to handle success or error.
       */
      async setRootCertificate({ data, cb }) {
        try {
          await Rpc.asyncData('rpc.UvmContext.certificateManager.setActiveRootCertificate', data.fileName)
          await this.loadCertificates(true)
          cb(null, true) // success
        } catch (err) {
          Util.handleException(err)
          cb(err, false) // error
        }
      },

      /**
       * Deletes a certificate.
       * @param {Object} payload.data - Data containing the certificate details.
       * @param {string} payload.certMode - The mode of the certificate (e.g., 'ROOT').
       * @param {Function} payload.cb - Callback function to handle success or error.
       */
      async deleteCertificate({ data, certMode, cb }) {
        try {
          const validation = Util.canDeleteCertificate(data)

          if (!validation.allowed) {
            cb(validation.message, false)
            return
          }
          await Rpc.asyncData('rpc.UvmContext.certificateManager.removeCertificate', certMode, data.fileName)
          if (certMode === 'ROOT') {
            await this.loadCertificates(true)
          }
          cb(null, true) // success
        } catch (err) {
          Util.handleException(err)
          cb(err, false) // error
        }
      },

      /* Optional hook triggered on browser refresh.
       */
      onBrowserRefresh() {
        this.loadCertificates(true)
        this.fetchAdminSettings(true)
        this.fetchSystemSettings(true)
      },
    },
  }
</script>
