import Main from '../components/settings/Main.vue'
// import Main from '../components/settings/network/SettingsInterface/index.vue'

// network
import Dhcp from '@/components/settings/network/Dhcp'
import Dns from '@/components/settings/network/Dns.vue'
import Interface from '@/components/settings/network/Interface.vue'
import NetworkTabs from '@/components/settings/network/NetworkTabs.vue'
import InterfaceEdit from '@/components/settings/network/InterfaceEdit.vue'
import DynamicRoutes from '@/components/settings/routing/DynamicRoutes.vue'
import Advanced from '@/components/settings/advanced/Advanced.vue'

// routing
import StaticRoutes from '@/components/settings/routing/StaticRoutes.vue'

// services
import DynamicBlockLists from '@/components/settings/services/DynamicBlockLists.vue'
// system  \
import About from '@/components/settings/system/About'
import Settings from '@/components/settings/system/Settings.vue'
import RulesList from '@/components/settings/rules/RulesList.vue'
import Troubleshooting from '@/components/settings/network/Troubleshooting.vue'
import DenialOfService from '@/components/settings/firewall/DenialOfService.vue'
export default [
  {
    name: 'settings',
    path: '/settings',
    component: Main,
    children: [
      {
        path: 'network',
        redirect: 'network/interfaces',
      },
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
        path: 'network/interfaces',
        component: Interface,
        meta: { helpContext: 'interface' },
      },
      {
        path: 'network/advanced',
        component: Advanced,
        meta: { helpContext: 'advanced' },
      },
      {
        path: 'network/interfaces/:device',
        component: InterfaceEdit,
      },
      {
        path: 'network/interfaces/add/:type',
        component: InterfaceEdit,
        // helpContext handled in InterfaceEdit component based on interface type
      },
      {
        path: 'network/troubleshooting',
        component: Troubleshooting,
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
        path: 'routing/dynamicRoutes',
        component: DynamicRoutes,
      },
      {
        path: 'firewall/denial-of-service',
        component: DenialOfService,
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
      {
        name: 'rule-list',
        path: ':category/:ruleType',
        component: RulesList,
      },
    ],
  },
]
