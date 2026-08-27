<template>
  <threat-prevention
    :settings="settings"
    :app-data="consolidatedAppData"
    :metrics-data="formattedMetrics"
    :reports="appReports"
    @toggle-state="toggleAppState"
    @threat-lookup="handleThreatLookup"
  >
    <!-- Custom action buttons slot -->
    <template #actions="{ newSettings, isDirty }">
      <div class="d-flex flex-wrap align-center" style="gap: 8px">
        <div style="min-width: 140px">
          <u-app-status-remove class="mt-0" :app-name="appDisplayName" @remove="removeApp" />
        </div>
        <v-divider vertical class="mx-4" />
        <u-btn class="mr-2" @click="refreshData">{{ $t('refresh') }}</u-btn>
        <u-btn :disabled="!isDirty || saveDisabled" @click="saveSettings(newSettings)">{{ $t('save') }}</u-btn>
      </div>
    </template>
  </threat-prevention>
</template>

<script>
  import { ThreatPrevention, UAppStatusRemove } from 'vuntangle'
  import { VDivider } from 'vuetify/lib'
  import appMixin from '../appMixin'
  import conditionDataMixin from '../conditionDataMixin'
  import util from '@/util/util'
  import { urlAddrRe, ipv4Re } from '@/constants'
  import Util from '@/util/setupUtil'

  export default {
    name: 'ThreatPreventionApp',

    components: {
      ThreatPrevention,
      UAppStatusRemove,
      VDivider,
    },

    mixins: [appMixin, conditionDataMixin(['directory-connector'])],

    provide() {
      return {
        $remoteData: () => ({
          interfaces: this.interfaces,
          directoryUsers: this.directoryUsers,
        }),
        $features: { isExpertMode: this.isExpertMode, hasFlaggedAction: true },
        $readOnly: false,
        $applications: {},
      }
    },

    props: {
      appData: { type: Object, default: null },
    },

    data() {
      return {
        appName: this.appData?.appName || 'threat-prevention',
        defaultDisplayName: 'Threat Prevention',
        localNetworks: [],
      }
    },

    computed: {
      // Get the consolidated app data for the threat prevention app.
      consolidatedAppData: appInstance => appInstance.buildConsolidatedAppData(),
      // Get the network settings from the store and extract the interfaces.
      networkSettings: ({ $store }) => $store.getters['config/networkSetting'],
      interfaces: ({ networkSettings }) => util.getInterfaceList(networkSettings, true, true),
      // Get isExpertMode from the store.
      isExpertMode: ({ $store }) => $store.getters['config/isExpertMode'],
    },

    watch: {
      appManager: {
        immediate: true,
        handler(mgr) {
          if (!mgr) return
          try {
            mgr.getReportInfo(
              (res, ex) => {
                if (!ex && res) this.localNetworks = res
                else this.$vuntangle.toast.add(`${this.$t('error')}: ${ex}`, 'error')
              },
              'localNetworks',
              null,
            )
          } catch (e) {
            Util.handleException(e)
          }
        },
      },
    },

    created() {
      this.$store.dispatch('config/getNetworkSettings', false)
    },

    methods: {
      /**
       * Handle the threat lookup request from the threats tab component.
       * @param param0 input: The input string to look up (IP or hostname).
       * @param param0 resolve: The callback function to resolve the threat lookup result.
       */
      async handleThreatLookup({ input, resolve }) {
        // Check if the app manager is available
        if (!this.appManager) {
          resolve({ error: 'threat_lookup_unavailable' })
          return
        }

        // Parse the input to extract the lookup target (IP or hostname)
        const lookupTarget = this.parseLookupInput(input)

        // Check if the lookup target is a local network IP
        if (this.isLocalNetworkIp(lookupTarget)) {
          resolve({ local: true })
          return
        }

        // Perform the RPC calls to get the threat information
        const rpc = key =>
          new Promise((resolve, reject) => {
            if (!this.appManager) {
              reject(new Error('threat_lookup_unavailable'))
              return
            }
            this.appManager.getReportInfo((res, ex) => (ex ? reject(ex) : resolve(res)), key, [lookupTarget])
          })

        try {
          // Sequential execution of RPC calls to ensure proper handling of results
          const ipInfo = await rpc('getIpInfo')
          const urlInfo = await rpc('getUrlInfo')
          const ipHistory = await rpc('getIpHistory')
          const urlHistory = await rpc('getUrlHistory')

          let urlAddress = lookupTarget
          let ipAddress = null

          // Parse getIpInfo
          let ipResult = {}
          let ipOcc = null
          if (ipInfo != null) {
            ipResult = ipInfo[0] || {}
            if (ipResult.ip) ipAddress = ipResult.ip
            ipOcc = ipHistory?.[0]?.queries?.getrephistory?.history_count ?? null
            if (ipOcc != null && ipOcc <= 0) ipOcc = null
          }

          // Parse getUrlInfo
          let urlResult = {}
          if (urlInfo != null) {
            urlResult = urlInfo[0] || {}
            if (urlResult.url) urlAddress = urlResult.url
          }
          let urlOcc = urlHistory?.[1]?.queries?.getrepinfo?.threathistory ?? null
          if (urlOcc != null && urlOcc <= 0) urlOcc = null

          // Return the consolidated threat information
          resolve({
            address: ipAddress != null && ipAddress !== urlAddress ? `${urlAddress} (${ipAddress})` : urlAddress,
            serverReputation: urlResult.reputation ?? null,
            serverOccurrences: urlOcc,
            clientReputation: ipResult.reputation ?? null,
            clientOccurrences: ipOcc,
          })
        } catch {
          resolve({ error: 'threat_lookup_failed' })
        }
      },

      /**
       * Parse the input string to extract the hostname from a URL or return the input as is.
       * @param {string} input - The input string to parse.
       * @returns {string} - The extracted hostname or the original input if no hostname is found.
       */
      parseLookupInput(input) {
        const parts = input.match(urlAddrRe)
        if (parts && parts[3] != null) {
          return parts[3]
        }
        return input
      },

      /**
       * Check if the given input is a local network IPv4 address.
       * @param {string} input - The input string to check.
       * @returns {boolean} - True if the input is a local network IP address.
       */
      isLocalNetworkIp(input) {
        if (!ipv4Re.test(input)) return false
        return this.localNetworks.some(net => util.ipMatchesNetwork(input, net.address, net.netmask))
      },
    },
  }
</script>
