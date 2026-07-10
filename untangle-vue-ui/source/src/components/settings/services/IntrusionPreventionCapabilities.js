import { intrusionPreventionDefaultCapabilities } from 'vuntangle'

export const ngfwCapabilities = {
  ...intrusionPreventionDefaultCapabilities,
  main: {
    ...intrusionPreventionDefaultCapabilities.main,
    appIcon: { render: true },
    powerStatus: { render: true },
    enableToggles: { render: false },
  },
  status: {
    ...intrusionPreventionDefaultCapabilities.status,
    powerToggle: { render: true },
    enableToggles: { render: false },
    memory: { render: true },
    metrics: { render: true },
    reports: { render: true },
  },
}
