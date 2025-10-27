<template>
  <appliance-system
    :system-settings="systemSettings"
    :http-settings="httpSettings"
    :ftp-settings="ftpSettings"
    :smtp-settings="smtpSettings"
    :is-expert-mode="isExpertMode"
    :company-name="companyName"
    :system-time-zones="systemTimeZones"
    :show-remote-support="true"
    :support-access-enabled="true"
    :all-wan-interface-names="enabledWanInterfaces"
    @save-settings="onSaveSettings"
    @force-time-sync="onForceTimeSync"
    @factory-reset="onFactoryReset"
    @reboot="onReboot"
    @shutdown="onShutdown"
    @refresh-settings="onRefreshSettings"
    @export-backup="onExportBackup"
    @restore-backup="onRestoreBackup"
  />
</template>
<script>
  import { ApplianceSystem } from 'vuntangle'
  import settingsMixin from '../settingsMixin'
  import util from '@/util/util'
  import Util from '@/util/setupUtil'

  export default {
    components: { ApplianceSystem },
    mixins: [settingsMixin],

    computed: {
      systemSettings: ({ $store }) => $store.getters['settings/systemSetting'],
      httpSettings: ({ $store }) => $store.getters['apps/getSettings']('http'),
      ftpSettings: ({ $store }) => $store.getters['apps/getSettings']('ftp'),
      smtpSettings: ({ $store }) => $store.getters['apps/getSettings']('smtp'),
      isExpertMode: ({ $store }) => $store.getters['settings/isExpertMode'],
      systemTimeZones: ({ $store }) => $store.getters['settings/systemTimeZones'],
      networkSetting: ({ $store }) => $store.getters['settings/networkSetting'],
      enabledWanInterfaces: ({ $store }) => $store.getters['settings/enabledWanInterfaces'],
      companyName() {
        return window?.rpc?.companyName || null
      },
    },
    created() {
      // update current system setting from store store
      this.$store.dispatch('settings/getSystemSettings', false)
      this.$store.dispatch('apps/getAndCommitAppSettings', 'http')
      this.$store.dispatch('apps/getAndCommitAppSettings', 'smtp')
      this.$store.dispatch('apps/getAndCommitAppSettings', 'ftp')
      // get list of all wan interfaces which is used to show in the hostname interface selection
      this.$store.dispatch('settings/getEnabledInterfaces')
      this.$store.dispatch('settings/getSystemTimeZones')
    },

    methods: {
      /*
       * Saving system changes with particular tab
       * This function commonly used saving all settings configurations
       */
      async onSaveSettings({ system, cb }) {
        this.$store.commit('SET_LOADER', true)
        const response = await this.$store.dispatch('settings/setSystemSettings', system)
        await this.$store.dispatch('apps/setAppSettings', {
          appName: 'http',
          settings: system.httpSettings,
        })
        await this.$store.dispatch('apps/setAppSettings', {
          appName: 'ftp',
          settings: system.ftpSettings,
        })
        await this.$store
          .dispatch('apps/setAppSettings', {
            appName: 'smtp',
            settings: system.smtpSettings,
          })
          .finally(() => this.$store.commit('SET_LOADER', false))
        cb(response.success)
      },

      /* Handler to sync time via ntp */
      async onForceTimeSync() {
        this.$store.commit('SET_LOADER', true)
        const response = await this.$store
          .dispatch('settings/doForceTimeSync')
          .finally(() => this.$store.commit('SET_LOADER', false))
        if (!response.success) {
          this.$vuntangle.toast.add(this.$vuntangle.$t('force_time_sync_failed'), 'error')
        }
      },

      /*
       * Factory resset handler
       */
      async onFactoryReset() {
        this.$store.commit('SET_LOADER', true)
        await new Promise(resolve => setTimeout(resolve, 1000))
        this.$store.commit('SET_LOADER', false)
        document.location.href = '/error/factoryDefaults'
        await this.$store.dispatch('settings/factoryReset')
      },

      /*
       * System reboot handler
       */
      async onReboot() {
        await this.$store.dispatch('settings/reboot')
      },

      /*
       * System reboot handler
       */
      async onShutdown() {
        await this.$store.dispatch('settings/shutdown')
      },

      /*
       * Backup restore handler
       */
      async onRestoreBackup(data) {
        try {
          const response = await util.uploadFile('/admin/v2/upload', data.restoreData)
          data.cbWithRes(response)
        } catch (ex) {
          Util.handleException(ex)
          data.cb(ex)
        }
      },

      /*
       * Export backup file handler
       */
      async onExportBackup() {
        try {
          await util.downloadFile('/admin/download', {
            type: 'backup',
          })
          return { success: true }
        } catch (ex) {
          util.handleException(ex)
          this.$vuntangle.toast.add(this.$vuntangle.$t('export_failed_try_again'), 'error')
          return { success: false }
        }
      },

      /* Handler to refresh settings */
      async onRefreshSettings() {
        this.$store.commit('SET_LOADER', true)

        const [response] = await Promise.all([
          this.$store.dispatch('settings/getSystemSettings', true),
          this.$store.dispatch('settings/getEnabledInterfaces'),
          this.$store.dispatch('settings/getSystemTimeZones'),
        ]).finally(() => {
          this.$store.commit('SET_LOADER', false)
        })
        if (!response.success) {
          this.$vuntangle.toast.add(this.$vuntangle.$t('error_refresh_settings'), 'error')
        }
      },

      /**
       * Optional hook triggered on browser refresh.
       * Fetches updated system settings and updates the store.
       */
      onBrowserRefresh() {
        this.$store.dispatch('settings/getSystemSettings', true)
      },
    },
  }
</script>
