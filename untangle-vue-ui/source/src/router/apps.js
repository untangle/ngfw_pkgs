import Main from '@/components/Apps/Main.vue'
import AppMain from '@/components/Apps/AppMain.vue'
import AppsView from '@/components/Apps/AppsView.vue'

export default [
  {
    path: '/apps',
    component: Main,
    children: [
      {
        path: ':policyId',
        name: 'apps',
        component: AppsView,
      },
      {
        path: ':policyId/:appName',
        name: 'app-main',
        component: AppMain,
      },
    ],
  },
]
