<template>
  <application-control-lite
    :settings="settings"
    :app-data="consolidatedAppData"
    :sessions-data="sessionsData"
    :metrics-data="formattedMetrics"
    :reports="appReports"
    @toggle-state="toggleAppState"
    @remove-app="removeApp"
  >
    <!-- Custom action buttons slot -->
    <template #actions="{ newSettings, isDirty }">
      <u-btn class="mr-2" @click="refreshData">
        {{ $t('refresh') }}
      </u-btn>
      <u-btn :disabled="!isDirty || saveDisabled" @click="saveSettings(newSettings)">
        {{ $t('save') }}
      </u-btn>
    </template>
  </application-control-lite>
</template>

<script>
  import { ApplicationControlLite } from 'vuntangle'
  import appMixin from '../appMixin'
  import Rpc from '@/util/Rpc'

  export default {
    name: 'ApplicationControlLiteApp',

    components: {
      ApplicationControlLite,
    },

    mixins: [appMixin],

    props: {
      appData: { type: Object, default: null },
    },

    data() {
      return {
        appName: this.appData?.appName || 'application-control-lite',
        learnMoreUrl: undefined,
      }
    },

    computed: {
      /**
       * Application display name, derived from appData properties or defaults to a static string
       * @param param0 - Destructured appData from component's props
       * @returns {string} Display name for the application
       */
      appDisplayName: ({ appData }) => appData?.appProperties?.displayName || 'Application Control Lite',

      /**
       * Consolidates app data with additional properties like learnMoreUrl and powerState
       * @param param0 - Destructured properties including appData, learnMoreUrl, and powerState
       * @returns {Object} Consolidated app data object to be passed to the component
       */
      consolidatedAppData: ({ appData, learnMoreUrl, powerState }) => {
        return {
          ...appData,
          learnMoreUrl,
          powerState: powerState || {},
        }
      },
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
