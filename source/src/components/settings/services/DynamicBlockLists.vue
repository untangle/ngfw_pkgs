<template>
  <v-container class="pa-0 d-flex flex-column" fluid>
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
      :settings="dynamicLists"
      :status="status"
      :disabled="!isLicensed"
      @download="onDownload"
      @delete-configuration="onDeleteConfiguration"
      @download-csv="initiateDownload"
      @refresh="fetchStatus"
      @update-settings="onSave"
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
  import api from '@/plugins/api'

  export default {
    components: {
      SettingsDynamicBlockLists,
      NoLicense,
    },
    mixins: [serviceMixin],
    data() {
      return {
        licenseNodeName: 'untangle-node-dynamic-lists',
        status: [],
      }
    },
    computed: {
      dynamicLists: ({ $store }) => $store.getters['settings/dynamicLists'],
    },

    mounted() {
      this.fetchStatus()
    },

    methods: {
      /** Resets the dynamic blocklists to its default configuration */
      onResetDefaults() {
        this.$vuntangle.confirm.show({
          title: this.$vuntangle.$t('confirm'),
          message: this.$vuntangle.$t('dynamic_blocklist_reset_warning'),
          action: async resolve => {
            const getResponse = await this.$store.dispatch('settings/getDynamicListsDefaultSettings')
            if (getResponse) {
              const setResponse = await this.$store.dispatch('settings/setDynamicListsDefaultSettings')
              if (setResponse) {
                this.$vuntangle.toast.add(this.$vuntangle.$t('dynamic_blocklist_reset_success'))
              }
            }
            resolve()
          },
        })
      },

      /**
       * Fetches the status for the dynamic lists and
       * formats the timestamp of each configuration to human readabale values
       */
      async fetchStatus() {
        this.$store.commit('SET_LOADER', true)
        const response = await api.get('/api/reports/dynamiclists')
        this.$store.commit('SET_LOADER', false)
        this.status = response?.result || []
      },

      /**
       * dispatches action to save the updated dynamic list
       * @param {Object} newSettings - new settings to be saved
       */
      async onSave(newSettings) {
        this.$store.commit('SET_LOADER', true)
        const response = await this.$store.dispatch('settings/saveDynamicLists', newSettings)
        this.$store.commit('SET_LOADER', false)
        if (response.success) {
          this.$vuntangle.toast.add(this.$t('saved_successfully', [this.$t('dynamic_blocklist')]))
        } else {
          this.$vuntangle.toast.add(this.$t('rolled_back_settings', [response.message]))
        }
      },

      /**
       * Handler for `delete-configuration` event, removing that configuration from settings
       * @param {String} configurationId -  id of blocklist row
       */
      async onDeleteConfiguration(configurationId) {
        this.$store.commit('SET_LOADER', true)
        const response = await api.delete(`/api/dynamiclists/${configurationId}`)

        if (response?.result) {
          this.$vuntangle.toast.add(this.$vuntangle.$t('deleted_successfully', [this.$t('dynamic_blocklist')]))
          await this.$store.dispatch('settings/getSettings', true)
        } else {
          this.$vuntangle.toast.add(this.$t('an_error_occurred'), 'error')
        }
        this.$store.commit('SET_LOADER', false)
      },

      /**
       * Handler for `download` event
       * @param {String[]} configurationIds - UUIDs of the configurations to be refreshed
       */
      async onDownload(configurationIds) {
        this.$store.commit('SET_LOADER', true)
        const response = await api.post('/api/dynamiclists/refresh', configurationIds)
        this.fetchStatus()
        this.$store.commit('SET_LOADER', false)

        if (response?.result) {
          this.$vuntangle.toast.add(this.$vuntangle.$t('download_blocklist_to_appliance_success'))
        }
      },

      /**
       * Handler for `download-csv` event
       * that fetches the ip list and than saves it to local CSV file
       * @param {Array} configurationId - id of blocklist row
       */
      async initiateDownload(configurationId) {
        try {
          this.$store.commit('SET_LOADER', true)
          const response = await api.get(`/api/dynamiclists/${configurationId}/download`)
          this.$store.commit('SET_LOADER', false)
          // call vuntangle util method which processes the response and downloads the CSV file
          vuntangle.util.processDynamicListDownload(`block-list-${configurationId}.csv`, response)
        } catch (error) {
          this.$vuntangle.toast.add(this.$vuntangle.$t('export_failed'), 'error')
        }
      },
    },
  }
</script>
