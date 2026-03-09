<template>
  <v-container fluid :class="`shared-cmp d-flex flex-column flex-grow-1 pa-0`">
    <branding-manager
      :settings="settings"
      :is-licensed.sync="isLicensed"
      :manage-license-uri="manageLicenseUri"
      @check-license="checkLicense"
      @get-manage-license-uri="getManageLicenseUri"
    />
  </v-container>
</template>

<script>
  import { BrandingManager } from 'vuntangle'
  import Util from '../../../util/setupUtil'
  import uris from '@/util/uris'

  export default {
    components: {
      BrandingManager,
    },

    data() {
      return {
        licenseNodeName: 'branding-manager',
        isLicensed: false,
        manageLicenseUri: null,
      }
    },

    computed: {
      settings: ({ $store }) => $store.getters['apps/getSettings']('branding-manager')?.settings,
    },

    created() {
      this.$store.dispatch('apps/loadAppData', this.licenseNodeName)
    },

    methods: {
      async checkLicense() {
        try {
          if (!this.licenseNodeName) return
          this.isLicensed = await this.$store.dispatch('apps/checkLicenseStatus', this.licenseNodeName)
        } catch (error) {
          Util.handleException(error)
        }
      },

      async getManageLicenseUri() {
        try {
          this.manageLicenseUri = await this.$store.dispatch('apps/fetchManageLicenseUri', uris.list.subscriptions)
        } catch (error) {
          Util.handleException(error)
        }
      },
    },
  }
</script>
