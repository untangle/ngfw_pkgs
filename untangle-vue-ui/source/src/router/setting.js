import Main from '@/components/settings/Main.vue'

// network
import Dhcp from '@/components/settings/network/NgfwDhcp'
import Dns from '@/components/settings/network/NgfwDns.vue'
import Interface from '@/components/settings/network/Interface.vue'
import NetworkTabs from '@/components/settings/network/NetworkTabs.vue'
import InterfaceEdit from '@/components/settings/network/InterfaceEdit.vue'
// import Interfaces from '@/components/settings/network/Interfaces.vue'

// routing
import StaticRoutes from '@/components/settings/routing/NgfwStaticRoutes.vue'

// services
import DynamicBlockLists from '@/components/settings/services/DynamicBlockLists.vue'
// system  \
import About from '@/components/settings/system/NgfwAbout'
import Settings from '@/components/settings/system/NgfwSettings.vue'
export default [
  {
    name: 'settings',
    path: '/settings',
    component: Main,
    children: [
      {
        path: 'network/dhcp',
        component: Dhcp,
        meta: { helpContext: 'dhcp' },
      },
      {
        path: 'network/dns',
        component: Dns,
        meta: { helpContext: 'dns' },
      },
      {
        path: 'network/interface',
        component: Interface,
        meta: { helpContext: 'dns' },
      },
      {
        path: 'network/interface/:device',
        component: InterfaceEdit,
      },
      {
        path: 'network/interface/add/:type',
        component: InterfaceEdit,
        // helpContext handled in InterfaceEdit component based on interface type
      },
      {
        path: 'network/networkTabs',
        component: NetworkTabs,
        meta: { helpContext: 'dns' },
      },
      {
        path: 'routing/routes',
        component: StaticRoutes,
        meta: { helpContext: 'static_routes' },
      },
      {
        path: 'services/dynamic-blocklist',
        component: DynamicBlockLists,
        meta: { helpContext: 'dynamic_lists' },
      },
      {
        path: 'system/about',
        component: About,
        meta: { helpContext: 'system_settings' },
      },
      {
        path: 'system/settings',
        component: Settings,
        meta: { helpContext: 'system_settings' },
      },
    ],
  },
]
