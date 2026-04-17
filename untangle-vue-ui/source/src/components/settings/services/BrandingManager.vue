<template>
  <v-container fluid :class="`shared-cmp d-flex flex-column flex-grow-1 pa-2`">
    <no-license v-if="!isLicensed && isInstalled" class="mt-2">
      {{ $t('not_licensed_service', [$t('branding_manager')]) }}
      <template #actions>
        <u-btn class="ml-4" to="/settings/system/about">{{ $t('view_system_license') }}</u-btn>
        <u-btn class="ml-4" :href="manageLicenseUri" target="_blank">
          {{ $t('manage_licenses') }}
          <v-icon right> mdi-open-in-new </v-icon>
        </u-btn>
      </template>
    </no-license>
    <branding-manager
      :settings="settings"
      :disabled="!isLicensed && isInstalled"
      :is-installed="isInstalled"
      @upload-logo="uploadLogo"
      @save-settings="onSaveSettings"
      @reset-to-defaults="onResetDefaults"
    >
      <template #actions="{ isDirty, onSave, onReset }">
        <div v-if="isInstalled" class="d-flex flex-wrap align-center" style="gap: 8px">
          <div style="min-width: 180px">
            <u-app-status-remove
              class="mt-0"
              service-app
              :app-name="$t('branding_manager')"
              @remove="onRemoveService"
            />
          </div>
          <v-divider vertical class="mx-4" />
          <u-btn @click="onReset">{{ $vuntangle.$t('refresh') }}</u-btn>
          <u-btn :disabled="!isDirty" @click="onSave">{{ $vuntangle.$t('save') }}</u-btn>
        </div>
        <div v-else style="min-width: 180px">
          <u-app-install @install="onInstallService" />
        </div>
      </template>
    </branding-manager>
  </v-container>
</template>

<script>
  import { BrandingManager, NoLicense, UAppStatusRemove, UAppInstall, UBtn } from 'vuntangle'
  import { VDivider } from 'vuetify/lib'
  import Util from '../../../util/setupUtil'
  import serviceMixin from './serviceMixin'
  import util from '@/util/util'

  export default {
    components: {
      BrandingManager,
      NoLicense,
      UAppStatusRemove,
      UAppInstall,
      UBtn,
      VDivider,
    },
    mixins: [serviceMixin],
    data() {
      return {
        serviceName: 'branding-manager',
        licenseNodeName: 'branding-manager',
        originalDefaultLogo: true,
      }
    },

    computed: {
      settings: ({ $store }) => $store.getters['apps/getSettings']('branding-manager')?.settings,
    },

    created() {
      this.$store.dispatch('apps/loadAppData', { appName: this.licenseNodeName })
    },

    methods: {
      async uploadLogo({ formData, cb }) {
        try {
          const response = await util.uploadFile('/admin/upload', {
            logo: formData.get('logo'),
            type: 'logo',
          })
          cb(response)
        } catch (error) {
          Util.handleException(error)
        }
      },

      /**
       * Resets the branding manager to its default configuration
       */
      onResetDefaults() {
        this.$store.dispatch('apps/loadAppData', { appName: this.licenseNodeName })
      },

      /**
       * Saves the settings
       * @param {Object} newSettings
       * @param {Boolean} needRackReload
       */
      async onSaveSettings({ newSettings, needRackReload }) {
        this.$store.commit('SET_LOADER', true)
        try {
          this.originalDefaultLogo = this.settings?.defaultLogo
          if (this.originalDefaultLogo !== newSettings.defaultLogo) {
            needRackReload = true
          }
          await this.$store.dispatch('apps/setAppSettings', {
            appName: 'branding-manager',
            settings: newSettings,
          })
          if (needRackReload) {
            window.location.reload()
          }
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },
    },
  }
</script>
