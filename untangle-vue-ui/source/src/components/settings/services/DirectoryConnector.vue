<template>
  <v-container fluid :class="`shared-cmp d-flex flex-column flex-grow-1 pa-0`">
    <no-license v-if="!isLicensed && isInstalled" class="mt-2">
      {{ $t('not_licensed_service', [$t('directory_connector')]) }}
      <template #actions>
        <u-btn class="ml-4" to="/settings/system/about">{{ $t('view_system_license') }}</u-btn>
        <u-btn class="ml-4" :href="manageLicenseUri" target="_blank">
          {{ $t('manage_licenses') }}
          <v-icon right> mdi-open-in-new </v-icon>
        </u-btn>
      </template>
    </no-license>
    <directory-connector
      v-if="settings"
      ref="directoryConnector"
      :settings="settings"
      :app-data="consolidatedAppData"
      :disabled="!isLicensed && isInstalled"
      :is-installed="isInstalled"
      :reports="appReports"
      @toggle-state="toggleAppState"
      @radius-test="onRadiusTest"
      @test-active-directory="onTestActiveDirectory"
    >
      <template #actions="{ newSettings, isDirty }">
        <div v-if="isInstalled" class="d-flex flex-wrap align-center" style="gap: 8px">
          <div style="min-width: 180px">
            <u-app-status-remove class="mt-0" :app-name="$t('directory_connector')" @remove="onRemoveService" />
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
    </directory-connector>
  </v-container>
</template>

<script>
  import { DirectoryConnector, NoLicense, UAppStatusRemove, UAppInstall } from 'vuntangle'
  import serviceMixin from './serviceMixin'
  import Rpc from '@/util/Rpc'

  export default {
    components: {
      DirectoryConnector,
      NoLicense,
      UAppStatusRemove,
      UAppInstall,
    },
    mixins: [serviceMixin],
    data() {
      return {
        serviceName: 'directory-connector',
        licenseNodeName: 'directory-connector',
        displayNameFallback: 'Directory Connector',
      }
    },
    methods: {
      async onSave(newSettings) {
        const isValid = await this.$refs.directoryConnector.validate()
        if (!isValid) return
        await this.saveSettings(newSettings)
      },

      async onRadiusTest({ settings, username, password, cb }) {
        if (!this.appManager) return
        try {
          const result = await Rpc.asyncData(
            this.appManager,
            'getRadiusManager().getRadiusStatusForSettingsV2',
            settings,
            username,
            password,
          )
          cb(result)
        } catch (ex) {
          cb(ex?.message || String(ex))
        }
      },

      async onTestActiveDirectory({ server, cb }) {
        if (!this.appManager) return
        try {
          const result = await Rpc.asyncData(
            this.appManager,
            'getActiveDirectoryManager().getStatusForSettingsV2',
            server,
          )
          cb(result)
        } catch (ex) {
          const failure = {
            status: 'FAIL_QUERY',
            searchBases: [],
            userCount: 0,
            groupCount: 0,
            error: ex?.message || String(ex),
          }
          cb(failure)
        }
      },
    },
  }
</script>
