<template>
  <div class="d-flex flex-column fill-height">
    <report-details
      :view-id="selectedUniqueId"
      :view-override="selectedReportView"
      :categories="categoriesForNav"
      :show-report-selector="true"
      :show-auto-refresh="true"
      :is-local-ui="false"
      @add-condition="onAddCondition"
      @remove-condition="onRemoveCondition"
      @clear-conditions="onClearConditions"
      @set-conditions="onSetConditions"
      @fetch-data="onFetchData"
      @view-report="onViewReport"
      @export-all-events="onExportAllEvents"
      @auto-refresh-change="onAutoRefreshChange"
      @edit-report="onEditReport"
    />

    <!-- Settings diff dialog — opened by the  action column on settings_changes rows -->
    <settings-diff-dialog v-model="diffDialogOpen" :file-name="diffFileName" />
  </div>
</template>

<script>
  import { mapGetters } from 'vuex'
  import { ReportDetails } from 'vuntangle'
  import reportsMixin from './reportsMixin'
  import SettingsDiffDialog from './SettingsDiffDialog.vue'
  import Util from '@/util/setupUtil'
  import util from '@/util/util'
  import { urlEncode, clientToServerDate } from '@/util/reports'
  import { buildReportView } from '@/util/reportViews'
  import { protocolNameMap } from '@/constants'

  export default {
    components: { ReportDetails, SettingsDiffDialog },

    mixins: [reportsMixin],

    provide() {
      return {
        $dateTimeRangeComponent: 'date-time-range-presets',
        $serverTimezoneOffsetMs: () => this.timeZoneOffset,
        $serverClockOffsetMs: () => this.serverClockOffsetMs,
        $refreshTick: () => this.refreshTick,
        $showTimeRangeHistory: true,
        $timeRangeSessionKey: () => this.$store.getters['reports/timeRangeSessionKey'],
      }
    },

    data() {
      return {
        // Diff dialog state — controlled by the  row action on settings_changes reports
        diffDialogOpen: false,
        diffFileName: '',

        // Last-used time range — stored each fetch so export uses the same window
        lastStartMs: null,
        lastEndMs: null,
        // Last-used extra conditions (non-time) — forwarded to server export
        lastConditions: [],

        // Auto-refresh state
        autoRefresh: false,
        refreshTick: 0,
        refreshTimer: null,
      }
    },

    computed: {
      ...mapGetters('reports', ['categoriesForNav', 'policyNameMap']),
      ...mapGetters('config', ['timeZoneOffset', 'serverClockOffsetMs', 'interfaceNameMap']),

      selectedUniqueId() {
        return this.allReports.find(
          r => urlEncode(r.category) === this.$route.params.cat && urlEncode(r.title) === this.$route.params.rep,
        )?.uniqueId
      },

      /**
       * Builds the view config for the currently selected report entry.
       * For EVENT_LIST, passes interfaceNameMap and policyNameMap so column cells
       * and the details panel show resolved names instead of raw IDs.
       * For settings_changes EVENT_LIST, passes onShowDiff callback so the
       * action column opens the diff dialog when clicked.
       */
      selectedReportView() {
        const entry = this.allReports.find(r => r.uniqueId === this.selectedUniqueId)
        return buildReportView(entry, this.timeZoneOffset, this.interfaceNameMap, this.policyNameMap, {
          onShowDiff: fileName => {
            this.diffFileName = fileName
            this.diffDialogOpen = true
          },
        })
      },
    },

    watch: {
      globalConditions() {
        this.refreshTick++
      },
    },

    beforeDestroy() {
      clearTimeout(this.refreshTimer)
    },

    /**
     * Fetch policy info once when the component mounts.
     * The action is a no-op if already loaded or if policy-manager is not installed.
     */
    async created() {
      await this.$store.dispatch('reports/fetchPoliciesInfo')
    },

    methods: {
      onEditReport(uniqueId) {
        const report = this.allReports.find(r => r.uniqueId === uniqueId)
        if (!report) return
        this.$router.push({
          name: 'report-edit',
          params: {
            cat: urlEncode(report.category),
            rep: urlEncode(report.title),
          },
        })
      },

      onAutoRefreshChange(val) {
        this.autoRefresh = val
        if (val) {
          this.refreshTick++
        } else {
          clearTimeout(this.refreshTimer)
          this.refreshTimer = null
        }
      },

      scheduleRefresh() {
        clearTimeout(this.refreshTimer)
        this.refreshTimer = null
        if (this.autoRefresh) {
          this.refreshTimer = setTimeout(() => {
            this.refreshTick++
          }, 5000)
        }
      },

      /**
       * Handles data fetch requests from the report display component.
       * Converts the raw epoch ms from the time picker to server-local dates before
       * dispatching to the store, so PostgreSQL receives the correct local time to filter on.
       */
      async onFetchData({ query, resolve }) {
        try {
          const entry = this.allReports.find(r => r.uniqueId === query.key)
          if (!entry) {
            resolve(null)
            return
          }

          // Extract time range boundaries from conditions and convert to server timezone.
          const gtCond = query.userConditions.find(c => c.column === 'time_stamp' && c.operator === 'GT')
          const ltCond = query.userConditions.find(c => c.column === 'time_stamp' && c.operator === 'LT')
          const startDate = clientToServerDate(gtCond?.value ?? Date.now() - 86400000, this.timeZoneOffset)
          const endDate = ltCond ? clientToServerDate(ltCond.value, this.timeZoneOffset) : null

          // Forward remaining conditions as SQL filter objects to the backend
          const conditions = query.userConditions
            .filter(c => c.column !== 'time_stamp')
            .map(c => ({
              javaClass: 'com.untangle.app.reports.SqlCondition',
              column: c.column,
              operator: c.operator,
              value: c.value,
            }))

          // Merge global conditions from Vuex store
          const globalConds = this.globalConditions.map(gc => ({
            javaClass: 'com.untangle.app.reports.SqlCondition',
            column: gc.column,
            operator: gc.operator,
            value: String(gc.value),
            autoFormatValue: gc.autoFormatValue !== false,
          }))
          conditions.push(...globalConds)

          // Store for use by the export handler
          this.lastStartMs = gtCond?.value ?? Date.now() - 86400000
          this.lastEndMs = ltCond?.value ?? null
          this.lastConditions = conditions

          // EVENT_LIST carries a user-selected limit from GenericEventList's limit selector.
          // All other report types use -1 (unlimited — backend applies its own aggregation).
          const limit = entry.type === 'EVENT_LIST' ? query.limit ?? 1000 : -1

          const payload = await this.$store.dispatch('reports/fetchReportData', {
            entry,
            conditions,
            startDate,
            endDate,
            limit,
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
          } else if (entry.type === 'EVENT_LIST') {
            resolve(payload.list)
          } else {
            resolve(null)
          }
        } catch (err) {
          Util.handleException(err)
          resolve(null)
        } finally {
          this.scheduleRefresh()
        }
      },

      /**
       * Exports all event rows for the current report as a CSV download.
       * Applies timezone conversion to the stored time range, then POSTs to /admin/download
       * with the entry definition, conditions, visible columns, and time boundaries.
       *
       * @param {string[]} visibleColumns - field names of columns currently visible in the grid
       */
      async onExportAllEvents({ visibleColumns }) {
        const entry = this.allReports.find(r => r.uniqueId === this.selectedUniqueId)
        if (!entry) return

        // Convert stored epoch ms boundaries to server-local dates for the download request
        const startDate = clientToServerDate(this.lastStartMs, this.timeZoneOffset)
        const endDate = this.lastEndMs ? clientToServerDate(this.lastEndMs, this.timeZoneOffset) : null

        // Build filename: "Category-Title-DD.MM.YYYY-HH:mm-DD.MM.YYYY-HH:mm"
        const fmt = d => {
          if (!d) return ''
          const p = n => String(n).padStart(2, '0')
          return `${p(d.getDate())}.${p(d.getMonth() + 1)}.${d.getFullYear()}-${p(d.getHours())}:${p(d.getMinutes())}`
        }
        const filename = `${entry.category}-${entry.title}-${fmt(startDate)}-${fmt(endDate || new Date())}`.replace(
          / /g,
          '_',
        )

        try {
          // util.downloadFile uses axios POST to the ABSOLUTE /admin/download URL, handles the
          // Blob response and triggers browser download — avoids the relative-URL problem where
          // form.action="download" resolved to /console/reports/.../download instead of /admin/download.
          await util.downloadFile('/admin/download', {
            type: 'eventLogExport',
            arg1: filename,
            arg2: JSON.stringify(entry),
            arg3: JSON.stringify(this.lastConditions),
            arg4: (visibleColumns || []).join(','),
            arg5: startDate ? String(startDate.getTime()) : '-1',
            arg6: endDate ? String(endDate.getTime()) : '-1',
          })
        } catch (err) {
          Util.handleException(err)
        }
      },
    },
  }
</script>
