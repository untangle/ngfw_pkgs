import SetupLayout from '@/layouts/SetupLayout'
import Main from '@/components/setup/Main.vue'
import License from '@/components/setup/License.vue'
import System from '@/components/setup/System.vue'
import Wan from '@/components/setup/Wan.vue'
import Complete from '@/components/setup/Complete.vue'
import Autoupgrades from '@/components/setup/Autoupgrades.vue'
import Internet from '@/components/setup/Internet.vue'
import Interface from '@/components/setup/Interface.vue'
import Network from '@/components/setup/Network.vue'
import { BlankLayout } from '@/layouts/BlankLayout.vue'

export default [
  {
    name: 'setup',
    path: '/wizardaa/',
    meta: { layout: BlankLayout },
    component: Main,
    children: [
      { name: 'setup-license', path: 'license', component: License, meta: { layout: SetupLayout } },
      { name: 'setup-system', path: 'system', component: System, meta: { layout: SetupLayout } },
      { name: 'setup-wan', path: 'wan', component: Wan, meta: { layout: SetupLayout } },
      { name: 'setup-complete', path: 'complete', component: Complete, meta: { layout: SetupLayout } },
      { name: 'setup-autoupgrades', path: 'autoupgrades', component: Autoupgrades, meta: { layout: SetupLayout } },
      { name: 'setup-internet', path: 'internet', component: Internet, meta: { layout: SetupLayout } },
      { name: 'setup-interface', path: 'interface', component: Interface, meta: { layout: SetupLayout } },
      { name: 'setup-network', path: 'network', component: Network, meta: { layout: SetupLayout } },
    ],
  },
]
