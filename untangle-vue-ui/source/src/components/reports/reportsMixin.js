import { mapGetters } from 'vuex'
import { urlEncode } from '@/util/reports'

export default {
  computed: {
    ...mapGetters('reports', ['allReports']),
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
  },
}
