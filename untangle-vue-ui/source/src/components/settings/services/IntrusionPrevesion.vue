<template>
  <v-container fluid :class="`shared-cmp d-flex flex-column flex-grow-1 pa-0`">
    <no-license v-if="isLicensed === false && isInstalled" class="mt-2">
      {{ $t('not_licensed_service', [$t('intrusion_prevention')]) }}
      <template #actions>
        <u-btn class="ml-4" to="/settings/system/about">{{ $t('view_system_license') }}</u-btn>
        <u-btn class="ml-4" :href="manageLicenseUri" target="_blank">
          {{ $t('manage_licenses') }}
          <v-icon right>mdi-open-in-new</v-icon>
        </u-btn>
      </template>
    </no-license>

    <intrusion-prevention
      v-if="settings"
      ref="intrusionPrevention"
      :settings="settings"
      :app-data="consolidatedAppData"
      :tabs="allTabs"
      :disabled="!isLicensed && isInstalled"
      :metrics-data="formattedMetrics"
      :reports="appReports"
      :overview-data="overviewData"
      :memory-data="memoryData"
      :max-memory="maxMemory"
      @toggle-state="toggleAppState"
      @fetch-signatures="onFetchSignatures"
    >
      <template #actions="{ newSettings, isDirty }">
        <div v-if="isInstalled" class="d-flex flex-wrap align-center" style="gap: 8px">
          <div style="min-width: 180px">
            <u-app-status-remove class="mt-0" :app-name="$t('intrusion_prevention')" @remove="onRemoveService" />
          </div>
          <v-divider vertical class="mx-4" />
          <u-btn class="mr-2" @click="refreshData">
            {{ $vuntangle.$t('refresh') }}
          </u-btn>
          <u-btn :disabled="!isDirty" @click="saveSettings(newSettings)">
            {{ $vuntangle.$t('save') }}
          </u-btn>
        </div>
        <div v-else style="min-width: 180px">
          <u-app-install @install="onInstallService" />
        </div>
      </template>
    </intrusion-prevention>
  </v-container>
</template>

<script>
  import { mapGetters } from 'vuex'
  import { IntrusionPrevention, NoLicense, UAppStatusRemove, UAppInstall, intrusionPreventionAllTabs } from 'vuntangle'
  import { VDivider } from 'vuetify/lib'
  import { ngfwCapabilities } from './IPCapabilities'
  import serviceMixin from './serviceMixin'

  export default {
    components: {
      IntrusionPrevention,
      NoLicense,
      UAppStatusRemove,
      UAppInstall,
      VDivider,
    },

    mixins: [serviceMixin],

    provide() {
      return {
        capabilities: ngfwCapabilities,
      }
    },

    data() {
      const now = Math.round(Date.now() / 1000) * 1000
      return {
        serviceName: 'intrusion-prevention',
        licenseNodeName: 'intrusion-prevention',
        displayNameFallback: 'Intrusion Prevention',
        overviewData: { daemonErrors: '', lastUpdate: '', lastUpdateCheck: '' },
        memoryHistory: Array.from({ length: 7 }, (_, i) => ({ timestamp: now + (i - 6) * 10000, memory: 0 })),
      }
    },

    computed: {
      ...mapGetters('metrics', ['getAppMetric', 'lastUpdateTime', 'systemStats']),

      iconPath: () => null,

      allTabs: () => intrusionPreventionAllTabs,

      memoryData() {
        return this.memoryHistory
      },

      maxMemory() {
        return this.systemStats?.MemTotal || 0
      },
    },

    watch: {
      lastUpdateTime(timestamp) {
        if (!this.consolidatedAppData?.powerState?.on || !this.instanceId) return
        const metric = this.getAppMetric(this.instanceId, 'memory')
        const memory = metric ? metric.value : 0
        this.memoryHistory = [...this.memoryHistory.slice(1), { timestamp, memory }]
      },
      'consolidatedAppData.powerState.on'(isOn) {
        if (!isOn) {
          const now = Math.round(Date.now() / 1000) * 1000
          this.memoryHistory = Array.from({ length: 7 }, (_, i) => ({ timestamp: now + (i - 6) * 10000, memory: 0 }))
        }
      },
    },

    methods: {
      async onFetchSignatures() {
        // TODO : Implement the logic to fetch signatures
      },
    },
  }
</script>
