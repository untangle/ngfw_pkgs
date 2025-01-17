import Main from '@/components/settings/Main.vue'

// network
import Dhcp from '@/components/settings/network/NgfwDhcp'
import Dns from '@/components/settings/network/NgfwDns.vue'
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
