<template>
  <web-filter
    :settings="settings"
    :app-data="consolidatedAppData"
    :tabs="webFilterAllTabs"
    :sessions-data="sessionsData"
    :metrics-data="formattedMetrics"
    :reports="appReports"
    @toggle-state="toggleAppState"
  >
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
  </web-filter>
</template>

<script>
  import { WebFilter, UAppStatusRemove, webFilterDefaultCapabilities, webFilterAllTabs } from 'vuntangle'
  import { VDivider } from 'vuetify/lib'
  import appMixin from '../appMixin'

  export default {
    name: 'WebFilterApp',

    components: { WebFilter, UAppStatusRemove, VDivider },

    mixins: [appMixin],

    provide() {
      return {
        capabilities: {
          ...webFilterDefaultCapabilities,
          main: {
            policyManagerAlert: { render: false },
            enableToggle: { render: false },
            appIcon: { render: true },
            powerStatus: { render: true },
            description: { render: true, key: 'app_web_filter_description' },
          },
        },
        $features: { isExpertMode: this.isExpertMode },
        $readOnly: false,
        $applications: {},
      }
    },

    props: {
      appData: { type: Object, default: null },
    },

    data() {
      return {
        appName: this.appData?.appName || 'web-filter',
        defaultDisplayName: 'Web Filter',
        webFilterAllTabs,
      }
    },

    computed: {
      consolidatedAppData: appInstance => appInstance.buildConsolidatedAppData(),
      isExpertMode: ({ $store }) => $store.getters['config/isExpertMode'],
    },
  }
</script>
