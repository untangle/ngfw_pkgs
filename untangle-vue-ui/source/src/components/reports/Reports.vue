<template>
  <reports
    :features="features"
    :all-reports="allReports"
    :app-categories="allCategories"
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
  import { exportCategoryReports } from '@/util/reports'
  export default {
    components: { Reports },
    data() {
      return {
        features: {
          maxReportsPerCard: 4,
          showViewMore: true,
          maximizableCards: true,
          exportable: true,
        },
      }
    },

    computed: {
      ...mapGetters('reports', ['allReports', 'allCategories']),
    },

    created() {
      this.loadReports()
    },

    methods: {
      ...mapActions('reports', ['loadReports']),

      onViewReport() {
        // TODO: navigate to the selected report detail view
      },

      onExportCategory(categoryName) {
        exportCategoryReports(this.allReports, categoryName)
      },

      onExportAll() {
        exportCategoryReports(this.allReports)
      },
    },
  }
</script>
