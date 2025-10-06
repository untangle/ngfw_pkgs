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
      const response = await window.rpc.UvmContext.licenseManager().getLicense(this.licenseNodeName).valid
      this.isLicensed = response || response
    },

    /**
     * PROP: manage-license-uri
     * Fetches the URI for license management
     */
    async getManageLicenseUri() {
      this.manageLicenseUri = await window.rpc.uriManager.getUriWithPath(uris.list.subscriptions)
    },
  },
}
