<template>
  <bandwidth-control
    :settings="settings"
    :app-data="consolidatedAppData"
    :sessions-data="sessionsData"
    :metrics-data="formattedMetrics"
    :reports="appReports"
    :is-configured="isConfigured"
    :qos-enabled="qosEnabled"
    :wan-interfaces="wanInterfaces"
    @toggle-state="toggleAppState"
    @fetch-network-settings="fetchNetworkSettings"
    @save-network-settings="saveNetworkSettings"
    @load-defaults="loadDefaults"
    @add-quota-rules="addQuotaRules"
    @wizard-complete="onWizardComplete"
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
  </bandwidth-control>
</template>

<script>
  import { cloneDeep } from 'lodash'
  import { BandwidthControl, UAppStatusRemove } from 'vuntangle'
  import { VDivider } from 'vuetify/lib'
  import appMixin from '../appMixin'
  import { APP_CONFIG } from '@/constants/apps'
  import util from '@/util/util'
  import { rpcCall } from '@/util/rpcHelpers'

  export default {
    name: 'BandwidthControlApp',

    components: { BandwidthControl, UAppStatusRemove, VDivider },

    mixins: [appMixin],

    provide() {
      return {
        $remoteData: () => ({
          interfaces: this.interfaces,
        }),
        $features: {},
        $applications: null,
        $readOnly: false,
      }
    },

    props: {
      appData: { type: Object, default: null },
    },

    data() {
      return {
        appName: this.appData?.appName || APP_CONFIG.BANDWIDTH_CONTROL.appName,
        defaultDisplayName: APP_CONFIG.BANDWIDTH_CONTROL.defaultDisplayName,
      }
    },

    computed: {
      consolidatedAppData: appInstance => appInstance.buildConsolidatedAppData(),
      isConfigured: ({ settings }) => !!settings?.configured,
      networkSettings: ({ $store }) => $store.getters['config/networkSetting'],
      qosEnabled: ({ networkSettings }) => !!networkSettings?.qosSettings?.qosEnabled,
      wanInterfaces: ({ networkSettings }) =>
        (networkSettings?.interfaces || []).filter(iface => iface.wan && iface.configType === 'ADDRESSED'),
      interfaces: ({ networkSettings }) => util.getInterfaceList(networkSettings, true, true),
    },

    methods: {
      async onWizardComplete() {
        const result = await this.$store.dispatch('apps/loadAppData', {
          appName: this.appData?.appName,
          appId: this.appData?.instance?.id,
          app: this.appManager,
        })
        const configured = !!result?.settings?.configured
        if (configured && !this.consolidatedAppData?.powerState?.on) {
          this.toggleAppState(true)
        }
      },

      async fetchNetworkSettings() {
        await this.$store.dispatch('config/getNetworkSettings', true)
      },

      async loadDefaults({ config, cb }) {
        if (!this.appManager) return
        this.$store.commit('SET_LOADER', true)
        const result = await rpcCall(this.appManager?.wizardLoadDefaults?.bind(this.appManager), [config], {
          fallback: null,
        })
        this.$store.commit('SET_LOADER', false)
        if (!result?.code) cb?.()
      },

      async addQuotaRules({ quota, cb }) {
        if (!this.appManager) return
        const size = Math.round(quota.size * quota.unit)
        const calls = []
        if (quota.hostEnabled) {
          calls.push(
            rpcCall(
              this.appManager?.wizardAddHostQuotaRules?.bind(this.appManager),
              [quota.expiration, size, quota.priority],
              { fallback: null },
            ),
          )
        }
        if (quota.userEnabled) {
          calls.push(
            rpcCall(
              this.appManager?.wizardAddUserQuotaRules?.bind(this.appManager),
              [quota.expiration, size, quota.priority],
              { fallback: null },
            ),
          )
        }
        await Promise.all(calls)
        cb?.()
      },

      async saveNetworkSettings({ interfaces, cb }) {
        const networkSettingsCopy = cloneDeep(this.networkSettings)
        networkSettingsCopy.qosSettings.qosEnabled = true
        networkSettingsCopy.interfaces = networkSettingsCopy.interfaces.map(iface => {
          if (iface.wan) {
            const updated = interfaces.find(w => w.interfaceId === iface.interfaceId)
            return {
              ...iface,
              qosEnabled: true,
              ...(updated && { downloadKbps: updated.downloadKbps, uploadKbps: updated.uploadKbps }),
            }
          }
          return iface
        })
        this.$store.commit('SET_LOADER', true)
        await this.$store.dispatch('config/setNetworkSettingV2', networkSettingsCopy).finally(() => {
          this.$store.commit('SET_LOADER', false)
        })
        cb?.()
      },
    },
  }
</script>
