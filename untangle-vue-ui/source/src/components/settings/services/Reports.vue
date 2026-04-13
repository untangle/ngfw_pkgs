<template>
  <v-container fluid :class="`shared-cmp d-flex flex-column flex-grow-1 pa-0`">
    <reports-app
      :settings="settings"
      :app-data="consolidatedAppData"
      :report-queue-size="reportQueueSize"
      :get-server-time="fetchServerTime"
      :server-tz-offset="serverTzOffset"
      :get-recommended-report-ids="fetchRecommendedReportIds"
      :get-current-applications="fetchCurrentApplications"
      :get-fixed-reports-allow-graphs="fetchFixedReportsAllowGraphs"
      :is-expert-mode="isExpertMode"
      :google-drive-configured="googleDriveConfigured"
      :google-drive-root-path="googleDriveRootPath"
      @save-settings="onSaveSettings"
      @refresh-settings="refreshData"
      @toggle-state="toggleAppState"
      @run-fixed-report="onRunFixedReport"
      @delete-reports="onDeleteReports"
      @configure-google-drive="onConfigureGoogleDrive"
      @upload-file="onUploadFile"
    />
  </v-container>
</template>

<script>
  import { ReportsApp } from 'vuntangle'
  import serviceMixin from './serviceMixin'
  import Rpc from '@/util/Rpc'
  import util from '@/util/util'
  import Util from '@/util/setupUtil'

  export default {
    components: {
      ReportsApp,
    },
    mixins: [serviceMixin],

    data() {
      return {
        licenseNodeName: 'reports',
        reportQueueSize: 0,
      }
    },

    computed: {
      /* Gets the expert mode status from the settings */
      isExpertMode: ({ $store }) => $store.getters['config/isExpertMode'],

      /* Whether Google Drive is currently configured */
      googleDriveConfigured: ({ $store }) => $store.getters['config/isGoogleDriveConnected'],

      /* App-specific Google Drive root path — matches ExtJS getAppSpecificGoogleDrivePath */
      googleDriveRootPath: ({ $store }) => $store.getters['config/googleDriveRootPath'],

      /* Server timezone offset in ms for date picker initialization */
      serverTzOffset: ({ $store }) => $store.getters['config/timeZoneOffset'],

      /* Display name sourced from the app manager, fallback to 'Reports' */
      appDisplayName: ({ appManager }) => appManager?.getAppProperties?.()?.displayName || 'Reports',

      /* Bundles powerState and appDisplayName into the shape expected by u-app-status-state */
      consolidatedAppData: ({ powerState, appDisplayName }) => ({
        powerState: powerState || {},
        appDisplayName,
      }),
    },

    created() {
      this.pollQueueSize()
      this.$store.dispatch('config/getTimeZoneOffSet')
      this.$store.dispatch('config/getIsGoogleDriveConnected')
      this.$store.dispatch('config/getGoogleDriveRootPath')
    },

    /* clear poll timer on component destroy to prevent memory leaks */
    beforeDestroy() {
      if (this._queuePollTimer) {
        clearTimeout(this._queuePollTimer)
        this._queuePollTimer = null
      }
    },

    methods: {
      /**
       * Refresh app settings and re-check Google Drive status.
       * Overrides serviceMixin.refreshData to ensure the Data tab reflects the latest
       * Drive connection state after the user configures Google Drive in Administration
       * and returns to this panel.
       */
      refreshData() {
        this.loadAppSettings()
        this.$store.dispatch('config/getIsGoogleDriveConnected')
        this.$store.dispatch('config/getGoogleDriveRootPath')
      },

      /* returns current server time in ms */
      fetchServerTime: () => util.getMilliseconds(),

      /* fetches the reports manager instance via the reports app */
      async fetchReportsManager() {
        const reportsApp = this.appManager || (await Rpc.asyncData('rpc.appManager.app', 'reports'))
        return Rpc.asyncData(reportsApp, 'getReportsManager')
      },

      /* returns list of recommended report IDs from the reports manager */
      async fetchRecommendedReportIds() {
        const reportsManager = await this.fetchReportsManager()
        const result = await Rpc.asyncData(reportsManager, 'getRecommendedReportIds')
        return result?.list || []
      },

      /* returns list of currently active applications from the reports manager */
      async fetchCurrentApplications() {
        const reportsManager = await this.fetchReportsManager()
        const result = await Rpc.asyncData(reportsManager, 'getCurrentApplications')
        return result?.list || []
      },

      /* returns whether fixed reports are allowed to display graphs */
      async fetchFixedReportsAllowGraphs() {
        const reportsManager = await this.fetchReportsManager()
        return Rpc.asyncData(reportsManager, 'fixedReportsAllowGraphs')
      },
      /**
       * Handle save settings event from the Reports component
       * @param {Object} payload - The payload object containing new settings
       * @param {Object} payload.newSettings - The updated settings object to save
       */
      async onSaveSettings({ newSettings }) {
        await this.saveSettings(newSettings)
      },

      /**
       * Run a fixed report for the given template and date range,
       * then fetch the queue size and start polling until the queue drains.
       */
      async onRunFixedReport({ templateId, startDate, stopDate }) {
        this.$store.commit('SET_LOADER', true)
        try {
          const { success } = await this.$store.dispatch('apps/runFixedReport', { templateId, startDate, stopDate })
          if (success) {
            this.reportQueueSize = await this.fetchQueueSize()
            this.startQueuePolling()
          }
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      /** Start a 5-second poll loop if one is not already running. */
      startQueuePolling() {
        if (this._queuePollTimer) return
        this._queuePollTimer = setTimeout(() => this.pollQueueSize(), 5000)
      },

      /** Fetch the current fixed report queue size from the app manager. */
      async fetchQueueSize() {
        const appManager = this.appManager || (await Rpc.asyncData('rpc.appManager.app', 'reports'))
        return Rpc.asyncData(appManager, 'getFixedReportQueueSize')
      },

      /** Poll the queue size every 5 seconds until it reaches 0. */
      async pollQueueSize() {
        this._queuePollTimer = null
        try {
          this.reportQueueSize = await this.fetchQueueSize()
          if (this.reportQueueSize > 0) {
            this._queuePollTimer = setTimeout(() => this.pollQueueSize(), 5000)
          }
        } catch {
          this.reportQueueSize = 0
        }
      },

      /**
       * Handle delete-reports event from the Data tab.
       * Calls reinitializeDatabase via RPC and reports success via cb.
       */
      async onDeleteReports({ cb }) {
        this.$store.commit('SET_LOADER', true)
        let succeeded = false
        try {
          const reportsManager = await this.fetchReportsManager()
          await Rpc.asyncData(reportsManager, 'reinitializeDatabase')
          succeeded = true
        } catch (ex) {
          Util.handleException(ex)
        } finally {
          cb(succeeded)
          this.$store.commit('SET_LOADER', false)
        }
      },

      /**
       * Handle configure-google-drive event from the Data tab.
       * Navigates to the Administration page where Google Drive is configured.
       */
      onConfigureGoogleDrive() {
        this.$router.push('/settings/system/administration?tab=google')
      },

      /**
       * Handle upload-file event from the Data tab.
       * Uploads the reports data backup file to the server and reports success via cb.
       * @param {Object} payload - { file: File, type: string, cb: Function }
       */
      async onUploadFile({ file, type, cb }) {
        this.$store.commit('SET_LOADER', true)
        let succeeded = false
        try {
          const response = await util.uploadFile('/admin/upload', { filename: file, type })
          succeeded = !!response?.success
        } catch (error) {
          Util.handleException(error)
        } finally {
          cb(succeeded)
          this.$store.commit('SET_LOADER', false)
        }
      },
    },
  }
</script>
