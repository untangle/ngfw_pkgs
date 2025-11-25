<template>
  <appliance-logging
    :base64-decode-logs="false"
    :native-export="false"
    :log-prop="logs"
    :tabs="['uvm']"
    @tab-switched="onLogsTabChanged"
    @on-reload="onReload"
    @on-export="onExportLogs"
  />
</template>
<script>
  import { ApplianceLogging } from 'vuntangle'
  import util from '@/util/util'

  /**
   * This component serves as a wrapper for the generic `ApplianceLogging` component.
   * It configures the component for the specific needs of the NGFW System | Logging page.
   *
   * - `tabs` is set to `['uvm']` because this is the only log type required here.
   * - `base64-decode-logs` is `false` because the NGFW API provides raw log text.
   * - `native-export` is `false` because NGFW uses a specific API endpoint for log exporting,
   *   so the component emits an `on-export` event which is handled by `onExportLogs()`.
   */
  export default {
    components: { ApplianceLogging },
    data() {
      return {
        logs: null,
      }
    },
    /**
     * Fetches the initial 'uvm' log when the component is created.
     */
    async created() {
      await this.$store.dispatch('settings/getLogsByName', { logName: 'uvm', refetch: true })
      this.logs = this.$store.getters['settings/getLogsByName']('uvm')
    },

    methods: {
      /**
       * Handles the `tab-switched` event from ApplianceLogging.
       * Fetches the logs for the newly selected tab. Get logs from store rather than fetching from API.
       * @param {String} tabName - The name of the tab that was switched to.
       */
      async onLogsTabChanged(tabName) {
        try {
          await this.$store.dispatch('settings/getLogsByName', { logName: tabName, refetch: false })
          this.logs = this.$store.getters['settings/getLogsByName'](tabName)
          return { success: true }
        } catch (ex) {
          util.handleException(ex)
          return { success: false }
        }
      },
      /**
       * Handles the `on-reload` event from ApplianceLogging.
       * Forces a refetch of the logs for the current tab.
       * @param {String} tabName - The name of the current tab to reload.
       */
      async onReload(tabName) {
        try {
          await this.$store.dispatch('settings/getLogsByName', { logName: tabName, refetch: true })
          this.logs = this.$store.getters['settings/getLogsByName'](tabName)
          return { success: true }
        } catch (ex) {
          util.handleException(ex)
          return { success: false }
        }
      },

      /*
       * Export system logs handler
       */
      /**
       * Handles the `on-export` event from ApplianceLogging.
       * Triggers a download of the system support logs via a specific API endpoint.
       */
      async onExportLogs() {
        try {
          await util.downloadFile('/admin/download', {
            type: 'SystemSupportLogs',
          })
          return { success: true }
        } catch (ex) {
          util.handleException(ex)
          this.$vuntangle.toast.add(this.$vuntangle.$t('export_failed_try_again'), 'error')
          return { success: false }
        }
      },
    },
  }
</script>
