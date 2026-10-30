/**
 * Widget definitions for the fixed dashboard widgets.
 * ReportEntry widgets are resolved dynamically from the Reports store.
 */
export const widgetComponents = {
  Information: {
    component: 'Information',
    width: 1,
    interval: 10,
    title: 'information',
  },
  Resources: {
    component: 'Resources',
    width: 1,
    interval: 10,
    title: 'resources',
  },
  CPULoad: {
    component: 'CpuLoad',
    width: 1,
    interval: 10,
    title: 'cpu_load',
  },
  NetworkInformation: {
    component: 'NetworkInformation',
    width: 1,
    interval: 10,
    title: 'network_information',
  },
  NetworkLayout: {
    component: 'NetworkLayout',
    width: 2,
    interval: 30,
    title: 'network_layout',
  },
  MapDistribution: {
    component: 'MapDistribution',
    width: 1,
    interval: 10,
    title: 'map_distribution',
  },
  PolicyOverview: {
    component: 'PolicyOverview',
    width: 1,
    interval: 10,
    title: 'policy_overview',
  },
  Notifications: {
    component: 'Notifications',
    width: 1,
    interval: 10,
    title: 'notifications',
  },
}

export function removeDashboardLayout() {
  window.sessionStorage.removeItem('dashboard-layout')
}
