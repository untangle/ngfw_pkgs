<template>
  <appliance-system
    :system-settings="systemSettings"
    :device-temperature-info="deviceTemperatureInfo"
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
    @refresh-device-temperature-info="onRefreshDeviceTemperatureInfo"
    @force-time-sync="onForceTimeSync"
    @language-sync="onLanguageSync"
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
  import Rpc from '@/util/Rpc'

  export default {
    components: { ApplianceSystem },
    mixins: [settingsMixin],
    inject: ['embedded'],

    computed: {
      systemSettings: ({ $store }) => $store.getters['config/systemSetting'],
      deviceTemperatureInfo: ({ $store }) => $store.getters['config/deviceTemperatureInfo'],
      httpSettings: ({ $store }) => $store.getters['apps/getSettings']('http')?.settings || {},
      ftpSettings: ({ $store }) => $store.getters['apps/getSettings']('ftp')?.settings || {},
      smtpSettings: ({ $store }) => $store.getters['apps/getSettings']('smtp')?.settings || {},
      isExpertMode: ({ $store }) => $store.getters['config/isExpertMode'],
      systemTimeZones: ({ $store }) => $store.getters['config/systemTimeZones'],
      networkSetting: ({ $store }) => $store.getters['config/networkSetting'],
      enabledWanInterfaces: ({ $store }) => $store.getters['config/enabledWanInterfaces'],
      companyName() {
        return window?.rpc?.companyName || null
      },
    },

    watch: {
      'systemSettings.languageSettings.language': {
        handler(newValue, oldValue) {
          if (newValue && oldValue && newValue !== oldValue && newValue.split('-').length === 2) {
            this.$i18n.setLocale(newValue.split('-')[1])
            if (this.embedded) window.top.location.reload()
          }
        },
      },
    },

    async created() {
      await this.$store.dispatch('withLoader', {
        needsRaf: true,
        asyncFn: async () => {
          // update current system setting from store
          await Promise.all([
            this.$store.dispatch('config/getSystemSettings', false),
            this.$store.dispatch('config/getDeviceTemperatureInfo'),
            this.$store.dispatch('apps/loadAppData', 'http'),
            this.$store.dispatch('apps/loadAppData', 'smtp'),
            this.$store.dispatch('apps/loadAppData', 'ftp'),
            // get list of all wan interfaces which is used to show in the hostname interface selection
            this.$store.dispatch('config/getEnabledInterfaces'),
            this.$store.dispatch('config/getSystemTimeZones'),
          ])
        },
      })
    },

    methods: {
      /*
       * Saving system changes with particular tab
       * This function commonly used saving all settings configurations
       */
      async onSaveSettings({ system, cb }) {
        this.$store.commit('SET_LOADER', true)
        const response = await this.$store.dispatch('config/setSystemSettings', system)
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
          .dispatch('config/doForceTimeSync')
          .finally(() => this.$store.commit('SET_LOADER', false))
        if (!response.success) {
          this.$vuntangle.toast.add(this.$vuntangle.$t('force_time_sync_failed'), 'error')
        }
      },

      /* Handler to synchronize language */
      onLanguageSync() {
        this.$store.commit('SET_LOADER', true)
        Rpc.asyncData('rpc.languageManager.synchronizeLanguage')
          .then(function () {
            window.location.reload()
          })
          .finally(() => {
            this.$store.commit('SET_LOADER', false)
          })
      },

      /*
       * Factory resset handler
       */
      async onFactoryReset() {
        this.$store.commit('SET_LOADER', true)
        await new Promise(resolve => setTimeout(resolve, 1000))
        this.$store.commit('SET_LOADER', false)
        document.location.href = '/error/factoryDefaults'
        await this.$store.dispatch('config/factoryReset')
      },

      /*
       * System reboot handler
       */
      async onReboot() {
        await this.$store.dispatch('config/reboot')
      },

      /*
       * Device temperature refresh handler
       */
      async onRefreshDeviceTemperatureInfo() {
        await this.$store.dispatch('config/getDeviceTemperatureInfo')
      },

      /*
       * System reboot handler
       */
      async onShutdown() {
        await this.$store.dispatch('config/shutdown')
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
        const [response] = await this.$store.dispatch('withLoader', {
          needsRaf: true,
          asyncFn: async () => {
            return await Promise.all([
              this.$store.dispatch('config/getSystemSettings', true),
              this.$store.dispatch('config/getEnabledInterfaces'),
              this.$store.dispatch('config/getSystemTimeZones'),
            ])
          },
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
        this.$store.dispatch('config/getSystemSettings', true)
      },
    },
  }
</script>
