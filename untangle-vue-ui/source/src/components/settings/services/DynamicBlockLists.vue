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
        const response = await window.rpc.appManager.app('dynamic-blocklists').status()
        this.$store.commit('SET_LOADER', false)
        this.status = response || []
      },

      /** Resets the dynamic blocklists to its default configuration */
      onResetDefaults() {
        this.$vuntangle.confirm.show({
          title: this.$vuntangle.$t('confirm'),
          message: this.$vuntangle.$t('dynamic_blocklist_reset_warning'),
          action: async resolve => {
            this.$store.commit('SET_LOADER', true)
            // Call API to reset defaults
            const response = await window.rpc.appManager.app('dynamic-blocklists').onResetDefaultsV2()
            if (response?.success !== false) {
              // Refresh the Vuex store with new default settings
              await this.$store.dispatch('apps/getAndCommitAppSettings', this.licenseNodeName)
            } else {
              this.$vuntangle.toast.add(this.$t('rolled_back_settings', [response.message]), 'error')
            }
            this.$store.commit('SET_LOADER', false)
            resolve()
          },
        })
      },
      /**
       * dispatches action to save the updated dynamic list
       * @param {Object} newSettings - new settings to be saved
       */
      async onSave(newSettings) {
        this.$store.commit('SET_LOADER', true)
        const response = await this.$store.dispatch('apps/setAppSettings', {
          appName: 'dynamic-blocklists',
          settings: newSettings,
        })
        this.$store.commit('SET_LOADER', false)
        if (!response.success) {
          this.$vuntangle.toast.add(this.$t('rolled_back_settings', [response.message]))
        }
      },
      /**
       * Handler for `delete-configuration` event, removing that configuration from settings
       * @param {String} configurationId -  id of blocklist row
       */
      async onDeleteConfiguration(configurationId) {
        this.$store.commit('SET_LOADER', true)
        // Get the latest dynamicListSettings from the store
        const currentSettings = this.dynamicListsSettings
        // Remove the configuration with the given ID
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
        this.$store.commit('SET_LOADER', false)
      },

      /**
       * Handler for `download` event @delete-configuration="onDeleteConfiguration"
       * @param {String[]} configurationIds - UUIDs of the configurations to be refreshed
       */
      async onDownload(configurationIds) {
        this.$store.commit('SET_LOADER', true)
        const response = await window.rpc.appManager.app('dynamic-blocklists').runJobsByConfigIdsV2(configurationIds)
        if (response?.success !== false) {
          await this.$store.dispatch('apps/getAndCommitAppSettings', this.licenseNodeName)
          this.fetchStatus()
        } else {
          this.$store.commit('SET_LOADER', false)
          this.$vuntangle.toast.add(this.$vuntangle.$t('an_error_occurred'), 'error')
        }
      },
    },
  }
</script>
