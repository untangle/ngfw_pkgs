import ReportsList from '@/components/Reports/ReportsList.vue'
import ReportDetailsView from '@/components/Reports/ReportDetailsView.vue'

export default [
  {
    path: '/reports',
    component: ReportsList,
    meta: { helpContext: 'reports' },
  },
  {
    path: '/reports/:cat/:rep',
    component: ReportDetailsView,
    meta: { helpContext: 'reports' },
  },
]
