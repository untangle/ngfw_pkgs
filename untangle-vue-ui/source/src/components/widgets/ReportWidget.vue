<template>
  <u-widget class="report-widget" :title="title" :enable-expand="false">
    <host-active-graph
      v-if="isTimeGraphReport"
      :entry="report"
      :is-widget="true"
      :refresh-tick="refreshTick"
      :time-range="previewTimeRange"
      @fetch-data="onFetchData"
    />
    <preview-report v-else-if="view" :view="view" @fetch-data="onFetchData" />
    <div v-else class="report-widget-empty">{{ $t('no_data_available') }}</div>
  </u-widget>
</template>
<script>
  import PreviewReport from '../../../node_modules/vuntangle/src/shared/Reports/components/PreviewReport.vue'
  import reportsMixin from '../reports/reportsMixin'
  import HostActiveGraph from './HostActiveGraph.vue'
  import { buildReportView as buildReportViewConfig } from '@/util/reportViews'
  export default {
    components: { HostActiveGraph, PreviewReport },
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
    },
    data() {
      return {
        refreshTick: 0,
        refreshTimeout: null,
        previewTimeRange: {
          period: [Date.now() - this.timeframe * 3600000, null],
        },
      }
    },
    computed: {
      isTimeGraphReport() {
        return this.report?.type === 'TIME_GRAPH' || this.report?.type === 'TIME_GRAPH_DYNAMIC'
      },
      view() {
        return buildReportViewConfig(
          this.reportForDisplay,
          this.timeZoneOffset,
          this.interfaceNameMap || {},
          this.policyNameMap || {},
        )
      },
      reportForDisplay() {
        if (this.report?.type !== 'EVENT_LIST' || this.displayColumns == null) {
          return this.report
        }
        return { ...this.report, defaultColumns: this.displayColumns }
      },
    },
    watch: {
      interval: 'scheduleRefresh',
      timeframe(value) {
        this.previewTimeRange = {
          period: [Date.now() - value * 3600000, null],
        }
      },
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
        if (this.interval > 0) {
          this.refreshTimeout = setTimeout(() => {
            this.refreshTick += 1
            this.scheduleRefresh()
          }, this.interval * 1000)
        }
      },
    },
  }
</script>
<style scoped>
  /* Report widgets already have a title supplied by UWidget. */
  .report-widget ::v-deep .preview-report .v-card__title,
  .report-widget ::v-deep .preview-report .v-divider {
    display: none;
  }
  .report-widget-empty {
    display: flex;
    min-height: 200px;
    align-items: center;
    justify-content: center;
    color: #777;
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
