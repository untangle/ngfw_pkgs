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
      @list-users="onListUsers"
      @refresh-group-cache="onRefreshGroupCache"
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
  import util from '@/util/setupUtil'
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

      /**
       * Performs a RADIUS authentication test using the provided settings and credentials.
       * Invokes the RPC method to validate the RADIUS server connectivity and authentication,
       * then returns the result through the callback.
       */
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
          cb()
          util.handleException(ex)
        }
      },

      /**
       * Handles the Active Directory connectivity test request.
       * Invokes the RPC method to validate the provided Active Directory settings
       * and returns the test result through the callback.
       */
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
          util.handleException(ex)
        }
      },

      /**
       * Retrieves the list of Active Directory users
       * calls cb with the results
       */
      async onListUsers({ server, cb }) {
        const empty = []
        if (!this.appManager) return cb(empty)
        try {
          const rows = await Rpc.asyncData(
            this.appManager,
            'getActiveDirectoryManager().getUsers',
            server?.domain || null,
          )
          cb(rows || empty)
        } catch (ex) {
          cb(empty)
          util.handleException(ex)
        }
      },

      /**
       * Triggers a group cache refresh via RPC and invokes the callback when complete,
       * regardless of success or failure.
       */
      async onRefreshGroupCache({ cb }) {
        if (!this.appManager) return cb()
        try {
          await Rpc.asyncData(this.appManager, 'refreshGroupCache')
        } catch (ex) {
          util.handleException(ex)
        } finally {
          cb()
        }
      },
    },
  }
</script>
