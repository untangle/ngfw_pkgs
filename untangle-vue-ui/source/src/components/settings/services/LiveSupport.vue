<template>
  <v-container fluid :class="`shared-cmp d-flex flex-column flex-grow-1 pa-0`">
    <no-license v-if="!isLicensed" class="mt-2">
      {{ $t('not_licensed_service', [$t('live_support')]) }}
      <template #actions>
        <u-btn class="ml-4" to="/settings/system/about">{{ $t('view_system_license') }}</u-btn>
        <u-btn class="ml-4" :href="manageLicenseUri" target="_blank">
          {{ $t('manage_licenses') }}
          <v-icon right> mdi-open-in-new </v-icon>
        </u-btn>
      </template>
    </no-license>
    <live-support
      :system-settings="systemSettings"
      :company-name="companyName"
      :company-url="companyUrl"
      :disabled="!isLicensed"
      :support-data="supportData"
      @support-launch="supportLaunch"
      @get-uri-with-path="getUriWithPath"
      @get-system-settings="getSettings"
    />
  </v-container>
</template>

<script>
  import { LiveSupport, NoLicense } from 'vuntangle'
  import Util from '../../../util/setupUtil'
  import serviceMixin from './serviceMixin'
  import Rpc from '@/util/Rpc'
  import util from '@/util/util'

  export default {
    components: {
      LiveSupport,
      NoLicense,
    },
    mixins: [serviceMixin],
    data() {
      return {
        licenseNodeName: 'live-support',
        supportData: [],
        companyUrl: '',
      }
    },

    computed: {
      companyName: ({ $store }) => $store.getters['apps/companyName'],
      systemSettings: ({ $store }) => $store.getters['config/systemSetting'],
    },

    created() {
      this.$store.dispatch('config/getSystemSettings', false)
      this.getSupportData()
    },

    methods: {
      getSettings() {
        this.$store.dispatch('config/getSystemSettings', true)
      },

      getUriWithPath() {
        try {
          window.open(window.rpc.uriManager.getUriWithPath('https://edge.arista.com/shop/Live-Support'))
        } catch (ex) {
          Util.handleException(ex)
        }
      },

      async supportLaunch({ yesHandler, cb }) {
        const baseUrl = await util.getStoreUrl()

        const about = util.getAbout()
        const fragment = window.location.hash ? window.location.hash.substring(1) : ''

        let supportUrl = `${baseUrl}?action=support&${about}&fragment=${fragment}&line=ngfw`
        const user = Rpc.directData('rpc.adminManager.getSettingsV2')?.users?.[0]
        if (user) {
          supportUrl += '&email=' + user.emailAddress
        }

        window.open(supportUrl)
        if (yesHandler) {
          try {
            this.$store.commit('SET_LOADER', true)
            await this.$store.dispatch('config/getSystemSettings', true)
            const systemSettings = JSON.parse(JSON.stringify(this.systemSettings))
            systemSettings.supportEnabled = true
            systemSettings.cloudEnabled = true
            const response = await this.$store.dispatch('config/setSystemSettings', systemSettings)
            this.$store.commit('SET_LOADER', false)
            cb(response)
          } catch (ex) {
            Util.handleException(ex)
          } finally {
            this.$store.commit('SET_LOADER', false)
          }
        }
      },

      async getSupportData() {
        try {
          this.$store.commit('SET_LOADER', true)
          const [companyURL, serverUID, fullVersionAndRevision] = await Promise.all([
            window.rpc.companyURL,
            window.rpc.serverUID,
            window.rpc.fullVersionAndRevision,
          ])
          const data = []
          this.companyUrl = companyURL
          data.push({ name: 'server_uid', value: serverUID }, { name: 'build', value: fullVersionAndRevision })
          this.supportData = data
        } catch (ex) {
          Util.handleException(ex)
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },
    },
  }
</script>
