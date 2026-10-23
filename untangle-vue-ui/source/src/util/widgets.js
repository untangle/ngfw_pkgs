/**
 * Widget definitions for the fixed dashboard widgets.
 * ReportEntry widgets are resolved dynamically from the Reports store.
 */
export const widgetComponents = {
  Information: {
    component: 'Info',
    width: 1,
    interval: 10,
  },
  Resources: {
    component: 'Resources',
    width: 1,
    interval: 10,
  },
  CPULoad: {
    component: 'CpuLoad',
    width: 1,
    interval: 10,
  },
  NetworkInformation: {
    component: 'NetworkInformation',
    width: 1,
    interval: 10,
  },
  NetworkLayout: {
    component: 'NetworkLayout',
    width: 1,
    interval: 10,
  },
  MapDistribution: {
    component: 'MapDistribution',
    width: 1,
    interval: 10,
  },
  PolicyOverview: {
    component: 'PolicyOverview',
    width: 1,
    interval: 10,
  },
  Notifications: {
    component: 'Notifications',
    width: 1,
    interval: 10,
  },
}

export function removeDashboardLayout() {
  window.sessionStorage.removeItem('dashboard-layout')
}
