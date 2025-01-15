import SetupLayout from '@/layouts/SetupLayout'
import Main from '@/components/setup/Main.vue'
import License from '@/components/setup/License.vue'
// import System from '@/components/setup/System.vue'
// import Wan from '@/components/setup/Wan.vue'
// import Lte from '@/components/setup/Lte.vue'
// import Wifi from '@/components/setup/Wifi.vue'
import Complete from '@/components/setup/Complete.vue'

export default [
  {
    name: 'setup',
    path: '/setup/',
    meta: { layout: SetupLayout },
    component: Main,
    children: [
      { name: 'setup-license', path: 'license', component: License, meta: { layout: SetupLayout } },
      //   { name: 'setup-system', path: 'system', component: System, meta: { layout: SetupLayout } },
      //   { name: 'setup-wan', path: 'wan', component: Wan, meta: { layout: SetupLayout } },
      //   { name: 'setup-lte', path: 'lte', component: Lte, meta: { layout: SetupLayout } },
      //   { name: 'setup-wifi', path: 'wifi', component: Wifi, meta: { layout: SetupLayout } },
      { name: 'setup-complete', path: 'complete', component: Complete, meta: { layout: SetupLayout } },
    ],
  },
]
