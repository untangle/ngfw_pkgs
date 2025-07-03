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
      :settings="vdynamicLists"
      :status="status"
      :disabled="!isLicensed"
      @download="onDownload"
      @delete-configuration="onDeleteConfiguration"
      @refresh="fetchStatus"
      @download-csv="initiateDownload"
      @update-settings="onEdit"
    >
      <template #actions="{ newSettings, disabled, isDirty }">
        <u-btn
          :disabled="!disabled && !newSettings.enabled && !isBlockListFullyEnabled"
          class="mr-2"
          @click="onResetDefaults"
        >
          {{ $vuntangle.$t('reset_to_defaults') }}
        </u-btn>
        <u-btn
          :disabled="
            !(
              newSettings.enabled ||
              isBlockListFullyEnabled ||
              (newSettings.enabled && isBlockListFullyEnabled && isDirty)
            )
          "
          @click="onSave(newSettings)"
        >
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
  import Util from '@/util/setupUtil'
  export default {
    components: {
      SettingsDynamicBlockLists,
      NoLicense,
    },
    mixins: [serviceMixin],
    data() {
      return {
        licenseNodeName: 'dynamic-blocklists',
        statusList: [],
      }
    },
    computed: {
      dynamicLists: ({ $store }) => $store.getters['settings/dynamicLists'],
      vdynamicLists() {
        const dynamicLists = this.dynamicLists.dynamicLists || {}
        const blockList = dynamicLists.dynamicBlockList?.list || []

        return {
          enabled: dynamicLists.enabled || false,
          configurations: blockList.map(item => ({
            enabled: item.enabled,
            id: item.id,
            name: item.name,
            parsingMethod: item.parsingMethod,
            pollingTime: item.pollingTime,
            pollingUnit: item.pollingUnit,
            skipCertCheck: item.skipCertCheck,
            source: item.source,
            type: item.type,
          })),
        }
      },
      status() {
        const dynamicLists = this.dynamicLists.dynamicLists || {}
        const blockList = dynamicLists.dynamicBlockList?.list || []
        return blockList.map(item => ({
          uuid: item.id,
          last_updated_time: item.lastUpdated,
          num_entries: item.count,
          status: item.status,
        }))
      },
      isBlockListFullyEnabled() {
        return this.dynamicLists.dynamicLists.enabled
      },
    },
    created() {
      this.$store.dispatch('settings/getDynamicBlockList')
    },
    mounted() {
      this.fetchStatus()
    },

    methods: {
      fetchStatus() {
        this.$store.dispatch('settings/getDynamicBlockList')
      },
      /** Resets the dynamic blocklists to its default configuration */
      onResetDefaults() {
        this.$vuntangle.confirm.show({
          title: this.$vuntangle.$t('confirm'),
          message: this.$vuntangle.$t('dynamic_blocklist_reset_warning'),
          action: async resolve => {
            const response = await this.$store.dispatch('settings/getdynamicListsDefaultSettings')
            if (response.success) {
              this.$vuntangle.toast.add(this.$vuntangle.$t('dynamic_blocklist_reset_success'))
            }
            resolve()
          },
        })
      },

      /**
       * dispatches action to save the updated dynamic list
       * @param {Object} newSettings - new settings to be saved
       */
      transformVdynamicToStoreFormat(newSettings) {
        const originalDynamicLists = this.dynamicLists.dynamicLists
        const originalList = originalDynamicLists.dynamicBlockList.list
        const updatedConfigs = newSettings.configurations
        // Merge the updated configurations with original list
        const updatedList = updatedConfigs.map(updatedItem => {
          // Check if the updatedItem exists in the original list
          const originalItem = originalList.find(item => item.name === updatedItem.name)

          if (originalItem) {
            // If originalItem exists, update the properties
            return {
              ...originalItem,
              enabled: updatedItem.enabled,
              parsingMethod: updatedItem.parsingMethod,
              pollingTime: updatedItem.pollingTime,
              pollingUnit: updatedItem.pollingUnit,
              skipCertCheck: updatedItem.skipCertCheck,
              source: updatedItem.source,
              type: updatedItem.type,
            }
          } else {
            // If no original item, it's a new configuration
            return {
              ...updatedItem,
              javaClass: 'com.untangle.app.dynamic_blocklists.DynamicBlockList',
              // If necessary, you can add any default values for missing properties here
            }
          }
        })

        const topLevelEnabledChanged = originalDynamicLists.enabled !== newSettings.enabled

        return {
          payload: {
            javaClass: originalDynamicLists.javaClass,
            version: originalDynamicLists.version,
            enabled: newSettings.enabled,
            dynamicBlockList: {
              javaClass: originalDynamicLists.dynamicBlockList.javaClass,
              list: updatedList,
            },
          },
          topLevelEnabledChanged,
        }
      },
      onEdit(newSettings) {
        this.$store.commit('SET_LOADER', true)
        const { payload } = this.transformVdynamicToStoreFormat(newSettings)
        let response = null
        if (payload.enabled === false) {
          response = { success: false, message: 'please enable DBL to update add new entries' }
        } else {
          response = { success: true, message: 'please save the added changes' }
        }
        this.$store.commit('SET_LOADER', false)

        if (response.success) {
          this.$vuntangle.toast.add(this.$t(response.message))
        } else {
          this.fetchStatus()
          this.$vuntangle.toast.add(this.$t('rolled_back_settings', [response.message]))
        }
      },

      async onSave(newSettings) {
        this.$store.commit('SET_LOADER', true)
        const { payload, topLevelEnabledChanged } = this.transformVdynamicToStoreFormat(newSettings)
        let response = null
        if (topLevelEnabledChanged && payload.enabled === true) {
          response = await this.$store.dispatch('settings/startDynamicLists', payload)
        } else if (topLevelEnabledChanged && payload.enabled === false) {
          response = await this.$store.dispatch('settings/stopDynamicLists', payload)
        } else if (payload.enabled === false) {
          response = { success: false, message: 'please enable DBL' }
        } else {
          response = await this.$store.dispatch('settings/saveDynamicLists', payload)
        }
        this.$store.commit('SET_LOADER', false)
        if (response.success) {
          this.$vuntangle.toast.add(this.$t('saved_successfully', [this.$t('dynamic_blocklist')]))
        } else {
          this.$vuntangle.toast.add(this.$t('rolled_back_settings', [response.message]))
        }
      },
      transformToJavaFormat(configurationIds) {
        return {
          javaClass: 'java.util.LinkedList',
          list: configurationIds,
        }
      },
      /**
       * Handler for `download` event
       * @param {String[]} configurationIds - UUIDs of the configurations to be refreshed
       */
      async onDownload(configurationIds) {
        this.$store.commit('SET_LOADER', true)
        const response = await this.$store.dispatch(
          'settings/runJobsByConfigIds',
          this.transformToJavaFormat(configurationIds),
        )
        this.$store.commit('SET_LOADER', false)
        if (response.success) {
          this.$vuntangle.toast.add(this.$vuntangle.$t('download_blocklist_to_appliance_success'))
        } else {
          this.$vuntangle.toast.add(this.$vuntangle.$t('download_blocklist_to_appliance_failed'))
        }
      },
      /**
       * Handler for `delete-configuration` event, removing that configuration from settings
       * @param {String} configurationId -  id of blocklist row
       */
      async onDeleteConfiguration(configurationId) {
        this.$store.commit('SET_LOADER', true)
        if (this.dynamicLists.dynamicLists.enabled === true) {
          this.dynamicLists.dynamicLists.dynamicBlockList.list =
            this.dynamicLists.dynamicLists.dynamicBlockList.list.filter(item => item.id !== configurationId)
          const response = await this.$store.dispatch('settings/saveDynamicLists', this.dynamicLists.dynamicLists)
          this.$store.commit('SET_LOADER', false)

          if (response.success) {
            this.$vuntangle.toast.add(this.$vuntangle.$t('deleted_successfully', [this.$t('dynamic_blocklist')]))
          } else {
            this.$vuntangle.toast.add(this.$t('an_error_occurred'), 'error')
          }
        } else {
          this.$store.commit('SET_LOADER', false)

          this.$vuntangle.toast.add(this.$t('Please enable DBL'), 'error')
        }
      },
      async exportCsv(id) {
        let response = null
        try {
          const rpc = await Util.setRpcJsonrpc('admin')
          const appManager = await rpc.jsonrpc.UvmContext.appManager()
          console.log('appManager : ', appManager)
          const app = await appManager.app('dynamic-blocklists')
          console.log('app', app)
          response = await app.exportCsv(id)
          return response
        } catch (ex) {
          Util.handleException(ex)
          return response
        }
      },
      /**
       * Handler for `download-csv` event
       * that fetches the ip list and than saves it to local CSV file
       * @param {Array} configurationId - id of blocklist row
       */
      async initiateDownload(configurationId) {
        try {
          console.log('configurationId initdown : ', configurationId)
          this.$store.commit('SET_LOADER', true)
          const response = await this.exportCsv(configurationId)
          this.$store.commit('SET_LOADER', false)
          // call vuntangle util method which processes the response and downloads the CSV file
          if (response != null) {
            vuntangle.util.processDynamicListDownload(`block-list-${configurationId}.csv`, response)
          } else {
            this.$vuntangle.toast.add(this.$vuntangle.$t('Please enable the entry'), 'error')
          }
        } catch (error) {
          this.$vuntangle.toast.add(this.$vuntangle.$t('export_failed'), 'error')
        }
      },
    },
  }
</script>
