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
    @handle-file-import="handleFileImport"
    @upload-certificate="uploadCertificate"
  >
    <template #actions="{ newSettings, isDirty, validate }">
      <u-btn :min-width="null" :disabled="!isDirty" @click="onSaveSettings(newSettings, validate)">{{
        $t('save')
      }}</u-btn>
    </template>
  </settings-administration>
</template>

<script>
  import { isEqual } from 'lodash'
  import { SettingsAdministration } from 'vuntangle'
  import settingsMixin from '../settingsMixin'
  import Rpc from '../../../util/Rpc'
  import Util from '@/util/util'
  import util from '@/util/setupUtil'

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

      /**
       * Retrieves server certificate verification setting from the Vuex store.
       * @returns {boolean} Server certificate verification status.
       */
      serverCertificateVerification: ({ $store }) => $store.getters['config/serverCertificateVerification'],

      /**
       * Retrieves server certificates from the Vuex store.
       * @returns {Array} List of server certificates.
       */
      serverCertificates: ({ $store }) => $store.getters['config/serverCertificates'],

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
          serverCertificates: this.serverCertificates,
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
    },

    methods: {
      isEqual,
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
          util.handleException(ex)
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
       * Maps server certificates to system settings.
       * This function resets the certificate-related properties in the system settings
       * and then maps the server certificates to their respective properties based on their usage flags.
       * @param {Object} systemSettings - The system settings object to be updated.
       * @param {Array} serverCertificates - The list of server certificates.
       * @returns {Object} The updated system settings object.
       */
      mapServerCertificatesToSystemSettings(systemSettings, serverCertificates) {
        // reset first (important)
        systemSettings.webCertificate = null
        systemSettings.mailCertificate = null
        systemSettings.ipsecCertificate = null
        systemSettings.radiusCertificate = null

        serverCertificates.forEach(cert => {
          if (cert.httpsServer) {
            systemSettings.webCertificate = cert.fileName
          }
          if (cert.smtpsServer) {
            systemSettings.mailCertificate = cert.fileName
          }
          if (cert.ipsecServer) {
            systemSettings.ipsecCertificate = cert.fileName
          }
          if (cert.radiusServer) {
            systemSettings.radiusCertificate = cert.fileName
          }
        })
        return systemSettings
      },
      /**
       * Handles saving of new administration, system and Google settings.
       * Validates settings, identifies changes, and dispatches actions to update the store.
       * @param {Object} newSettings - The new combined settings object, where system settings are under the 'system' key and google settings are under 'googleSettings' key.
       * @param {Function} validate - Validation function for the settings form.
       */
      async onSaveSettings(newSettings, validate) {
        if (validate && !(await validate())) return

        const {
          admin: newAdminSettings,
          system: newSystemSettings,
          googleSettings: newGoogleSettings,
          serverCertificates,
        } = newSettings
        const changes = []
        this.mapServerCertificatesToSystemSettings(newSystemSettings, serverCertificates)
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
          this.loadCertificates(true)
          this.$vuntangle.toast.add(this.$vuntangle.$t('administration_settings_saved'))
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      /**
       * Loads certificate information from the store.
       * @param {boolean} refetch - Whether to refetch the data from the server.
       */
      async loadCertificates(refetch) {
        await this.$store.dispatch('config/getServerCertificateList', refetch)
        await this.$store.dispatch('config/getRootCertificateInformation', refetch)
        await this.$store.dispatch('config/getServerCertificateVerification', refetch)
        await this.$store.dispatch('config/getNetworkSettings', refetch)
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
            util.handleException(err)
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
          util.handleException(err)
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
          util.handleException(err)
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
          } else if (certMode === 'SERVER') {
            await this.$store.dispatch('config/getServerCertificateList', true)
          }
          cb(null, true) // success
        } catch (err) {
          util.handleException(err)
          cb(err, false) // error
        }
      },

      /**
       * Handles file import for certificates.
       * This function uploads a certificate file to the server.
       * @param {Object} payload - The payload object.
       * @param {File} payload.file - The file to be imported.
       * @param {string} payload.argument - Additional argument for the upload.
       * @param {Function} payload.cb - Callback function to handle the response.
       */
      async handleFileImport({ file, argument, cb }) {
        if (!file) {
          this.$vuntangle.toast.add(this.$t('please_choose_a_file'), 'error')
          return
        }

        try {
          const response = await Util.uploadFile('/admin/upload', {
            filename: file,
            argument,
            formName: 'upload_form',
            type: 'certificate_upload',
          })
          const parseData = response?.msg ? JSON.parse(response.msg) : {}
          cb(parseData)
        } catch (err) {
          util.handleException(err)
        }
      },

      /**
       * Uploads a certificate to the server using an RPC call.
       * This function is used to upload a certificate with its key and other data.
       * @param {Object} payload - The payload object.
       * @param {string} payload.certMode - The certificate mode (e.g., 'ROOT').
       * @param {Function} payload.cb - Callback function to handle success or error.
       */
      async uploadCertificate({ certMode, certData, keyData, extraData, cb }) {
        try {
          const response = await Rpc.asyncData(
            'rpc.UvmContext.certificateManager.uploadCertificate',
            certMode,
            certData,
            keyData,
            extraData,
          )

          if (response.result !== 0) {
            cb(response.output, false)
            return
          }

          if (certMode === 'ROOT') {
            await this.loadCertificates(true)
          }

          cb(response.output, true)
        } catch (err) {
          util.handleException(err)
          cb(err, false)
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
