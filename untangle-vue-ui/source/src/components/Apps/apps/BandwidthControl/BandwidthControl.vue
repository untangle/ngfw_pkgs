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
  >
    <!-- Custom action buttons slot -->
    <template #actions="{ newSettings, isDirty }">
      <div class="d-flex flex-wrap align-center" style="gap: 8px">
        <div style="min-width: 180px">
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
  import { BandwidthControl, UAppStatusRemove } from 'vuntangle'
  import { VDivider } from 'vuetify/lib'
  import appMixin from '../appMixin'

  export default {
    name: 'BandwidthControlApp',

    components: { BandwidthControl, UAppStatusRemove, VDivider },

    mixins: [appMixin],

    props: {
      appData: { type: Object, default: null },
    },

    data() {
      return {
        appName: this.appData?.appName || 'bandwidth-control',
        defaultDisplayName: 'Bandwidth Control',
      }
    },

    computed: {
      consolidatedAppData: appInstance => appInstance.buildConsolidatedAppData(),
      isConfigured: ({ settings }) => !!settings?.configured,
      networkSettings: ({ $store }) => $store.getters['config/networkSetting'],
      qosEnabled: ({ networkSettings }) => !!networkSettings?.qosSettings?.qosEnabled,
      wanInterfaces: ({ networkSettings }) =>
        (networkSettings?.interfaces || []).filter(iface => iface.wan && iface.configType === 'ADDRESSED'),
    },
  }
</script>
