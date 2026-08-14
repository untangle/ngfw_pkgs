import Reports from '@/components/reports/Reports.vue'
import ReportDetails from '@/components/reports/ReportDetails.vue'
import ReportEdit from '@/components/reports/ReportEdit.vue'

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
  {
    name: 'report-create',
    path: '/reports/create',
    component: ReportEdit,
    meta: { helpContext: 'report-edit' },
  },
  {
    name: 'report-edit',
    path: '/reports/edit/:cat/:rep',
    component: ReportEdit,
    meta: { helpContext: 'report-edit' },
  },
]
