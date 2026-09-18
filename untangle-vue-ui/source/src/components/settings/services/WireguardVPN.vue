<template>
  <v-container fluid class="shared-cmp d-flex flex-column flex-grow-1 pa-0">
    <no-license v-if="!isLicensed && isInstalled" class="mt-2">
      {{ $t('not_licensed_service', [$t('wireguard_vpn')]) }}
      <template #actions>
        <u-btn class="ml-4" to="/settings/system/about">
          {{ $t('view_system_license') }}
        </u-btn>
        <u-btn class="ml-4" :href="manageLicenseUri" target="_blank">
          {{ $t('manage_licenses') }}
          <v-icon right>mdi-open-in-new</v-icon>
        </u-btn>
      </template>
    </no-license>
    <WireguardVPN
      v-if="settings"
      :settings="settings"
      :app-data="consolidatedAppData"
      :disabled="!isLicensed && isInstalled"
      :is-installed="isInstalled"
      :metrics-data="formattedMetrics"
      :reports="appReports"
      :tunnel-status-data="enrichedTunnelStatusData"
      @toggle-state="toggleAppState"
      @refresh-tunnel-status="fetchTunnelStatus"
    >
      <template #actions="{ newSettings, isDirty }">
        <div v-if="isInstalled" class="d-flex flex-wrap align-center" style="gap: 8px">
          <div style="min-width: 180px">
            <u-app-status-remove class="mt-0" service-app :app-name="$t('wireguard_vpn')" @remove="onRemoveService" />
          </div>
          <v-divider vertical class="mx-4" />
          <u-btn class="mr-2" @click="refreshData">{{ $vuntangle.$t('refresh') }}</u-btn>
          <u-btn :disabled="!isDirty" @click="saveSettings(newSettings)">
            {{ $vuntangle.$t('save') }}
          </u-btn>
        </div>
        <div v-else style="min-width: 180px">
          <u-app-install @install="onInstallService" />
        </div>
      </template>
    </WireguardVPN>
  </v-container>
</template>

<script>
  import { WireguardVPN, NoLicense, UAppStatusRemove, UAppInstall } from 'vuntangle'
  import serviceMixin from './serviceMixin'
  import { rpcCall } from '@/util/rpcHelpers'

  export default {
    components: {
      WireguardVPN,
      NoLicense,
      UAppStatusRemove,
      UAppInstall,
    },

    mixins: [serviceMixin],

    computed: {
      serverTzOffset: ({ $store }) => $store.getters['config/timeZoneOffset'],

      enrichedTunnelStatusData() {
        const tunnelsByPublicKey = new Map(
          (Array.isArray(this.settings?.tunnels) ? this.settings.tunnels : []).map(tunnel => [
            tunnel.publicKey,
            tunnel,
          ]),
        )

        return this.tunnelStatusData.map(status => {
          const tunnel = tunnelsByPublicKey.get(status['peer-key'])

          return {
            ...status,
            'tunnel-description': tunnel?.description || '',
            'configured-endpoint': tunnel?.endpointHostname || '',
            'latest-handshake-display': this.formatHandshake(status['latest-handshake']),
          }
        })
      },
    },

    data() {
      return {
        serviceName: 'wireguard-vpn',
        licenseNodeName: 'wireguard-vpn',
        displayNameFallback: 'WireGuard VPN',
        tunnelStatusData: [],
      }
    },

    watch: {
      'powerState.on'(isOn) {
        if (isOn) {
          this.fetchTunnelStatus()
        } else {
          this.tunnelStatusData = []
        }
      },
    },

    methods: {
      formatHandshake(value) {
        const timestamp = Number(value)
        if (!timestamp) return this.$vuntangle.$t('wireguard_no_recent_activity')

        const browserOffsetMs = new Date().getTimezoneOffset() * 60000
        const date = new Date(timestamp * 1000 + browserOffsetMs + this.serverTzOffset)
        return date.toLocaleString(undefined, { hour12: true })
      },

      async fetchTunnelStatus() {
        if (!this.appManager) return

        try {
          const result = await rpcCall(this.appManager?.getTunnelStatus?.bind(this.appManager), [], {
            mode: 'propagate',
          })
          const status = result ? JSON.parse(result) : {}
          this.tunnelStatusData = status?.wireguard || []
        } catch (error) {
          this.tunnelStatusData = []
          this.$vuntangle.toast.add(`Error occurred while fetching tunnel status: ${error?.message || error}`, 'error')
        }
      },
    },
  }
</script>
