<template>
  <v-container fluid :class="`shared-cmp d-flex flex-column flex-grow-1 pa-2`">
    <no-license v-if="!isLicensed && isInstalled" class="mt-2">
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
      ref="component"
      :settings="settings"
      :app-data="consolidatedAppData"
      :disabled="!isLicensed && isInstalled"
      :reports="appReports"
      :root-directory="rootDirectory"
      :google-drive-is-configured="isGoogleDriveConnected"
      :is-installed="isInstalled"
      @send-backup="sendBackup"
      @toggle-state="toggleAppState"
    >
      <template #actions="{ newSettings, isDirty }">
        <div v-if="isInstalled" class="d-flex flex-wrap align-center" style="gap: 8px">
          <div style="min-width: 180px">
            <u-app-status-remove
              class="mt-0"
              service-app
              :app-name="$t('configuration_backup')"
              @remove="onRemoveService"
            />
          </div>
          <v-divider vertical class="mx-4" />
          <u-btn class="mr-2" @click="refreshData">
            {{ $vuntangle.$t('refresh') }}
          </u-btn>
          <u-btn :disabled="!isDirty" @click="onSave(newSettings)">
            {{ $vuntangle.$t('save') }}
          </u-btn>
        </div>
        <div v-else style="min-width: 180px">
          <u-app-install @install="onInstallService" />
        </div>
      </template>
    </configuration-backup>
  </v-container>
</template>

<script>
  import { ConfigurationBackup, NoLicense, UAppStatusRemove, UAppInstall, UBtn } from 'vuntangle'
  import { VDivider } from 'vuetify/lib'
  import Util from '../../../util/setupUtil'
  import serviceMixin from './serviceMixin'
  import Rpc from '@/util/Rpc'

  export default {
    components: {
      ConfigurationBackup,
      NoLicense,
      UAppStatusRemove,
      UAppInstall,
      UBtn,
      VDivider,
    },
    mixins: [serviceMixin],

    data() {
      return {
        serviceName: 'configuration-backup',
        licenseNodeName: 'configuration-backup',
        rootDirectory: '',
      }
    },

    computed: {
      isGoogleDriveConnected: ({ $store }) => $store.getters['config/isGoogleDriveConnected'],
      appDisplayName: ({ appManager }) => appManager?.getAppProperties?.()?.displayName || 'Configuration Backup',
      consolidatedAppData: ({ powerState, appDisplayName }) => ({
        powerState: powerState || {},
        appDisplayName,
      }),
    },

    async created() {
      this.$store.dispatch('config/getIsGoogleDriveConnected')
      this.rootDirectory = await this.$store.dispatch('config/getRootDirectory')
    },

    methods: {
      /**
       * Triggers an immediate backup via RPC.
       * Calls the callback with the response or null on failure.
       * @param {Function} cb - callback provided by the vuntangle component
       */
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
       * Validates then delegates to mixin's saveSettings
       * @param {Object} newSettings
       */
      async onSave(newSettings) {
        const isValid = await this.$refs.component.validate()
        if (!isValid) return
        await this.saveSettings(newSettings)
      },
    },
  }
</script>
