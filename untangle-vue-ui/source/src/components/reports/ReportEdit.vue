<template>
  <report-edit
    :report="reportEntry"
    :categories="allCategories"
    :existing-reports="allReports"
    :table-fields="translatedTableFields"
    :condition-operators="globalConditionOperators"
    @save="onSave"
    @delete="onDelete"
    @cancel="onCancel"
  />
</template>

<script>
  import { mapGetters } from 'vuex'
  import { ReportEdit } from 'vuntangle'
  import { urlEncode } from '@/util/reports'
  import { tableFields } from '@/util/eventTableColumns'
  import { globalOperatorOptions } from '@/constants'

  export default {
    components: { ReportEdit },

    computed: {
      ...mapGetters('reports', ['allReports', 'allCategories']),

      reportEntry() {
        const found = this.allReports.find(
          r => urlEncode(r.category) === this.$route.params.cat && urlEncode(r.title) === this.$route.params.rep,
        )
        if (found) return found

        // TODO: remove — dummy report for UI verification
        return {
          title: 'Test Report',
          category: '',
          description: '',
          type: 'TEXT',
          table: 'sessions',
          displayOrder: 0,
          textString: '',
          textColumns: ['{0} sessions', 'count(*) as sessions', 'round(sum(s2p_bytes)/1048576, 3) as MB'],
          conditions: [
            {
              javaClass: 'com.untangle.app.reports.SqlCondition',
              column: 'bypassed',
              operator: '=',
              value: 'false',
              autoFormatValue: true,
            },
            {
              javaClass: 'com.untangle.app.reports.SqlCondition',
              column: 'protocol',
              operator: '!=',
              value: '17',
              autoFormatValue: true,
            },
            {
              javaClass: 'com.untangle.app.reports.SqlCondition',
              column: 'hostname',
              operator: 'like',
              value: '%untangle%',
              autoFormatValue: false,
            },
            {
              javaClass: 'com.untangle.app.reports.SqlCondition',
              column: 'client_intf',
              operator: '=',
              value: '2',
              autoFormatValue: true,
            },
            {
              javaClass: 'com.untangle.app.reports.SqlCondition',
              column: 'server_intf',
              operator: '=',
              value: '1',
              autoFormatValue: true,
            },
            {
              javaClass: 'com.untangle.app.reports.SqlCondition',
              column: 'username',
              operator: '!=',
              value: '',
              autoFormatValue: true,
            },
            {
              javaClass: 'com.untangle.app.reports.SqlCondition',
              column: 'c2s_bytes',
              operator: '>',
              value: '1000',
              autoFormatValue: true,
            },
            {
              javaClass: 'com.untangle.app.reports.SqlCondition',
              column: 's2c_bytes',
              operator: '<',
              value: '500000',
              autoFormatValue: false,
            },
            {
              javaClass: 'com.untangle.app.reports.SqlCondition',
              column: 'policy_id',
              operator: '=',
              value: '1',
              autoFormatValue: true,
            },
            {
              javaClass: 'com.untangle.app.reports.SqlCondition',
              column: 'server_country',
              operator: '=',
              value: 'US',
              autoFormatValue: true,
            },
            {
              javaClass: 'com.untangle.app.reports.SqlCondition',
              column: 'client_country',
              operator: '!=',
              value: 'CN',
              autoFormatValue: false,
            },
            {
              javaClass: 'com.untangle.app.reports.SqlCondition',
              column: 'server_port',
              operator: '=',
              value: '443',
              autoFormatValue: true,
            },
          ],
        }
      },

      translatedTableFields() {
        const result = {}
        for (const [table, fields] of Object.entries(tableFields)) {
          result[table] = fields.map(f => ({ value: f, text: this.$t(f) }))
        }
        return result
      },

      globalConditionOperators() {
        return globalOperatorOptions.map(op => ({ value: op.value, text: this.$t(op.text) }))
      },
    },

    methods: {
      onCancel() {
        if (this.reportEntry) {
          this.$router.push({
            name: 'report-details',
            params: {
              cat: this.$route.params.cat,
              rep: this.$route.params.rep,
            },
          })
        } else {
          this.$router.push({ name: 'reports' })
        }
      },
    },
  }
</script>
