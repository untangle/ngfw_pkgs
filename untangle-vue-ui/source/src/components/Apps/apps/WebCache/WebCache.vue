<template>
  <web-cache
    :settings="settings"
    :app-data="consolidatedAppData"
    :sessions-data="sessionsData"
    :metrics-data="formattedMetrics"
    :reports="appReports"
    :statistics="statistics"
    @toggle-state="toggleAppState"
    @clear-cache="clearCache"
  >
    <!-- Custom action buttons slot -->
    <template #actions="{ newSettings, isDirty }">
      <div class="d-flex flex-wrap align-center" style="gap: 8px">
        <div style="min-width: 180px">
          <u-app-status-remove class="mt-0" :app-name="appDisplayName" @remove="removeApp" />
        </div>
        <v-divider vertical class="mx-4" />
        <u-btn class="mr-2" @click="refreshData">{{ $t('refresh') }}</u-btn>
        <u-btn :disabled="!isDirty || saveDisabled" @click="saveSettings(newSettings)">{{ $t('save') }}</u-btn>
      </div>
    </template>
  </web-cache>
</template>

<script>
  import { WebCache, UAppStatusRemove } from 'vuntangle'
  import { VDivider } from 'vuetify/lib'
  import appMixin from '../appMixin'
  import Util from '@/util/setupUtil'
  import Rpc from '@/util/Rpc'

  export default {
    name: 'WebCacheApp',

    components: { WebCache, UAppStatusRemove, VDivider },

    mixins: [appMixin],

    props: {
      appData: { type: Object, default: null },
    },

    data() {
      return {
        appName: this.appData?.appName || 'web-cache',
        defaultDisplayName: 'Web Cache',
        statistics: null,
      }
    },

    computed: {
      consolidatedAppData: appInstance => appInstance.buildConsolidatedAppData(),
    },

    watch: {
      appManager: {
        async handler(manager) {
          if (!manager) return
          await this.getStatistics()
        },
      },
    },

    methods: {
      async getStatistics() {
        if (!this.appManager) return
        try {
          this.statistics = await Rpc.asyncData(this.appManager, 'getStatisticsV2')
        } catch (ex) {
          this.statistics = null
          Util.handleException(ex)
        }
      },

      refreshData() {
        appMixin.methods.refreshData.call(this)
        this.getStatistics()
      },

      async clearCache(cb) {
        if (!this.appManager) return
        try {
          this.$store.commit('SET_LOADER', true)
          await Rpc.asyncData(this.appManager, 'clearSquidCache')
          cb?.()
        } catch (ex) {
          Util.handleException(ex)
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },
    },
  }
</script>
