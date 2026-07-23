<template>
  <firewall
    :settings="settings"
    :app-data="consolidatedAppData"
    :metrics-data="formattedMetrics"
    :reports="appReports"
    @toggle-state="toggleAppState"
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
  </firewall>
</template>

<script>
  import { Firewall, UAppStatusRemove } from 'vuntangle'
  import { VDivider } from 'vuetify/lib'
  import appMixin from '../appMixin'

  export default {
    name: 'FirewallApp',

    components: {
      Firewall,
      UAppStatusRemove,
      VDivider,
    },

    mixins: [appMixin],

    props: {
      appData: { type: Object, default: null },
    },

    data() {
      return {
        appName: this.appData?.appName || 'firewall',
        defaultDisplayName: 'Firewall',
      }
    },

    computed: {
      consolidatedAppData: appInstance => appInstance.buildConsolidatedAppData(),
    },
  }
</script>
