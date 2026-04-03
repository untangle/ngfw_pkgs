<template>
  <phish-blocker
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
  </phish-blocker>
</template>

<script>
  import { PhishBlocker } from 'vuntangle'
  import appMixin from '../appMixin'

  export default {
    name: 'PhishBlockerApp',

    components: { PhishBlocker },

    mixins: [appMixin],

    props: {
      appData: { type: Object, default: null },
    },

    data() {
      return {
        appName: this.appData?.appName || 'phish-blocker',
        lastUpdate: null,
      }
    },

    computed: {
      // Display name for the app, falling back to a default if not provided in appData.
      appDisplayName: ({ appData }) => appData?.appProperties?.displayName || 'Phish Blocker',

      // Consolidated app data to pass to the PhishBlocker component,
      // including the lastUpdate timestamp.
      consolidatedAppData: ({ appData, powerState, lastUpdate }) => {
        return {
          ...appData,
          lastUpdate,
          powerState: powerState || {},
        }
      },
    },

    watch: {
      // Watcher for appManager from appMixin to trigger fetching of phish-blocker specific data when the manager becomes available.
      appManager: {
        async handler(manager) {
          if (!manager) return
          await this.fetchPhishBlockerData()
        },
      },
    },

    methods: {
      /**
       * Fetches phish-blocker specific data: last ClamAV signature update time.
       * Called when the appManager becomes available.
       */
      async fetchPhishBlockerData() {
        if (!this.appManager) return

        const lastUpdate = await new Promise(resolve => {
          this.appManager.getLastUpdate((res, ex) => resolve(ex ? null : res))
        })

        this.lastUpdate = lastUpdate
      },

      /**
       * Refreshes the app data and re-fetches phish-blocker specific timestamps.
       */
      refreshData() {
        appMixin.methods.refreshData.call(this)
        this.fetchPhishBlockerData()
      },
    },
  }
</script>
