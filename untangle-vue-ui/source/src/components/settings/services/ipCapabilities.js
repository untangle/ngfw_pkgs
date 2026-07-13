import { ipDefaultCapabilities } from 'vuntangle'

export const ngfwCapabilities = {
  ...ipDefaultCapabilities,
  main: {
    ...ipDefaultCapabilities.main,
    appIcon: { render: true },
    powerStatus: { render: true },
    enableToggles: { render: false },
  },
  rule: {
    genericRule: { render: true },
  },
  signature: {
    customSignature: { render: true },
  },
}
