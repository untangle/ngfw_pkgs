<template>
  <div class="chart-only">
    <!-- ReportChart creates the Highcharts legend only after its chromeless chart is ready for capture. -->
    <report-chart
      v-if="reportConfig && dataReady"
      :report="reportConfig"
      chromeless
      @fetch-data="onFetchData"
      @render-complete="onRenderComplete"
    />
    <!--
      FixedReports.java waits for this class after its highcharts-legend wait
      times out, allowing the screenshot to capture a useful empty state.
    -->
    <div v-if="noData" class="highcharts-no-data no-data-message">
      {{ $vuntangle.$t('no_data_available') }}
    </div>
  </div>
</template>

<script>
  import { ReportChart } from 'vuntangle'
  import reportsMixin from './reportsMixin'
  import { buildReportView } from '@/util/reportViews'
  import Util from '@/util/setupUtil'

  const GRAPH_REPORT_TYPES = ['PIE_GRAPH', 'TIME_GRAPH', 'TIME_GRAPH_DYNAMIC']

  /**
   * Bare report-chart entry point used by FixedReports.java when generating
   * emailed PNG attachments. The route supplies a report unique ID and an
   * exact epoch-millisecond range; this component resolves the normal migrated
   * report definition/data while omitting all interactive application chrome.
   *
   * Readiness remains compatible with the existing backend contract:
   * `.highcharts-legend` means the graph can be captured and
   * `.highcharts-no-data` means an empty/error state can be captured.
   */
  export default {
    name: 'ChartOnly',

    components: { ReportChart },

    mixins: [reportsMixin],

    /**
     * Supplies the context expected by Vuntangle's shared report mixin.
     * Vue merges these values with reportsMixin.provide automatically.
     * Interactive-only features are intentionally disabled for PNG rendering.
     */
    provide() {
      return {
        $timeRange: () => this.fixedTimeRange,
        $refreshTick: () => 0,
        $isPreview: () => false,
        $boxSettings: undefined,
        $applianceUid: () => undefined,
        $totalCountReport: () => ({ count: 0 }),
        $paginationReport: () => ({ pageNumber: 1, pageSize: 100 }),
        $useCursorPaginationReport: () => false,
        $hasQosmos: () => false,
        $actionFilter: () => null,
        $columnFilter: () => null,
      }
    },

    data() {
      return {
        // Mount ReportChart only after a non-empty backend response is normalized.
        dataReady: false,
        // Prevents the safety timer from replacing a successfully rendered chart.
        chartRendered: false,
        // Controls the backend-compatible `.highcharts-no-data` fallback marker.
        noData: false,
        // One-shot response consumed by ReportChart's immediate fetch-data event.
        cachedData: null,
      }
    },

    computed: {
      /** Validates the exact range supplied by FixedReports; invalid input must not silently use another range. */
      requestedTimeRange() {
        const start = Number(this.$route.query.startDate)
        const end = Number(this.$route.query.endDate)
        const startDate = new Date(start)
        const endDate = new Date(end)

        if (
          !Number.isFinite(startDate.getTime()) ||
          !Number.isFinite(endDate.getTime()) ||
          start <= 0 ||
          end <= start
        ) {
          return null
        }

        return { start, end }
      },

      /** Shape consumed by Vuntangle's injected `$timeRange` contract. */
      fixedTimeRange() {
        return {
          period: this.requestedTimeRange ? [this.requestedTimeRange.start, this.requestedTimeRange.end] : [null, null],
        }
      },

      /** Resolves the backend report definition from the ReportsContext-initialized store. */
      entry() {
        const { reportUniqueId } = this.$route.query
        if (!reportUniqueId) return null
        return this.allReports.find(r => r.uniqueId === reportUniqueId) || null
      },

      /** Translates supported graph entries through the same view builder used by ReportDetails and ReportEdit. */
      reportConfig() {
        if (!this.entry || !GRAPH_REPORT_TYPES.includes(this.entry.type)) return null
        const view = buildReportView(this.entry, this.timeZoneOffset, this.interfaceNameMap, this.policyNameMap)
        return view?.reports?.[0] || null
      },
    },

    async created() {
      // Safety timeout: if nothing renders within 60 seconds, show no-data fallback
      // so the headless browser's waitForElement("highcharts-no-data") can succeed.
      this._safetyTimer = setTimeout(() => {
        if (!this.chartRendered && !this.noData) {
          this.showNoData()
        }
      }, 60000)

      // Match the legacy GraphReport contract: only graph entries with a complete
      // fixed date range are eligible for screenshot generation.
      if (!this.entry || !this.reportConfig || !this.requestedTimeRange) {
        this.showNoData()
        return
      }

      // Policy labels are only needed for the small subset of graphs grouped by policy ID.
      if (this.entry.seriesRenderer === 'policy_id') {
        try {
          await this.$store.dispatch('reports/fetchPoliciesInfo')
        } catch {
          // Raw policy IDs remain valid chart labels if policy-manager is unavailable.
        }
      }

      await this.preFetchData()
    },

    beforeDestroy() {
      clearTimeout(this._safetyTimer)
    },

    methods: {
      /** Fetches and normalizes graph data before mounting Highcharts, preventing an empty legend from signaling readiness. */
      async preFetchData() {
        try {
          const { start, end } = this.requestedTimeRange

          const payload = await this.$store.dispatch('reports/fetchReportData', {
            entry: this.entry,
            conditions: [],
            startDate: new Date(start),
            endDate: new Date(end),
            limit: -1,
          })

          if (payload.data) {
            let result = null
            if (payload.data.series) {
              let arr = payload.data.series
              if (this.entry.seriesRenderer) {
                arr = arr.map(s => ({
                  ...s,
                  label: this.resolveSeriesLabel(s.label, this.entry.seriesRenderer),
                }))
              }
              // Signals Vuntangle chartOptions to consume the backend's already-pivoted series shape.
              Object.defineProperty(arr, '__prebuiltType', { value: 'prebuilt_series', enumerable: false })
              result = arr
            } else if (payload.data.slices) {
              let slices = payload.data.slices
              if (this.entry.seriesRenderer) {
                slices = slices.map(s => ({
                  ...s,
                  name: this.resolveSeriesLabel(s.name, this.entry.seriesRenderer),
                }))
              }
              // Signals Vuntangle chartOptions to consume the backend's already-aggregated slice shape.
              Object.defineProperty(slices, '__prebuiltType', { value: 'prebuilt_slices', enumerable: false })
              result = slices
            }

            const hasData = payload.data.series
              ? result?.some(series => Array.isArray(series.data) && series.data.length > 0)
              : result?.length > 0

            if (hasData) {
              this.cachedData = result
              this.dataReady = true
            } else {
              this.showNoData()
            }
          } else {
            this.showNoData()
          }
        } catch (err) {
          Util.handleException(err)
          this.showNoData()
        }
      },

      /** Stops the safety timer after Vuntangle confirms a visible chart with rendered points. */
      onRenderComplete() {
        this.chartRendered = true
        clearTimeout(this._safetyTimer)
      },

      /** Exposes the no-data marker consumed by FixedReports.java's timeout fallback. */
      showNoData() {
        this.dataReady = false
        this.noData = true
        clearTimeout(this._safetyTimer)
      },

      /**
       * Serves the prefetched response to ReportChart's initial request. Any later
       * request falls back to the normal ReportDetails host implementation.
       */
      onFetchData(payload) {
        if (this.cachedData) {
          payload.resolve(this.cachedData)
          this.cachedData = null
          return
        }
        return reportsMixin.methods.onFetchData.call(this, payload)
      },
    },
  }
</script>

<style scoped>
  /* The screenshot viewport is the complete chart canvas; no surrounding application layout is rendered. */
  .chart-only {
    display: flex;
    flex-direction: column;
    width: 100vw;
    height: 100vh;
    overflow: hidden;
  }

  .no-data-message {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 100%;
    height: 100%;
    font-size: 14px;
    color: #666;
  }
</style>
