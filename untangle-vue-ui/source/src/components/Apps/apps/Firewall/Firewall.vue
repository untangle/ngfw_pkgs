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
  import conditionDataMixin from '../conditionDataMixin'
  import util from '@/util/util'

  export default {
    name: 'FirewallApp',

    components: {
      Firewall,
      UAppStatusRemove,
      VDivider,
    },

    mixins: [appMixin, conditionDataMixin(['directory-connector'])],

    provide() {
      return {
        $remoteData: () => ({
          interfaces: this.interfaces,
          directoryGroups: this.directoryGroups,
          directoryDomains: this.directoryDomains,
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
        appName: this.appData?.appName || 'firewall',
        defaultDisplayName: 'Firewall',
      }
    },

    computed: {
      // Get the consolidated app data for the firewall app.
      consolidatedAppData: appInstance => appInstance.buildConsolidatedAppData(),
      // Get the network settings from the store.
      networkSettings: ({ $store }) => $store.getters['config/networkSetting'],
      // Get the list of interfaces from the network settings.
      interfaces: ({ networkSettings }) => util.getInterfaceList(networkSettings, true, true),
      // Get the expert mode status from the store.
      isExpertMode: ({ $store }) => $store.getters['config/isExpertMode'],
    },

    /**
     * Get the network settings when the component is created.
     */
    created() {
      this.$store.dispatch('config/getNetworkSettings', false)
    },
  }
</script>
