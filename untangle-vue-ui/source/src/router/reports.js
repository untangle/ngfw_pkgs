import Reports from '@/components/reports/Reports.vue'
import ReportDetails from '@/components/reports/ReportDetails.vue'
import ReportEdit from '@/components/reports/ReportEdit.vue'
import ChartOnly from '@/components/reports/ChartOnly.vue'
import store from '@/store'
import { urlEncode } from '@/util/reports'

export default [
  {
    name: 'reports',
    path: '/reports',
    component: Reports,
    meta: { helpContext: 'reports', requiresReportsApp: true },
  },
  {
    name: 'report-details',
    path: '/reports/:cat/:rep',
    component: ReportDetails,
    meta: { helpContext: 'report-details', requiresReportsApp: true },
  },
  {
    name: 'report-create',
    path: '/reports/create',
    component: ReportEdit,
    meta: { helpContext: 'report-edit', requiresReportsApp: true, requiresAdmin: true },
  },
  {
    name: 'report-chart-only',
    path: '/reports/chart',
    component: ChartOnly,
    meta: { chartOnly: true },
  },
  {
    name: 'report-category',
    path: '/reports/:cat',
    meta: { helpContext: 'reports', requiresReportsApp: true },
    // Redirect a report category URL to its first available report.
    beforeEnter(to, from, next) {
      const { cat } = to.params
      const report = store.state.reports.allReports.find(r => urlEncode(r.category) === cat)
      if (report) {
        next({ name: 'report-details', params: { cat, rep: urlEncode(report.title) }, replace: true })
      } else {
        // Fall back to the Reports page if the category does not exist.
        next({ name: 'reports', replace: true })
      }
    },
  },
  {
    name: 'report-edit',
    path: '/reports/edit/:cat/:rep',
    component: ReportEdit,
    meta: { helpContext: 'report-edit', requiresReportsApp: true, requiresAdmin: true },
  },
]
