<template>
  <appliance-logging
    :log-prop="logs"
    @tab-switched="onLogsTabChanged"
    @on-reload="onReload"
    @on-export="onExportLogs"
  />
</template>
<script>
  import { ApplianceLogging } from 'vuntangle'
  import util from '@/util/util'

  export default {
    components: { ApplianceLogging },
    data() {
      return {
        logs: null,
      }
    },
    async created() {
      await this.$store.dispatch('system/getLogsByName', { logName: 'uvm', refetch: true })
      this.logs = this.$store.getters['system/getLogsByName']('uvm')
    },

    methods: {
      async onLogsTabChanged(tabName) {
        try {
          console.log('on tab changed ', tabName)
          await this.$store.dispatch('system/getLogsByName', { logName: tabName, refetch: false })
          this.logs = this.$store.getters['system/getLogsByName'](tabName)
          return { success: true }
        } catch (ex) {
          util.handleException(ex)
          return { success: false }
        }
      },
      async onReload(tabName) {
        try {
          await this.$store.dispatch('system/getLogsByName', { logName: tabName, refetch: true })
          this.logs = this.$store.getters['system/getLogsByName'](tabName)
          return { success: true }
        } catch (ex) {
          util.handleException(ex)
          return { success: false }
        }
      },

      /*
       * Export system logs handler
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
