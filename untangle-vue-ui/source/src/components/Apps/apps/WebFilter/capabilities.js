import { webFilterDefaultCapabilities } from 'vuntangle'

export const ngfwCapabilities = {
  ...webFilterDefaultCapabilities,
  main: {
    policyManagerAlert: { render: false },
    enableToggle: { render: false },
    appIcon: { render: true },
    powerStatus: { render: true },
    description: { render: true, key: 'app_web_filter_description' },
  },
  categories: {
    listGroup: {
      mode: 'direct',
      actions: [
        { value: 'blocked', text: 'block', forceEnabledFor: [] },
        { value: 'flagged', text: 'flag', forceEnabledFor: [] },
      ],
    },
  },
  searchTerms: {
    ...webFilterDefaultCapabilities.searchTerms,
    importExport: {
      render: true,
      exportId: 'web-filter-search-terms',
      formats: [
        { text: 'comma_delimited', value: 'comma' },
        { text: 'newline_delimited', value: 'newline' },
        { text: 'json_array', value: 'json' },
      ],
      defaultActions: [
        { key: 'blocked', label: 'block', default: true },
        { key: 'flagged', label: 'flag', default: true },
      ],
    },
    defaultItem: {
      javaClass: 'com.untangle.uvm.app.GenericRule',
      string: '',
      description: '',
      blocked: true,
      flagged: true,
    },
  },
  blockSites: {
    ...webFilterDefaultCapabilities.blockSites,
    siteName: { key: 'string', label: 'enter_site_domain', validator: null },
    enabled: { render: false },
    blocked: { render: true },
    rejected: { render: false },
    flagged: { render: true, label: 'flag' },
    logged: { render: false },
    exact: { render: false },
    global: { render: true },
    importExport: { render: true, exportId: 'web-filter-block-sites' },
    defaultItem: {
      javaClass: 'com.untangle.uvm.app.GenericRule',
      string: '',
      description: '',
      blocked: true,
      flagged: true,
      isGlobal: false,
    },
  },
  passSites: {
    ...webFilterDefaultCapabilities.passSites,
    siteName: { key: 'string', label: 'enter_site_domain', validator: null },
    flagged: { render: false },
    logged: { render: false },
    exact: { render: false },
    global: { render: true },
    importExport: { render: true, exportId: 'web-filter-pass-sites' },
    defaultItem: {
      javaClass: 'com.untangle.uvm.app.GenericRule',
      string: '',
      description: '',
      enabled: true,
      isGlobal: false,
    },
  },
  passClients: {
    ...webFilterDefaultCapabilities.passClients,
    defaultItem: {
      javaClass: 'com.untangle.uvm.app.GenericRule',
      string: '1.2.3.4',
      description: '',
      enabled: true,
    },
  },
  siteLookup: {
    ...webFilterDefaultCapabilities.siteLookup,
    recategorize: { render: true },
  },
  advanced: {
    ...webFilterDefaultCapabilities.advanced,
  },
}
