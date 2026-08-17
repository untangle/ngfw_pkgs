<template>
  <report-edit
    :report="report"
    :categories="allCategories"
    :existing-reports="allReports"
    :table-fields="translatedTableFields"
    :condition-operators="globalConditionOperators"
    @save="onSave"
    @delete="onDelete"
    @cancel="onCancel"
    @refresh="onRefresh"
  />
</template>

<script>
  import { mapGetters } from 'vuex'
  import { ReportEdit } from 'vuntangle'
  import reportsMixin from './reportsMixin'
  import { urlEncode } from '@/util/reports'

  export default {
    name: 'ReportEditPage',
    components: { ReportEdit },
    mixins: [reportsMixin],

    computed: {
      ...mapGetters('reports', ['allCategories']),

      /**
       * Resolves the report entry from the store using the current route params.
       * Returns null for the create route so the editor starts with a blank form.
       */
      report() {
        if (this.$route.name === 'report-create') return null
        const { cat, rep } = this.$route.params
        return this.allReports.find(r => urlEncode(r.category) === cat && urlEncode(r.title) === rep) || null
      },
    },

    methods: {
      /**
       * Persists a new or updated report entry to the backend.
       * Generates a uniqueId for new reports, then navigates to the detail view on success.
       *
       * @param {Object} entry - the report definition from the editor form
       */
      async onSave(entry) {
        const isNew = !entry.uniqueId
        if (isNew) {
          entry.uniqueId = 'report-' + Math.random().toString(36).substr(2)
        }

        this.$store.commit('SET_LOADER', true)
        try {
          const result = await this.$store.dispatch('reports/saveReport', entry)
          if (result.success) {
            const successMessage = isNew ? 'report_created' : 'report_updated'
            this.$vuntangle.toast.add(this.$t(successMessage, { title: entry.title }))
            this.$router.push({
              name: 'report-details',
              params: { cat: urlEncode(entry.category), rep: urlEncode(entry.title) },
            })
          } else {
            this.$vuntangle.toast.add(this.$t('report_save_failed'), 'error')
          }
        } catch (error) {
          this.$vuntangle.toast.add(this.$t('report_save_failed'), 'error')
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      /**
       * Deletes a report after user confirmation.
       * Shows a confirm dialog, then dispatches the delete action and navigates
       * back to the reports list on success.
       *
       * @param {Object} entry - the report entry to delete
       */
      onDelete(entry) {
        this.$vuntangle.confirm.show({
          title: this.$t('warning'),
          message: this.$t('delete_report_confirm'),
          confirmLabel: this.$t('yes'),
          cancelLabel: this.$t('no'),
          action: async resolve => {
            resolve()
            this.$store.commit('SET_LOADER', true)
            try {
              const result = await this.$store.dispatch('reports/deleteReport', entry)
              if (result.success) {
                this.$vuntangle.toast.add(this.$t('report_deleted', { title: entry.title }))
                this.$router.push({ name: 'reports' })
              } else {
                this.$vuntangle.toast.add(this.$t('report_delete_failed'), 'error')
              }
            } catch (error) {
              this.$vuntangle.toast.add(this.$t('report_delete_failed'), 'error')
            } finally {
              this.$store.commit('SET_LOADER', false)
            }
          },
        })
      },

      /** Reloads the full report list from the backend. */
      async onRefresh() {
        await this.$store.dispatch('reports/loadReports')
      },
      /** Navigates back to the report detail view (edit mode) or the reports list (create mode). */
      onCancel() {
        if (this.$route.name === 'report-edit') {
          const { cat, rep } = this.$route.params
          this.$router.push({ name: 'report-details', params: { cat, rep } })
        } else {
          this.$router.push({ name: 'reports' })
        }
      },
    },
  }
</script>
