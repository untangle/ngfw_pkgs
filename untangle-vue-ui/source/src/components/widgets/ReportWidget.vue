<template>
  <u-widget class="report-widget" :title="title" :enable-expand="true">
    <template #actions>
      <v-menu v-model="menuOpen" offset-y left :close-on-content-click="false">
        <template #activator="{ on, attrs }">
          <v-btn icon v-bind="attrs" v-on="on"><v-icon>mdi-dots-vertical</v-icon></v-btn>
        </template>
        <v-list dense style="min-width: 220px; max-width: 260px">
          <v-list-item dense style="min-height: 10px; justify-content: flex-end">
            <v-btn icon x-small @click.stop="closeMenu"><v-icon small>mdi-close-thick</v-icon></v-btn>
          </v-list-item>
          <v-list-item dense style="min-height: 30px" @click="refreshTick += 1">
            <v-list-item-icon class="mr-2"><v-icon>mdi-refresh</v-icon></v-list-item-icon>
            <v-list-item-title style="font-size: 14px">{{ $t('refresh') }}</v-list-item-title>
          </v-list-item>
          <v-list-item dense style="min-height: 30px" :disabled="!report" @click="openInReports">
            <v-list-item-icon class="mr-2"><v-icon>mdi-open-in-new</v-icon></v-list-item-icon>
            <v-list-item-title style="font-size: 14px">{{ $t('open_in_reports') }}</v-list-item-title>
          </v-list-item>
          <v-divider />
          <v-subheader class="ml-2" style="font-size: 14px">{{ $t('settings') }}</v-subheader>
          <v-list-item dense class="mr-10">
            <v-list-item-title class="mt-2" style="font-size: 14px; flex: 0 0 90px"
              >{{ $t('auto_refresh') }}:</v-list-item-title
            >
            <v-select
              v-model="localInterval"
              :items="refreshOptions"
              dense
              hide-details
              class="menu-select"
              style="max-width: 200px"
              @change="onIntervalChange"
            />
          </v-list-item>
          <v-list-item dense style="min-height: 16px" />
          <!-- <v-divider /> -->
          <v-list-item dense>
            <v-spacer />
            <v-btn small color="primary" @click="saveSettings">{{ $t('save') }}</v-btn>
          </v-list-item>
        </v-list>
      </v-menu>
    </template>
    <div class="report-widget-content">
      <preview-report v-if="view" :view="view" @fetch-data="onFetchData" />
      <div v-else class="report-widget-empty">{{ $t('no_data_available') }}</div>
      <div v-if="isConditionMasked" class="report-widget-mask" />
    </div>
  </u-widget>
</template>
<script>
  import PreviewReport from '../../../node_modules/vuntangle/src/shared/Reports/components/PreviewReport.vue'
  import reportsMixin from '../reports/reportsMixin'
  import { buildReportView as buildReportViewConfig } from '@/util/reportViews'
  import { urlEncode, tableContainsColumns } from '@/util/reports'
  export default {
    components: { PreviewReport },
    mixins: [reportsMixin],
    provide() {
      return {
        $timeRange: () => this.previewTimeRange,
        $isPreview: () => false,
        $isPreviewMaximized: () => false,
        $boxSettings: null,
        $applianceUid: () => null,
        $totalCountReport: () => 0,
        $paginationReport: () => ({ pageNumber: 1, pageSize: 100 }),
        $useCursorPaginationReport: () => false,
        $hasQosmos: () => false,
        $actionFilter: () => null,
        $columnFilter: () => null,
        $enableExportCsv: () => false,
        $enableGridExportSettings: () => this.report?.type === 'EVENT_LIST',
        $widgetExportInfo: () => this.widgetExportInfo,
        $refreshTick: () => this.refreshTick,
      }
    },
    props: {
      title: {
        default: '',
        type: String,
      },
      report: {
        default: null,
        type: Object,
      },
      displayColumns: {
        default: null,
        type: Array,
      },
      interval: {
        default: 60,
        type: Number,
      },
      timeframe: {
        default: 1,
        type: Number,
      },
      size: {
        default: null,
        type: String,
      },
    },
    data() {
      return {
        widgetExportInfo: {
          oemName: '',
          version: (window.rpc?.version || '').replace(/\./g, '_'),
          hostName: (window.rpc?.hostname || '').replace(/\./g, '_'),
        },
        refreshTick: 0,
        refreshTimeout: null,
        menuOpen: false,
        localInterval: this.interval,
        previewTimeRange: {
          period: [Date.now() - this.timeframe * 3600000, null],
        },
        refreshOptions: [
          { text: '10 seconds', value: 10 },
          { text: '30 seconds', value: 30 },
          { text: '1 minute', value: 60 },
          { text: '2 minutes', value: 120 },
          { text: '5 minutes', value: 300 },
          { text: 'Never', value: 0 },
        ],
      }
    },
    computed: {
      reportForDisplay() {
        if (this.report?.type !== 'EVENT_LIST' || this.displayColumns == null) {
          return this.report
        }
        return { ...this.report, defaultColumns: this.displayColumns }
      },
      view() {
        return buildReportViewConfig(
          this.reportForDisplay,
          this.timeZoneOffset,
          this.interfaceNameMap || {},
          this.policyNameMap || {},
        )
      },
      isConditionMasked() {
        if (!this.report?.table || !this.conditionColumns.length) return false
        return !tableContainsColumns(this.report.table, this.conditionColumns)
      },
    },
    watch: {
      menuOpen(val) {
        if (val) {
          this._savedInterval = this.interval
        }
      },
      interval(val) {
        this.localInterval = val
        this.scheduleRefresh()
      },
      timeframe(value) {
        this.previewTimeRange = {
          period: [Date.now() - value * 3600000, null],
        }
      },
    },
    async created() {
      const companyName = await this.$store.dispatch('apps/getCompanyName')
      this.widgetExportInfo.oemName = (companyName || '').trim().replace(/ /g, '_')
    },
    mounted() {
      this.scheduleRefresh()
    },
    activated() {
      this.scheduleRefresh()
    },
    deactivated() {
      this.clearRefreshTimeout()
    },
    beforeDestroy() {
      this.clearRefreshTimeout()
    },
    methods: {
      clearRefreshTimeout() {
        clearTimeout(this.refreshTimeout)
        this.refreshTimeout = null
      },
      scheduleRefresh() {
        this.clearRefreshTimeout()
        if (this.localInterval > 0) {
          this.refreshTimeout = setTimeout(() => {
            this.refreshTick += 1
            // next schedule is set by onFetchData's finally block after fetch completes
          }, this.localInterval * 1000)
        }
      },
      closeMenu() {
        this.localInterval = this._savedInterval
        this.menuOpen = false
      },
      openInReports() {
        if (!this.report) return
        this.$router.push({
          name: 'report-details',
          params: {
            cat: urlEncode(this.report.category),
            rep: urlEncode(this.report.title),
          },
        })
      },
      onIntervalChange(value) {
        this.scheduleRefresh()
        this.$emit('update:interval', value)
      },
      saveSettings() {
        this.menuOpen = false
        this.$emit('save-settings', { interval: this.localInterval, size: this.size })
        this.refreshTick += 1
      },
    },
  }
</script>
<style scoped>
  .menu-select ::v-deep .v-input__slot::before,
  .menu-select ::v-deep .v-input__slot::after {
    display: none;
  }
  /* Report widgets already have a title supplied by UWidget. */
  .report-widget ::v-deep .preview-report .v-card__title,
  .report-widget ::v-deep .preview-report .v-divider {
    display: none;
  }
  .report-widget-content {
    position: relative;
    height: 100%;
  }
  .report-widget-empty {
    display: flex;
    min-height: 200px;
    align-items: center;
    justify-content: center;
    color: #777;
  }
  .report-widget-mask {
    position: absolute;
    inset: 0;
    background: rgba(255, 255, 255, 0.7);
    z-index: 10;
  }
  .report-widget ::v-deep .v-card__title .v-btn:has(.mdi-refresh),
  .report-widget ::v-deep .v-card__title .v-btn:has(.mdi-eye-off-outline),
  .report-widget ::v-deep .v-card__title .v-btn:has(.mdi-eye-outline) {
    display: none;
  }
  /* Hide the event-count selector from dashboard event grids. */
  .report-widget ::v-deep .v-select[style*='160px'] {
    display: none;
  }
  .report-widget ::v-deep .v-card.mr-4 {
    display: none;
  }
  .report-widget ::v-deep .v-card > .d-flex.flex-column.flex-grow-1 > .v-card {
    display: none !important;
  }
  /* Event reports also render AG Grid's own pagination footer. */
  .report-widget ::v-deep .ag-paging-panel {
    display: none !important;
  }
</style>
