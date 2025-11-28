<template>
  <settings-certificates :certificates-information="certificatesInformation" />
</template>

<script>
  import { SettingsCertificates } from 'vuntangle'

  export default {
    components: { SettingsCertificates },

    computed: {
      /**
       * Retrieves certificates information from the Vuex store.
       * @returns {Object} Certificates information object.
       */
      certificatesInformation: ({ $store }) => $store.getters['settings/certificatesInformation'],
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
        await this.$store.dispatch('settings/getCertificatesInformation', refetch)
      },

      onBrowserRefresh() {
        this.loadCertificates(true)
      },
    },
  }
</script>
