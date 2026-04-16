<template>
  <v-container fluid :class="`shared-cmp d-flex flex-column flex-grow-1 pa-2`">
    <no-license v-if="!isLicensed" class="mt-2">
      {{ $t('not_licensed_service', [$t('wan_failover')]) }}
      <template #actions>
        <u-btn class="ml-4" to="/settings/system/about">{{ $t('view_system_license') }}</u-btn>
        <u-btn class="ml-4" :href="manageLicenseUri" target="_blank">
          {{ $t('manage_licenses') }}
          <v-icon right> mdi-open-in-new </v-icon>
        </u-btn>
      </template>
    </no-license>
    <wan-failover
      v-if="settings"
      :settings="settings"
      :app-data="consolidatedAppData"
      :metrics-data="formattedMetrics"
      :wan-status-data="wanStatusData"
      :reports="appReports"
      @get-wan-status="getWanStatus"
      @toggle-state="toggleAppState"
    >
      <template #actions="{ newSettings, isDirty }">
        <div class="d-flex flex-wrap align-center" style="gap: 8px">
          <div style="min-width: 180px">
            <u-app-status-remove class="mt-0" service-app app-name="WAN Failover" @remove="onRemoveService" />
          </div>
          <v-divider vertical class="mx-4" />
          <u-btn class="mr-2" @click="refreshData">
            {{ $vuntangle.$t('refresh') }}
          </u-btn>
          <u-btn :disabled="!isDirty" @click="saveSettings(newSettings)">
            {{ $vuntangle.$t('save') }}
          </u-btn>
        </div>
      </template>
    </wan-failover>
  </v-container>
</template>

<script>
  import { WanFailover, NoLicense, UAppStatusRemove } from 'vuntangle'
  import serviceMixin from './serviceMixin'

  export default {
    components: {
      WanFailover,
      NoLicense,
      UAppStatusRemove,
    },
    mixins: [serviceMixin],

    data() {
      return {
        licenseNodeName: 'wan-failover',
        wanStatusData: [],
        pingListData: [],
      }
    },

    computed: {
      appDisplayName: ({ appManager }) =>
        appManager?.getAppProperties?.()?.displayName || this.$vuntangle.$t('wan_failover'),
      consolidatedAppData: ({ powerState, appDisplayName }) => ({
        powerState: powerState || {},
        appDisplayName,
      }),
    },

    created() {
      this.getWanStatus()
    },

    methods: {
      async getWanStatus() {
        const app = await this.$store.dispatch('apps/getApp', { appName: this.licenseNodeName })
        this.wanStatusData = (app.getWanStatus().list || []).filter(item => item.systemName !== null)
      },
    },
  }
</script>
