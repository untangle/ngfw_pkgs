<template>
  <application-control-lite
    :settings="settings"
    :app-data="consolidatedAppData"
    :sessions-data="sessionsData"
    :metrics-data="formattedMetrics"
    :reports="appReports"
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
  </application-control-lite>
</template>

<script>
  import { ApplicationControlLite, UAppStatusRemove } from 'vuntangle'
  import { VDivider } from 'vuetify/lib'
  import appMixin from '../appMixin'
  import Rpc from '@/util/Rpc'

  export default {
    name: 'ApplicationControlLiteApp',

    components: {
      ApplicationControlLite,
      UAppStatusRemove,
      VDivider,
    },

    mixins: [appMixin],

    props: {
      appData: { type: Object, default: null },
    },

    data() {
      return {
        appName: this.appData?.appName || 'application-control-lite',
        defaultDisplayName: 'Application Control Lite',
        learnMoreUrl: undefined,
      }
    },

    computed: {
      // Consolidated app data to pass to the ApplicationControlLite component,
      // including the learnMoreUrl for the shop link.
      consolidatedAppData: appInstance =>
        appInstance.buildConsolidatedAppData({ learnMoreUrl: appInstance.learnMoreUrl }),
    },

    created() {
      this.fetchLearnMoreUrl()
    },

    methods: {
      /**
       * Fetches the "Learn More" URL for the application from the backend via RPC
       * If the RPC call fails, it falls back to a default URL
       */
      async fetchLearnMoreUrl() {
        const defaultUrl = 'https://edge.arista.com/shop/Application-Control'
        this.learnMoreUrl = await Rpc.asyncData('rpc.uriManager.getUriWithPath', defaultUrl).catch(() => defaultUrl)
      },
    },
  }
</script>
