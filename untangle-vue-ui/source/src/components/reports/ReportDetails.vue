<template>
  <div class="d-flex flex-column fill-height">
    <report-details
      :view-id="selectedUniqueId"
      :view-override="selectedReportView"
      :categories="categoriesForNav"
      :show-report-selector="true"
      :show-auto-refresh="true"
      :show-settings="true"
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

  export default {
    components: { ReportDetails, SettingsDiffDialog },

    mixins: [reportsMixin],

    provide() {
      return {
        $isPreview: () => false,
        $dateTimeRangeComponent: 'date-time-range-presets',
        $refreshTick: () => this.refreshTick,
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
