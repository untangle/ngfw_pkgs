<template>
  <v-container fluid :class="`shared-cmp d-flex flex-column flex-grow-1 pa-2`">
    <no-license v-if="!isLicensed" class="mt-2">
      {{ $t('not_licensed_service', [$t('configuration_backup')]) }}
      <template #actions>
        <u-btn class="ml-4" to="/settings/system/about">{{ $t('view_system_license') }}</u-btn>
        <u-btn class="ml-4" :href="manageLicenseUri" target="_blank">
          {{ $t('manage_licenses') }}
          <v-icon right> mdi-open-in-new </v-icon>
        </u-btn>
      </template>
    </no-license>
    <configuration-backup
      v-if="settings"
      :settings="settings"
      :disabled="!isLicensed"
      :root-directory="rootDirectory"
      :google-drive-is-configured="isGoogleDriveConnected"
      @send-backup="sendBackup"
    >
      <!-- Custom action buttons slot -->
      <template #actions="{ newSettings, disabled, isDirty }">
        <u-btn :disabled="disabled" class="mr-2" @click="onResetDefaults">
          {{ $vuntangle.$t('reset_to_defaults') }}
        </u-btn>
        <u-btn :disabled="disabled || !isDirty" @click="onSave(newSettings)">
          {{ $vuntangle.$t('save') }}
        </u-btn>
      </template>
    </configuration-backup>
  </v-container>
</template>

<script>
  import { ConfigurationBackup, NoLicense } from 'vuntangle'
  import Util from '../../../util/setupUtil'
  import serviceMixin from './serviceMixin'
  import Rpc from '@/util/Rpc'

  export default {
    components: {
      ConfigurationBackup,
      NoLicense,
    },
    mixins: [serviceMixin],

    data() {
      return {
        licenseNodeName: 'configuration-backup',
        rootDirectory: '',
      }
    },

    computed: {
      settings: ({ $store }) => $store.getters['apps/getSettings']('configuration-backup')?.settings,
      isGoogleDriveConnected: ({ $store }) => $store.getters['config/isGoogleDriveConnected'],
    },

    async created() {
      this.$store.dispatch('apps/loadAppData', { appName: this.licenseNodeName })
      this.$store.dispatch('config/getIsGoogleDriveConnected')
      this.rootDirectory = await this.$store.dispatch('config/getRootDirectory')
    },

    methods: {
      onResetDefaults() {
        this.$store.dispatch('apps/loadAppData', { appName: this.licenseNodeName })
      },

      async sendBackup({ cb }) {
        try {
          this.$store.commit('SET_LOADER', true)
          const response = await Rpc.asyncData('rpc.appManager.app("configuration-backup").sendBackup').finally(() => {
            this.$store.commit('SET_LOADER', false)
          })
          return cb(response ?? null)
        } catch (error) {
          Util.handleException(error)
        }
      },

      /**
       * Saves the settings
       * @param param
       */
      async onSave(newSettings) {
        this.$store.commit('SET_LOADER', true)
        try {
          await this.$store.dispatch('apps/setAppSettings', {
            appName: 'configuration-backup',
            settings: newSettings,
          })
        } catch (error) {
          Util.handleException(error)
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },
    },
  }
</script>
