<template>
  <u-dialog
    :show-dialog="showDialog"
    title="Add/Edit Widgets"
    :buttons="dialogButtons"
    width="1000px"
    @close-dialog="$emit('close')"
    @add-report-widget="addWidget"
  >
    <div class="report-widget-dialog">
      <div v-if="!selectedReport" class="report-widget-dialog__report-list">
        <reports-nav
          :view-id="highlightedReportId"
          :categories="categories"
          menu-content-class="dashboard-report-selector-menu"
          class="report-widget-dialog__reports-nav"
          @view-report="selectReportById"
        />
      </div>

      <div v-else class="report-widget-dialog__preview">
        <div class="report-widget-dialog__back">
          <v-btn text small @click="clearReportSelection">
            <v-icon small class="mr-1">mdi-arrow-left</v-icon>
            Back
          </v-btn>
        </div>
        <div class="report-widget-dialog__chart">
          <host-active-graph
            v-if="selectedReportSupported && isTimeGraphReport"
            :entry="selectedReport"
            :time-range="previewTimeRange"
            @fetch-data="$emit('fetch-data', $event)"
          />
          <preview-report v-else :view="previewView" @fetch-data="$emit('fetch-data', $event)" />
        </div>
        <div class="report-widget-dialog__settings">
          <v-checkbox v-model="enabled" label="Enabled" dense hide-details class="mt-0" />
          <v-select
            v-model="refreshIntervalSec"
            :items="refreshOptions"
            label="Auto Refresh"
            dense
            outlined
            hide-details
            class="mt-2"
          />
          <div v-if="isEventReport" class="report-widget-dialog__columns mt-2">
            <div class="report-widget-dialog__columns-header">
              <strong>Columns:</strong>
              <v-checkbox
                v-model="useDefaultColumns"
                label="report defaults"
                dense
                hide-details
                class="mt-0 ml-3"
                @change="updateDefaultColumns"
              />
            </div>
            <v-combobox
              v-if="!useDefaultColumns"
              v-model="displayColumns"
              :items="displayColumnOptions"
              item-text="text"
              item-value="value"
              multiple
              chips
              small-chips
              deletable-chips
              dense
              outlined
              hide-details
              class="mt-1"
            />
          </div>
        </div>
      </div>
    </div>
  </u-dialog>
</template>

<script>
  import { UDialog } from 'vuntangle'
  import PreviewReport from '../../../node_modules/vuntangle/src/shared/Reports/components/PreviewReport.vue'
  import ReportsNav from '../../../node_modules/vuntangle/src/shared/Reports/components/ReportsNav.vue'
  import HostActiveGraph from '../widgets/HostActiveGraph.vue'
  import { tableFields } from '@/util/eventTableColumns'
  export default {
    name: 'ReportWidgetDialog',
    components: { HostActiveGraph, PreviewReport, ReportsNav, UDialog },
    provide() {
      return {
        $isLocalUi: false,
        $showReportSelector: true,
        $disabledReportIds: () => [],
        $dateTimeRangeComponent: 'span',
        $conditions: () => [],
        $conditionOperators: () => [],
        $conditionColumns: () => [],
        $conditionFormatValue: () => (column, value) => value,
        $conditionValueOptions: () => ({}),
        $enableExportCsv: () => false,
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
        $refreshTick: () => 0,
      }
    },
    props: {
      showDialog: { type: Boolean, default: false },
      categories: { type: Array, default: () => [] },
      reports: { type: Array, default: () => [] },
      supportedReportIds: { type: Array, default: () => [] },
      initialReportId: { type: String, default: '' },
      buildReportView: { type: Function, default: null },
    },
    data: () => ({
      highlightedReportId: null,
      selectedReportId: null,
      enabled: true,
      refreshIntervalSec: 60,
      displayColumns: null,
      useDefaultColumns: true,
      previewTimeRange: { period: [Date.now() - 3600000, null] },
      refreshOptions: [
        { value: 10, text: '10 seconds' },
        { value: 30, text: '30 seconds' },
        { value: 60, text: '1 minute' },
        { value: 120, text: '2 minutes' },
        { value: 300, text: '5 minutes' },
        { value: 0, text: 'never' },
      ],
    }),
    computed: {
      selectedReport() {
        return this.reports.find(report => report.uniqueId === this.selectedReportId) || null
      },
      selectedReportSupported() {
        return this.supportedReportIds.includes(this.selectedReportId)
      },
      isEventReport() {
        return this.selectedReport?.type === 'EVENT_LIST'
      },
      isTimeGraphReport() {
        return this.selectedReport?.type === 'TIME_GRAPH' || this.selectedReport?.type === 'TIME_GRAPH_DYNAMIC'
      },
      displayColumnOptions() {
        const fields = tableFields[this.selectedReport?.table] || []
        return fields.map(value => ({ value, text: this.$t(value) }))
      },
      previewView() {
        if (!this.buildReportView || !this.selectedReport) {
          return null
        }
        const report =
          this.isEventReport && !this.useDefaultColumns
            ? { ...this.selectedReport, defaultColumns: this.displayColumns || [] }
            : this.selectedReport
        return this.buildReportView(report)
      },
      dialogButtons() {
        return [
          { name: 'Cancel', handler: 'close-dialog' },
          {
            name: 'Add',
            handler: 'add-report-widget',
            disabled: !this.selectedReport || !this.selectedReportSupported,
          },
        ]
      },
    },
    watch: {
      showDialog(value) {
        if (value) {
          this.reset()
        }
      },
      categories(value) {
        if (this.showDialog && !this.highlightedReportId && value.length && this.initialReportId) {
          this.highlightedReportId = this.initialReportId
        }
      },
    },
    methods: {
      reset() {
        this.highlightedReportId = this.initialReportId || null
        this.selectedReportId = null
        this.enabled = true
        this.refreshIntervalSec = 60
        this.displayColumns = null
        this.useDefaultColumns = true
        this.previewTimeRange = { period: [Date.now() - 3600000, null] }
      },
      selectReport(report) {
        this.highlightedReportId = report.id
        this.selectedReportId = report.id
        this.enabled = true
        this.refreshIntervalSec = 60
        const selectedReport = this.reports.find(item => item.uniqueId === report.id) || report
        this.displayColumns = selectedReport.defaultColumns ? [...selectedReport.defaultColumns] : null
        this.useDefaultColumns = !this.isEventReport
      },
      selectReportById(reportId) {
        const report = this.reports.find(item => item.uniqueId === reportId)
        if (report) {
          this.selectReport({ id: report.uniqueId })
        }
      },
      clearReportSelection() {
        this.selectedReportId = null
      },
      updateDefaultColumns(value) {
        this.useDefaultColumns = value
        if (value) {
          this.displayColumns = null
        } else if (!Array.isArray(this.displayColumns)) {
          this.displayColumns = [...(this.selectedReport?.defaultColumns || [])]
        }
      },
      addWidget() {
        if (!this.selectedReport || !this.selectedReportSupported) {
          return
        }
        this.$emit('add', {
          report: this.selectedReport,
          enabled: this.enabled,
          refreshIntervalSec: this.refreshIntervalSec,
          displayColumns: this.isEventReport && !this.useDefaultColumns ? this.displayColumns || [] : null,
        })
      },
    },
  }
</script>
<style lang="scss" scoped>
  .report-widget-dialog {
    display: flex;
    height: 500px;
    max-height: calc(100vh - 220px);
    gap: 16px;
    overflow: hidden;
  }
  .report-widget-dialog__report-list {
    height: 100%;
    max-height: 100%;
    min-width: 0;
    flex: 1;
    overflow-y: auto;
  }
  .report-widget-dialog__reports-nav {
    padding: 8px;
  }
  .report-widget-dialog__settings {
    border-top: 1px solid #ddd;
    padding: 8px 0 0;
  }
  .report-widget-dialog__preview {
    display: flex;
    min-height: 0;
    min-width: 0;
    flex: 1;
    flex-direction: column;
    overflow-y: auto;
  }
  .report-widget-dialog__chart {
    min-height: 390px;
    flex: 1;
    ::v-deep .v-card__title .v-btn:has(.mdi-refresh),
    ::v-deep .v-card__title .v-btn:has(.mdi-eye-off-outline),
    ::v-deep .v-card__title .v-btn:has(.mdi-eye-outline) {
      display: none;
    }
    // Event reports expose a 100/500/1000 Events limit selector in the shared grid toolbar.
    ::v-deep .v-select[style*='160px'] {
      display: none;
    }
    // Hide the shared grid pagination footer in dashboard previews.
    ::v-deep .v-card.mr-4 {
      display: none;
    }
    ::v-deep .v-card > .d-flex.flex-column.flex-grow-1 > .v-card {
      display: none !important;
    }
    // Event reports also render AG Grid's own pagination footer.
    ::v-deep .ag-paging-panel {
      display: none !important;
    }
  }
  .report-widget-dialog__columns-header {
    display: flex;
    align-items: center;
    min-height: 32px;
  }
  .report-widget-dialog__back {
    display: flex;
    justify-content: flex-start;
  }
</style>
<style lang="scss">
  // Keep the dashboard report selector width stable regardless of report names/descriptions.
  .dashboard-report-selector-menu {
    width: 860px !important;
    max-width: calc(100vw - 32px);
  }
  .dashboard-report-selector-menu > .v-card {
    width: 100%;
  }
</style>
