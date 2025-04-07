import api from '@/plugins/api'
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
      const response = await api.get(`/api/license/enabled/${this.licenseNodeName}`)
      this.isLicensed = response?.result || false
    },

    /**
     * PROP: manage-license-uri
     * Fetches the URI for license management
     */
    async getManageLicenseUri() {
      this.manageLicenseUri = await uris.translate(uris.list.subscriptions)
    },
  },
}
