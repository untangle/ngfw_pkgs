<template>
  <settings-certificates
    :certificates-information="certificatesInformation"
    @certificate-generator="certificteGenerator"
    @download-root-certificate="downloadRootCertificate"
  />
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
        await this.$store.dispatch('config/getCertificatesInformation', refetch)
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
          await Util.downloadFile('/admin/download', { type: 'certificate_download', arg1: arg }, 'root_authority.crt')
        } catch (err) {
          Util.handleException(err)
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
