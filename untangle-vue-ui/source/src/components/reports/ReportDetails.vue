<template>
  <div class="d-flex flex-column fill-height">
    <report-details
      :view-id="selectedUniqueId"
      :view-override="selectedReportView"
      :categories="categoriesForNav"
      :show-report-selector="true"
      :is-local-ui="false"
      @fetch-data="onFetchData"
      @view-report="onViewReport"
    />
  </div>
</template>

<script>
  import { mapGetters } from 'vuex'
  import { ReportDetails } from 'vuntangle'
  import reportsMixin from './reportsMixin'
  import Util from '@/util/setupUtil'
  import { urlEncode } from '@/util/reports'
  import { buildReportView } from '@/util/reportViews'
  import { protocolNameMap } from '@/constants'

  export default {
    components: { ReportDetails },

    mixins: [reportsMixin],

    provide() {
      return {
        $dateTimeRangeComponent: 'date-time-range-presets',
        $serverTimezoneOffsetMs: () => this.timeZoneOffset,
        $serverClockOffsetMs: () => this.serverClockOffsetMs,
      }
    },

    computed: {
      ...mapGetters('reports', ['allReports', 'categoriesForNav']),
      ...mapGetters('config', ['timeZoneOffset', 'serverClockOffsetMs']),

      selectedUniqueId() {
        return this.allReports.find(
          r => urlEncode(r.category) === this.$route.params.cat && urlEncode(r.title) === this.$route.params.rep,
        )?.uniqueId
      },

      /**
       * Builds the view config for the currently selected report entry,
       * selecting the correct display component based on the report type.
       */
      selectedReportView() {
        const entry = this.allReports.find(r => r.uniqueId === this.selectedUniqueId)
        return buildReportView(entry)
      },
    },

    methods: {
      /**
       * Handles data fetch requests for the selected report entry.
       * Extracts the time range from query conditions, forwards additional filters to the
       * backend, and resolves with the processed result ready for chart rendering.
       *
       * Chart reports (time-series and pie/column):
       *   - Backend returns pre-built series or slice arrays
       *   - Slices whose group column is protocol have numbers resolved to display names
       *
       * Text reports:
       *   - Backend returns raw rows; placeholder values are substituted into the template string
       */
      async onFetchData({ query, resolve }) {
        try {
          const entry = this.allReports.find(r => r.uniqueId === query.key)
          if (!entry) {
            resolve(null)
            return
          }

          // Extract the time range boundaries from the query conditions
          const gtCond = query.userConditions.find(c => c.column === 'time_stamp' && c.operator === 'GT')
          const ltCond = query.userConditions.find(c => c.column === 'time_stamp' && c.operator === 'LT')
          const startDate = gtCond ? new Date(gtCond.value) : new Date(Date.now() - 86400000)
          const endDate = ltCond ? new Date(ltCond.value) : null

          // Forward remaining conditions as filters to the backend query
          const conditions = query.userConditions
            .filter(c => c.column !== 'time_stamp')
            .map(c => ({
              javaClass: 'com.untangle.app.reports.SqlCondition',
              column: c.column,
              operator: c.operator,
              value: c.value,
            }))

          const payload = await this.$store.dispatch('reports/fetchReportData', {
            entry,
            conditions,
            startDate,
            endDate,
            limit: -1,
          })

          if (payload.data) {
            // Chart response: pre-built series or slice data
            const backendData = payload.data

            if (backendData.series) {
              const arr = backendData.series
              Object.defineProperty(arr, '__prebuiltType', { value: 'prebuilt_series', enumerable: false })
              resolve(arr)
            } else if (backendData.slices) {
              let slices = backendData.slices

              // Resolve protocol numbers to display names for reports grouped by protocol
              if (entry.type === 'PIE_GRAPH' && entry.pieGroupColumn === 'protocol') {
                slices = slices.map(s => ({
                  ...s,
                  name: protocolNameMap[parseInt(s.name)] || s.name,
                }))
              }

              Object.defineProperty(slices, '__prebuiltType', { value: 'prebuilt_slices', enumerable: false })
              resolve(slices)
            } else {
              resolve(null)
            }
          } else if (entry.type === 'TEXT') {
            resolve(payload.text)
          } else {
            resolve(null)
          }
        } catch (err) {
          Util.handleException(err)
          resolve(null)
        }
      },
    },
  }
</script>
