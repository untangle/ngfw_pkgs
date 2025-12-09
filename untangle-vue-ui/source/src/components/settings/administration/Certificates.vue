<template>
  <settings-certificates
    :settings="commonSettings"
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
  </settings-certificates>
</template>

<script>
  import { SettingsCertificates } from 'vuntangle'
  import settingsMixin from '../settingsMixin'
  import Rpc from '@/util/Rpc'
  import Util from '@/util/util'

  export default {
    components: { SettingsCertificates },
    mixins: [settingsMixin],

    computed: {
      /**
       * Retrieves certificates information from the Vuex store.
       * @returns {Object} Certificates information object.
       */
      certificatesInformation: ({ $store }) => $store.getters['config/certificatesInformation'],
      rootCertificates: ({ $store }) => $store.getters['config/rootCertificates'],
      commonSettings() {
        return { certificatesInformation: this.certificatesInformation, rootCertificates: this.rootCertificates }
      },
    },

    created() {
      this.loadCertificates(false)
    },

    methods: {
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
            'root_certificate.pem',
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
          const validation = this.canDeleteCertificate(data)

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
      },
    },
  }
</script>
