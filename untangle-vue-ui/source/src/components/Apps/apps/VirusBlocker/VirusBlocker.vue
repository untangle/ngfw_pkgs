<template>
  <virus-blocker
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
  </virus-blocker>
</template>

<script>
  import { VirusBlocker } from 'vuntangle'
  import appMixin from '../appMixin'

  export default {
    name: 'VirusBlockerApp',

    components: { VirusBlocker },

    mixins: [appMixin],

    props: {
      appData: { type: Object, default: null },
    },

    data() {
      return {
        appName: this.appData?.appName || 'virus-blocker',
        isFileScannerAvailable: false,
        lastSignatureUpdate: null,
      }
    },

    computed: {
      // Display name for the app, falling back to a default if not provided in appData.
      appDisplayName: ({ appData }) => appData?.appProperties?.displayName || 'Virus Blocker',

      // Consolidated app data to pass to the VirusBlocker component,
      // including additional properties for file scanner availability and last signature update.
      consolidatedAppData: ({ appData, powerState, lastSignatureUpdate, isFileScannerAvailable }) => {
        return {
          ...appData,
          isFileScannerAvailable,
          lastSignatureUpdate,
          powerState: powerState || {},
        }
      },
    },

    watch: {
      // Watcher for appManager from appMixin to trigger fetching of virus-blocker specific data when the manager becomes available.
      appManager: {
        async handler(manager) {
          if (!manager) return
          await this.fetchVirusBlockerData()
        },
      },
    },

    methods: {
      /**
       * Fetches virus-blocker specific data such as file scanner availability and last signature update time from the app manager.
       * This method is called when the appManager becomes available, and updates the component's data properties accordingly.
       */
      async fetchVirusBlockerData() {
        if (!this.appManager) return

        const [isAvailable, lastUpdate] = await Promise.all([
          new Promise(resolve => {
            this.appManager.isFileScannerAvailable((res, ex) => resolve(ex ? false : res))
          }),
          new Promise(resolve => {
            this.appManager.getLastSignatureUpdate((res, ex) => resolve(ex ? null : res))
          }),
        ])

        this.isFileScannerAvailable = isAvailable
        this.lastSignatureUpdate = lastUpdate
      },

      /**
       * Refreshes the app data by calling the refreshData method from appMixin and then fetching the latest virus-blocker specific data.
       * This method is triggered when the user clicks the "Refresh" button in the UI, ensuring that all displayed information is up to date.
       */
      refreshData() {
        appMixin.methods.refreshData.call(this)
        this.fetchVirusBlockerData()
      },
    },
  }
</script>
