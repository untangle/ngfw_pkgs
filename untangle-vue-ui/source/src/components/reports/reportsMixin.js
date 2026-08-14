import { mapGetters } from 'vuex'
import { urlEncode, tableContainsColumns } from '@/util/reports'
import { globalOperatorOptions, globalConditionColumns, protocolNameMap, conditionValueOptions } from '@/constants'
import { tableFields } from '@/util/eventTableColumns'

export default {
  provide() {
    return {
      $conditions: () => this.globalConditions,
      $conditionOperators: () => this.globalConditionOperators,
      $conditionColumns: () => this.globalConditionColumns,
      $conditionFormatValue: () => this.conditionFormatValue,
      $conditionValueOptions: () => conditionValueOptions,
      $disabledReportIds: () => this.disabledReportIds,
      $conditionTableFields: () => this.translatedTableFields,
      $tables: () => this.tables,
    }
  },

  created() {
    this.$store.dispatch('reports/fetchTables')
  },

  computed: {
    ...mapGetters('reports', ['allReports', 'globalConditions', 'tables']),

    /** Translates operator options for the global condition dropdowns. */
    globalConditionOperators() {
      return globalOperatorOptions.map(op => ({ value: op.value, text: this.$t(op.text) }))
    },

    /** Translates column options for the global condition dropdowns. */
    globalConditionColumns() {
      return globalConditionColumns.map(col => ({ value: col.value, text: this.$t(col.text) }))
    },

    /** Translates per-table field lists for the condition column picker. */
    translatedTableFields() {
      const result = {}
      for (const [table, fields] of Object.entries(tableFields)) {
        result[table] = fields.map(f => ({ value: f, text: this.$t(f) }))
      }
      return result
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

    /**
     * Navigates to the report editor for the given uniqueId.
     * If no uniqueId is provided, navigates to the create-new-report route.
     * @param {String} uniqueId - the report's uniqueId, or falsy to create a new report
     */
    onEditReport(uniqueId) {
      if (!uniqueId) {
        this.$router.push('/reports/create')
        return
      }
      const report = this.allReports.find(r => r.uniqueId === uniqueId)
      if (!report) return
      this.$router.push(`/reports/edit/${urlEncode(report.category)}/${urlEncode(report.title)}`)
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

    /** Replaces all global conditions with the set from the "More Conditions" dialog. */
    onSetConditions(conditions) {
      this.$store.commit('reports/SET_GLOBAL_CONDITIONS', conditions)
    },
  },
}
