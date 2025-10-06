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

    <settings-dynamic-block-lists :settings="dynamicListsSettings" :disabled="!isLicensed" @update-settings="onSave">
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
      dynamicListsSettings: ({ $store }) => $store.getters['settings/dynamicListSettings'],
    },

    created() {
      // update current system setting from store store
      this.$store.dispatch('settings/getDynamicListSettings', false)
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
            const response = await this.$store.dispatch('settings/getDynamicListsDefaultSettings')
            if (!response.success) {
              this.$vuntangle.toast.add(this.$t('rolled_back_settings', [response.message]))
            }
            resolve()
          },
        })
      },
      async onSave(newSettings) {
        this.$store.commit('SET_LOADER', true)
        const response = await this.$store.dispatch('settings/setDynamicListSettings', newSettings)
        this.$store.commit('SET_LOADER', false)
        if (response.success) {
          this.$vuntangle.toast.add(this.$t('saved_successfully', [this.$t('dynamic_blocklist')]))
        } else {
          this.$vuntangle.toast.add(this.$t('rolled_back_settings', [response.message]))
        }
      },
    },
  }
</script>
