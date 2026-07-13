import { mapGetters } from 'vuex'
import { urlEncode, tableContainsColumns } from '@/util/reports'
import { globalOperatorOptions, globalConditionColumns, protocolNameMap, conditionValueOptions } from '@/constants'

export default {
  provide() {
    return {
      $conditions: () => this.globalConditions,
      $conditionOperators: () => this.globalConditionOperators,
      $conditionColumns: () => this.globalConditionColumns,
      $conditionFormatValue: () => this.conditionFormatValue,
      $conditionValueOptions: () => conditionValueOptions,
      $disabledReportIds: () => this.disabledReportIds,
    }
  },

  computed: {
    ...mapGetters('reports', ['allReports', 'globalConditions']),

    globalConditionOperators() {
      return globalOperatorOptions.map(op => ({ value: op.value, text: this.$t(op.text) }))
    },

    globalConditionColumns() {
      return globalConditionColumns.map(col => ({ value: col.value, text: this.$t(col.text) }))
    },

    /** Unique column names currently used across all active global conditions. */
    conditionColumns() {
      return [...new Set(this.globalConditions.map(c => c.column))]
    },

    /**
     * Report uniqueIds that should be disabled because their database table
     * does not contain one or more columns required by the active global conditions.
     */
    disabledReportIds() {
      if (!this.conditionColumns.length) return []
      return this.allReports
        .filter(r => r.table && !tableContainsColumns(r.table, this.conditionColumns))
        .map(r => r.uniqueId)
    },

    /**
     * Returns a formatter function that resolves raw column values to display names.
     * Currently handles protocol numbers → "TCP [6]" style names.
     */
    conditionFormatValue() {
      return (column, value) => {
        if (column === 'protocol') return protocolNameMap[value] || value
        return value
      }
    },
  },

  methods: {
    /**
     * Navigates to the report details page for the given uniqueId.
     * Resolves the report from the store, then builds cat/rep route params.
     * @param {String} uniqueId - the report's uniqueId from the backend
     */
    onViewReport(uniqueId) {
      const report = this.allReports.find(r => r.uniqueId === uniqueId)
      if (!report) return
      this.$router.push({
        name: 'report-details',
        params: {
          cat: urlEncode(report.category),
          rep: urlEncode(report.title),
        },
      })
    },

    /** Adds a new global condition to the Vuex store. */
    onAddCondition(condition) {
      this.$store.commit('reports/ADD_GLOBAL_CONDITION', condition)
    },

    /** Removes a global condition by index from the Vuex store. */
    onRemoveCondition(index) {
      this.$store.commit('reports/REMOVE_GLOBAL_CONDITION', index)
    },

    /** Clears all active global conditions from the Vuex store. */
    onClearConditions() {
      this.$store.commit('reports/CLEAR_GLOBAL_CONDITIONS')
    },
  },
}
