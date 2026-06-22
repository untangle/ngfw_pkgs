<template>
  <web-cache
    :settings="settings"
    :app-data="consolidatedAppData"
    :sessions-data="sessionsData"
    :metrics-data="formattedMetrics"
    :reports="appReports"
    @toggle-state="toggleAppState"
  >
    <!-- Custom action buttons slot -->
    <template #actions>
      <div class="d-flex flex-wrap align-center" style="gap: 8px">
        <div style="min-width: 140px">
          <u-app-status-remove class="mt-0" :app-name="appDisplayName" @remove="removeApp" />
        </div>
        <v-divider vertical class="mx-4" />
        <u-btn @click="refreshData">{{ $t('refresh') }}</u-btn>
      </div>
    </template>
  </web-cache>
</template>

<script>
  import { WebCache, UAppStatusRemove } from 'vuntangle'
  import { VDivider } from 'vuetify/lib'
  import appMixin from '../appMixin'

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
      }
    },

    computed: {
      consolidatedAppData: appInstance => appInstance.buildConsolidatedAppData(),
    },
  }
</script>
