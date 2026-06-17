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
  import { WebFilter, UAppStatusRemove, webFilterAllTabs } from 'vuntangle'
  import { VDivider } from 'vuetify/lib'
  import appMixin from '../appMixin'
  import { ngfwCapabilities } from './capabilities'

  export default {
    name: 'WebFilterApp',

    components: { WebFilter, UAppStatusRemove, VDivider },

    mixins: [appMixin],

    provide() {
      return {
        capabilities: ngfwCapabilities,
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
      // Transforms appData into the format expected by WebFilter and its child components.
      consolidatedAppData: appInstance => appInstance.buildConsolidatedAppData(),

      isExpertMode: ({ $store }) => $store.getters['config/isExpertMode'],
    },
  }
</script>
