import Reports from '@/components/reports/Reports.vue'
import ReportDetails from '@/components/reports/ReportDetails.vue'

export default [
  {
    name: 'reports',
    path: '/reports',
    component: Reports,
    meta: { helpContext: 'reports' },
  },
  {
    name: 'report-details',
    path: '/reports/:cat/:rep',
    component: ReportDetails,
    meta: { helpContext: 'report-details' },
  },
]
