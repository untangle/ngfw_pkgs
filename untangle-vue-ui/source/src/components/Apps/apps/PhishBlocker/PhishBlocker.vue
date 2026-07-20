<template>
  <phish-blocker
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
  </phish-blocker>
</template>

<script>
  import { PhishBlocker, UAppStatusRemove } from 'vuntangle'
  import { VDivider } from 'vuetify/lib'
  import appMixin from '../appMixin'

  export default {
    name: 'PhishBlockerApp',

    components: { PhishBlocker, UAppStatusRemove, VDivider },

    mixins: [appMixin],

    props: {
      appData: { type: Object, default: null },
    },

    data() {
      return {
        appName: this.appData?.appName || 'phish-blocker',
        defaultDisplayName: 'Phish Blocker',
        lastUpdate: null,
      }
    },

    computed: {
      // Consolidated app data to pass to the PhishBlocker component,
      // including the lastUpdate timestamp.
      consolidatedAppData: appInstance => appInstance.buildConsolidatedAppData({ lastUpdate: appInstance.lastUpdate }),
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
