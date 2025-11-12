<template>
  <v-container fluid :class="`shared-cmp d-flex flex-column flex-grow-1 pa-2`">
    <no-license v-if="isLicensed === false" class="mt-2">
      {{ $t('not_licensed_service', [$t('dynamic_blocklist')]) }}
      <template #actions>
        <u-btn class="ml-4" to="/settings/system/about">{{ $t('view_system_license') }}</u-btn>
        <u-btn class="ml-4" :href="manageLicenseUri" target="_blank">
          {{ $t('manage_licenses') }}
          <v-icon right> mdi-open-in-new </v-icon>
        </u-btn>
      </template>
    </no-license>

    <settings-dynamic-block-lists
      v-if="dynamicListsSettings"
      :settings="dynamicListsSettings"
      :status="status"
      :disabled="!isLicensed"
      @update-settings="onSave"
      @delete-configuration="onDeleteConfiguration"
      @download="onDownload"
      @refresh="fetchStatus"
      @download-csv="initiateDownload"
    >
      <template #actions="{ newSettings, disabled, isDirty }">
        <u-btn :disabled="disabled" class="mr-2" @click="onResetDefaults">
          {{ $vuntangle.$t('reset_to_defaults') }}
        </u-btn>
        <u-btn :disabled="disabled || !isDirty" @click="onSave(newSettings)">
          {{ $vuntangle.$t('save') }}
        </u-btn>
      </template>
    </settings-dynamic-block-lists>
  </v-container>
</template>

<script>
  import { SettingsDynamicBlockLists, NoLicense } from 'vuntangle'
  import serviceMixin from './serviceMixin'
  import vuntangle from '@/plugins/vuntangle'
  import { EVENT_ACTIONS } from '@/constants/actions'
  import { sendEvent } from '@/utils/event'

  export default {
    components: {
      SettingsDynamicBlockLists,
      NoLicense,
    },
    mixins: [serviceMixin],
    data() {
      return {
        licenseNodeName: 'dynamic-blocklists',
        status: [],
      }
    },
    computed: {
      dynamicListsSettings: ({ $store }) => $store.getters['apps/getSettings']('dynamic-blocklists'),
    },
    created() {
      this.$store.dispatch('apps/getAndCommitAppSettings', this.licenseNodeName)
    },
    mounted() {
      this.fetchStatus()
    },

    methods: {
      /**
       * Fetches the status for the dynamic lists and
       * formats the timestamp of each configuration to human readabale values
       */
      async fetchStatus() {
        this.$store.commit('SET_LOADER', true)
        try {
          const response = await window.rpc.appManager.app('dynamic-blocklists').status()
          this.status = response || []
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      /** Resets the dynamic blocklists to its default configuration */
      onResetDefaults() {
        this.$vuntangle.confirm.show({
          title: this.$vuntangle.$t('confirm'),
          message: this.$vuntangle.$t('dynamic_blocklist_reset_warning'),
          action: async resolve => {
            this.$store.commit('SET_LOADER', true)
            try {
              const response = await window.rpc.appManager.app('dynamic-blocklists').onResetDefaultsV2()

              if (response?.success !== false) {
                await this.$store.dispatch('apps/getAndCommitAppSettings', this.licenseNodeName)
                sendEvent({
                  type: EVENT_ACTIONS.REFRESH_APP_STATUS,
                  appName: 'dynamic-blocklists',
                  targetState: 'INITIALIZED',
                })
              } else {
                this.$vuntangle.toast.add(this.$t('rolled_back_settings', [response.message]), 'error')
              }
            } finally {
              this.$store.commit('SET_LOADER', false)
              resolve()
            }
          },
        })
      },

      /**
       * dispatches action to save the updated dynamic list
       * @param {Object} newSettings - new settings to be saved
       */
      async onSave(newSettings) {
        this.$store.commit('SET_LOADER', true)
        try {
          const response = await this.$store.dispatch('apps/setAppSettings', {
            appName: 'dynamic-blocklists',
            settings: newSettings,
          })
          if (!response.success) {
            this.$vuntangle.toast.add(this.$t('rolled_back_settings', [response.message]))
            return
          }

          const targetState = newSettings.enabled ? 'RUNNING' : 'INITIALIZED'
          sendEvent({
            type: EVENT_ACTIONS.REFRESH_APP_STATUS,
            appName: 'dynamic-blocklists',
            targetState,
          })
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      /**
       * Handler for `delete-configuration` event, removing that configuration from settings
       * @param {String} configurationId -  id of blocklist row
       */
      async onDeleteConfiguration(configurationId) {
        this.$store.commit('SET_LOADER', true)
        try {
          const currentSettings = this.dynamicListsSettings
          const updatedConfSettings = currentSettings.configurations.filter(config => config.id !== configurationId)

          const newSettings = {
            ...currentSettings,
            configurations: updatedConfSettings,
          }

          const response = await this.$store.dispatch('apps/setAppSettings', {
            appName: 'dynamic-blocklists',
            settings: newSettings,
          })

          if (!response.success) {
            this.$vuntangle.toast.add(this.$t('an_error_occurred'), 'error')
          }
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      /**
       * Handler for `download` event
       * @param {String[]} configurationIds - UUIDs of the configurations to be refreshed
       */
      async onDownload(configurationIds) {
        this.$store.commit('SET_LOADER', true)
        try {
          const response = await window.rpc.appManager.app('dynamic-blocklists').runJobsByConfigIdsV2(configurationIds)
          await this.fetchStatus()

          if (response?.success !== false) {
            await this.$store.dispatch('apps/getAndCommitAppSettings', this.licenseNodeName)
          } else {
            this.$vuntangle.toast.add(this.$vuntangle.$t('download_blocklist_to_appliance_failure'), 'error')
          }
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },
      /**
       * Handler for `download-csv` event
       * that fetches the ip list and than saves it to local CSV file
       * @param {Array} configurationId - id of blocklist row
       */
      async initiateDownload(configurationId) {
        this.$store.commit('SET_LOADER', true)
        try {
          const response = await window.rpc.appManager.app('dynamic-blocklists').exportCsvV2(configurationId)

          if (!response || response.length === 0) {
            this.$vuntangle.toast.add(this.$vuntangle.$t('export_failed'), 'error')
            return
          }

          vuntangle.util.processDynamicListDownload(`block-list-${configurationId}.csv`, response)
        } catch (error) {
          this.$vuntangle.toast.add(this.$vuntangle.$t('export_failed'), 'error')
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },
    },
  }
</script>
