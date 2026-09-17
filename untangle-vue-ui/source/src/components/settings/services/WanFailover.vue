<template>
  <v-container fluid :class="`shared-cmp d-flex flex-column flex-grow-1 pa-0`">
    <no-license v-if="!isLicensed && isInstalled" class="mt-2">
      {{ $t('not_licensed_service', [$t('wan_failover')]) }}
      <template #actions>
        <u-btn class="ml-4" to="/settings/system/about">{{ $t('view_system_license') }}</u-btn>
        <u-btn class="ml-4" :href="manageLicenseUri" target="_blank">
          {{ $t('manage_licenses') }}
          <v-icon right> mdi-open-in-new </v-icon>
        </u-btn>
      </template>
    </no-license>
    <wan-failover
      v-if="settings"
      :settings="displaySettings"
      :app-data="consolidatedAppData"
      :disabled="!isLicensed && isInstalled"
      :is-installed="isInstalled"
      :metrics-data="formattedMetrics"
      :wan-status-data="wanStatusData"
      :reports="appReports"
      @get-wan-status="getWanStatus"
      @get-ping-suggestions="getPingSuggestions"
      @run-wan-test="runWanTest"
      @toggle-state="toggleAppState"
    >
      <template #actions="{ newSettings, isDirty }">
        <div v-if="isInstalled" class="d-flex flex-wrap align-center" style="gap: 8px">
          <div style="min-width: 180px">
            <u-app-status-remove class="mt-0" :app-name="$t('wan_failover')" @remove="onRemoveService" />
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
    </wan-failover>
  </v-container>
</template>
<script>
  import { WanFailover, NoLicense, UAppStatusRemove, UAppInstall } from 'vuntangle'
  import serviceMixin from './serviceMixin'
  import Rpc from '@/util/Rpc'
  import util from '@/util/setupUtil'
  export default {
    components: {
      WanFailover,
      NoLicense,
      UAppStatusRemove,
      UAppInstall,
    },
    mixins: [serviceMixin],
    data() {
      return {
        serviceName: 'wan-failover',
        licenseNodeName: 'wan-failover',
        wanStatusData: [],
        displayNameFallback: 'WAN Failover',
      }
    },
    computed: {
      displaySettings({ settings }) {
        // convert all milliseconds to seconds after load
        if (!settings?.tests?.length) return settings
        return {
          ...settings,
          tests: settings.tests.map(test => ({
            ...test,
            timeoutMilliseconds: test.timeoutMilliseconds / 1000,
            delayMilliseconds: test.delayMilliseconds / 1000,
          })),
        }
      },
    },
    watch: {
      // Watcher for appManager from serviceMixin to trigger fetching of wan-failover specific data when the manager becomes available.
      appManager: {
        async handler(manager) {
          if (!manager) return
          await this.getWanStatus()
        },
      },
    },
    methods: {
      async onSave(newSettings) {
        // convert all seconds to milliseconds before save
        const settingsToSave = newSettings?.tests?.length
          ? {
              ...newSettings,
              tests: newSettings.tests.map(test => ({
                ...test,
                timeoutMilliseconds: test.timeoutMilliseconds * 1000,
                delayMilliseconds: test.delayMilliseconds * 1000,
              })),
            }
          : newSettings
        await this.saveSettings(settingsToSave)
      },
      getWanStatus() {
        this.wanStatusData = (this.appManager?.getWanStatusV2() || []).filter(item => item.systemName !== null)
      },
      async runWanTest(test, resolve) {
        if (!this.appManager) {
          resolve(null)
          return
        }
        this.$store.commit('SET_LOADER', true)
        try {
          const result = await Rpc.asyncData(this.appManager, 'runTest', test)
          resolve(result)
        } catch (err) {
          util.handleException(err)
          resolve(null)
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      async getPingSuggestions(interfaceId, resolve) {
        if (!this.appManager) {
          resolve([])
          return
        }
        this.$store.commit('SET_LOADER', true)
        try {
          const result = await Rpc.asyncData(this.appManager, 'getPingableHostsV2', interfaceId)
          resolve(Array.isArray(result) ? result : [])
        } catch (err) {
          util.handleException(err)
          resolve([])
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },
    },
  }
</script>
