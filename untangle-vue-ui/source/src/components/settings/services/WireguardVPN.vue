<template>
  <!-- Parent Container -->
  <v-container fluid class="shared-cmp d-flex flex-column flex-grow-1 pa-0">
    <!-- No License Component -->
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

    <!-- WireguardVPN Component -->
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
      @check-network-availability="isNetworkAvailable"
      @refresh-tunnel-status="fetchTunnelStatus"
      @request-new-address-pool="requestNewAddressPool"
    >
      <template #actions="{ newSettings, isDirty, validate }">
        <!-- Installed State Actions -->
        <div v-if="isInstalled" class="d-flex flex-wrap align-center" style="gap: 8px">
          <!-- Uninstall Service -->
          <div style="min-width: 140px">
            <u-app-status-remove class="mt-0" service-app :app-name="$t('wireguard_vpn')" @remove="onRemoveService" />
          </div>
          <v-divider vertical class="mx-4" />
          <!-- Refresh and Save Buttons -->
          <u-btn class="mr-2" @click="refreshData">{{ $vuntangle.$t('refresh') }}</u-btn>
          <u-btn :disabled="!isDirty" @click="saveSettingsWithValidation(newSettings, validate)">
            {{ $vuntangle.$t('save') }}
          </u-btn>
        </div>
        <!-- Uninstalled State Actions -->
        <div v-else style="min-width: 180px">
          <!-- Install Service -->
          <u-app-install @install="onInstallService" />
        </div>
      </template>
    </WireguardVPN>
  </v-container>
</template>

<script>
  import { WireguardVPN, NoLicense, UAppStatusRemove, UAppInstall } from 'vuntangle'
  import serviceMixin from './serviceMixin'
  import util from '@/util/util'
  import { rpcCall } from '@/util/rpcHelpers'

  export default {
    components: {
      WireguardVPN,
      NoLicense,
      UAppStatusRemove,
      UAppInstall,
    },

    mixins: [serviceMixin],

    data() {
      return {
        serviceName: 'wireguard-vpn',
        licenseNodeName: 'wireguard-vpn',
        displayNameFallback: 'WireGuard VPN',
        tunnelStatusData: [],
      }
    },

    computed: {
      // Server timezone offset in milliseconds, used for formatting timestamps
      serverTzOffset: ({ $store }) => $store.getters['config/timeZoneOffset'],

      // Enriches the tunnel status data with additional information from the settings
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
            'latest-handshake-display':
              util.formatUnixTimestamp(status['latest-handshake'], this.serverTzOffset) ||
              this.$vuntangle.$t('wireguard_no_recent_activity'),
          }
        })
      },
    },

    watch: {
      // Watch for changes in the app's power state to fetch or clear tunnel status data
      'powerState.on'(isOn) {
        if (isOn) {
          this.fetchTunnelStatus()
        } else {
          this.tunnelStatusData = []
        }
      },
    },

    methods: {
      /**
       * Checks a WireGuard network against NGFW's registered network spaces.
       * @param network {string} Network in CIDR notation
       * @param callback {Function} Receives the conflict object, or null when available
       */
      async isNetworkAvailable(network, callback) {
        const conflict = await util.checkNetworkAvailability('wireguard-vpn', network)
        callback(conflict)
      },

      /**
       * Fetches the current tunnel status from the backend and updates the component state
       */
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
          this.$vuntangle.toast.add(
            this.$vuntangle.$t('wireguard_tunnel_status_fetch_error', [error?.message || error]),
            'error',
          )
        }
      },

      /**
       * Requests a new address pool from the backend and updates the provided setter function
       * @param setAddressPool {Function} A function to update the address pool in the component state
       */
      async requestNewAddressPool(setAddressPool) {
        try {
          if (!this.appManager?.getNewAddressPool) return
          const addressPool = await rpcCall(this.appManager.getNewAddressPool.bind(this.appManager), [], {
            mode: 'propagate',
          })
          if (addressPool && typeof setAddressPool === 'function') setAddressPool(addressPool)
        } catch (error) {
          this.$vuntangle.toast.add(
            this.$vuntangle.$t('wireguard_address_pool_fetch_error', [error?.message || error]),
            'error',
          )
        }
      },

      /**
       * Saves the new settings after optional validation
       * @param newSettings {Object} The new settings to save
       * @param validate {Function} Optional validation function that returns a boolean or a Promise resolving to a boolean
       */
      async saveSettingsWithValidation(newSettings, validate) {
        if (validate && !(await validate())) return
        await this.saveWireguardSettings(newSettings)
      },

      /**
       * Saves the Wireguard settings to the backend and refreshes the app data
       * @param newSettings {Object} The new settings to save
       */
      async saveWireguardSettings(newSettings) {
        this.$store.commit('SET_LOADER', true)
        try {
          await rpcCall(this.appManager?.setSettingsV2?.bind(this.appManager), [newSettings, true], {
            fallback: false,
          })
          await this.$store.dispatch('apps/loadAppData', {
            appName: this.licenseNodeName,
            app: this.appManager,
          })
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },
    },
  }
</script>
