<template>
  <reports
    :features="features"
    :all-reports="allReports"
    :app-categories="allCategories"
    @add-condition="onAddCondition"
    @remove-condition="onRemoveCondition"
    @clear-conditions="onClearConditions"
    @set-conditions="onSetConditions"
    @view-report="onViewReport"
    @export-category="onExportCategory"
    @import-reports="onImportReports"
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
          importable: true,
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

      /**
       * Handles importing reports by validating titles, checking for conflicts,
       * and dispatching the import action to the store.
       * Dialog stays open on validation/import failure; closes only on success via callback.
       *
       * @param {Object} params - The import parameters
       * @param {Array<Object>} params.reports - Array of report objects to import
       * @param {boolean} params.replaceAll - If true, replaces all existing reports; otherwise merges with conflict check
       * @param {Function} params.cb - Callback to signal success/failure to the dialog
       */
      async onImportReports({ reports, replaceAll, cb }) {
        const hasEmptyTitle = reports.some(r => !r.title || !r.title.trim())
        if (hasEmptyTitle) {
          this.$vuntangle.toast.add(this.$t('report_title_required'), 'error')
          cb(new Error('report_title_required'), false)
          return
        }

        if (!replaceAll) {
          const existingTitleSet = new Set(this.allReports.map(r => r.title))
          const hasConflicts = reports.some(r => existingTitleSet.has(r.title))
          if (hasConflicts) {
            this.$vuntangle.toast.add(this.$t('import_reports_conflict_error'), 'error')
            cb(new Error('import_reports_conflict_error'), false)
            return
          }
        }

        const preparedReports = this.prepareReportsForImport(reports, replaceAll)
        const result = await this.$store.dispatch('reports/importReports', { reports: preparedReports, replaceAll })
        if (result.success) {
          this.$vuntangle.toast.add(`${preparedReports.length} Report(s) imported!`)
          cb(null, true)
          if (preparedReports.length === 1) {
            this.onViewReport(preparedReports[0].uniqueId)
          }
        } else {
          cb(result.error || new Error('import_failed'), false)
        }
      },

      /**
       * Prepares report objects for import by stripping computed/internal fields
       * and assigning new unique IDs where necessary to avoid collisions.
       *
       * @param {Array<Object>} reports - Raw report objects from the imported file
       * @param {boolean} replaceAll - If true, preserves existing uniqueIds; otherwise regenerates on conflict
       * @returns {Array<Object>} Cleaned report objects ready for store dispatch
       */
      prepareReportsForImport(reports, replaceAll) {
        const COMPUTED_FIELDS = ['localizedTitle', 'localizedDescription', 'slug', 'categorySlug', 'url', 'icon', '_id']
        const existingIdSet = new Set(this.allReports.map(r => r.uniqueId))

        return reports.map(r => {
          const rep = { ...r }
          COMPUTED_FIELDS.forEach(f => delete rep[f])
          delete rep._importIndex
          rep.javaClass = 'com.untangle.app.reports.ReportEntry'
          if (!rep.uniqueId || (!replaceAll && existingIdSet.has(rep.uniqueId))) {
            rep.uniqueId = 'report-' + Math.random().toString(36).substring(2)
          }
          return rep
        })
      },
    },
  }
</script>
