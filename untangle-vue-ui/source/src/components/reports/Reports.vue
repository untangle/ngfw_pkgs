<template>
  <reports
    :features="features"
    :all-reports="allReports"
    :app-categories="allCategories"
    :disabled-report-ids="disabledReportIds"
    :conditions="globalConditions"
    :operators="globalConditionOperators"
    :condition-columns="globalConditionColumns"
    :format-value="conditionFormatValue"
    :column-value-options="conditionValueOptions"
    @add-condition="onAddCondition"
    @remove-condition="onRemoveCondition"
    @clear-conditions="onClearConditions"
    @view-report="onViewReport"
    @export-category="onExportCategory"
  >
    <template #actions>
      <u-btn @click="onExportAll">{{ $t('export') }}</u-btn>
    </template>
  </reports>
</template>
<script>
  import { mapActions, mapGetters } from 'vuex'
  import { Reports } from 'vuntangle'
  import reportsMixin from './reportsMixin'
  import { exportCategoryReports } from '@/util/reports'

  export default {
    components: { Reports },

    mixins: [reportsMixin],

    data() {
      return {
        features: {
          maxReportsPerCard: 4,
          showViewMore: true,
          maximizableCards: true,
          exportable: true,
          enableSearch: true,
        },
      }
    },

    computed: {
      ...mapGetters('reports', ['allCategories']),
    },

    created() {
      this.loadReports()
    },

    methods: {
      ...mapActions('reports', ['loadReports']),

      async onExportCategory(categoryName) {
        await exportCategoryReports(this.allReports, categoryName)
      },

      async onExportAll() {
        await exportCategoryReports(this.allReports)
      },
    },
  }
</script>
