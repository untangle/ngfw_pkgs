<template>
  <virus-blocker
    :settings="settings"
    :app-data="consolidatedAppData"
    :sessions-data="sessionsData"
    :metrics-data="formattedMetrics"
    :reports="appReports"
    @toggle-state="toggleAppState"
  >
    <!-- Custom action buttons slot -->
    <template #actions="{ newSettings, isDirty, validate }">
      <div class="d-flex flex-wrap align-center" style="gap: 8px">
        <div style="min-width: 180px">
          <u-app-status-remove class="mt-0" :app-name="appDisplayName" @remove="removeApp" />
        </div>
        <v-divider vertical class="mx-4" />
        <u-btn class="mr-2" @click="refreshData">{{ $t('refresh') }}</u-btn>
        <u-btn :disabled="!isDirty || saveDisabled" @click="onSave(newSettings, validate)">{{ $t('save') }}</u-btn>
      </div>
    </template>
  </virus-blocker>
</template>

<script>
  import { VirusBlocker, UAppStatusRemove } from 'vuntangle'
  import { VDivider } from 'vuetify/lib'
  import appMixin from '../appMixin'

  export default {
    name: 'VirusBlockerApp',

    components: { VirusBlocker, UAppStatusRemove, VDivider },

    mixins: [appMixin],

    props: {
      appData: { type: Object, default: null },
    },

    data() {
      return {
        appName: this.appData?.appName || 'virus-blocker',
        defaultDisplayName: 'Virus Blocker',
        isFileScannerAvailable: false,
        lastSignatureUpdate: null,
      }
    },

    computed: {
      // Consolidated app data to pass to the VirusBlocker component,
      // including additional properties for file scanner availability and last signature update.
      consolidatedAppData: appInstance =>
        appInstance.buildConsolidatedAppData({
          isFileScannerAvailable: appInstance.isFileScannerAvailable,
          lastSignatureUpdate: appInstance.lastSignatureUpdate,
        }),
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
      async onSave(newSettings, validate) {
        const isValid = await validate()
        if (!isValid) return
        this.saveSettings(newSettings)
      },

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
