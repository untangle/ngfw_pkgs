const booleanValues = { 'True': 'True', 'False': 'False' }
const booleanValueOptions = Object.entries(booleanValues).map(([k, v]) => ({ text: v, value: k }))

const invert = { true: 'is_not', false: 'is' }
const invertOptions = Object.entries(invert).map(([k, v]) => ({ text: v, value: k }))

const numeric = {
  '=': 'equals',
  '!=': 'not_equals',
  '>': 'greater_than',
  '<': 'less_than',
  '>=': 'greater_or_equal',
  '<=': 'less_or_equal',
}
const numericOptions = Object.entries(numeric).map(([k, v]) => ({ text: v, value: k }))

const textOperators = {
  '=': 'equals',
  '!=': 'not_equals',
  'substr': 'Contains',
  '!substr': 'Does not contain',
}
const textOperatorOptions = Object.entries(textOperators).map(([k, v]) => ({ text: v, value: k }))

const booleanOperators = { '=': 'is', '!=': 'is_not' }
const booleanOperatorOptions = Object.entries(booleanOperators).map(([k, v]) => ({ text: v, value: k }))

const appDescription = {
  'web-filter': 'Web Filter scans and categorizes web traffic to monitor and enforce network usage policies.',
  'web-monitor': 'Web monitor scans and categorizes web traffic to monitor and enforce network usage policies.',
  'virus-blocker': 'Virus Blocker detects and blocks malware before it reaches users desktops or mailboxes.',
  'virus-blocker-lite': 'Virus Blocker Lite detects and blocks malware before it reaches users desktops or mailboxes.',
  'spam-blocker': 'Spam Blocker detects, blocks, and quarantines spam before it reaches users mailboxes.',
  'spam-blocker-lite': 'Spam Blocker Lite detects, blocks, and quarantines spam before it reaches users mailboxes.',
  'phish-blocker': 'Phish Blocker detects and blocks phishing emails using signatures.',
  'web-cache':
    'Web Cache stores and serves web content from local cache for increased speed and reduced bandwidth usage.',
  'bandwidth-control': 'Bandwidth Control monitors, manages, and shapes bandwidth usage on the network',
  'ssl-inspector':
    'SSL Inspector allows for full decryption of HTTPS and SMTPS so that other applications can process the encrypted streams.',
  'application-control':
    'Application Control scans sessions and identifies the associated applications allowing each to be flagged and/or blocked.',
  'application-control-lite':
    'Application Control Lite identifies, logs, and blocks sessions based on the session content using custom signatures.',

  'captive-portal':
    'Captive Portal allows administrators to require network users to complete a defined process, such as logging in or accepting a network usage policy, before accessing the internet.',

  'firewall': 'Firewall is a simple application that flags and blocks sessions based on rules.',
  'threat-prevention':
    'Threat Prevention flags and blocks sessions based on rules that match IP address and URL historical statistics.',

  'ad-blocker': 'Ad Blocker blocks advertising content and tracking cookies for scanned web traffic.',
  'reports':
    'Reports records network events to provide administrators the visibility and data necessary to investigate network activity.',

  'policy-manager':
    'Policy Manager enables administrators to create different policies and handle different sessions with different policies based on rules.',

  'directory-connector':
    'Directory Connector allows integration with external directories and services, such as Active Directory, RADIUS, or Google.',

  'wan-failover':
    'WAN Failover detects WAN outages and re-routes traffic to any other available WANs to maximize network uptime.',

  'wan-balancer': 'WAN Balancer spreads network traffic across multiple internet connections for better performance.',

  'ipsec-vpn':
    'IPsec VPN provides secure network access and tunneling to remote users and sites using IPsec, GRE, L2TP, Xauth, and IKEv2 protocols.',

  'wireguard-vpn':
    'WireGuard VPN provides secure network access and tunneling to remote users and sites using the WireGuard VPN protocol.',

  'openvpn':
    'OpenVPN provides secure network access and tunneling to remote users and sites using the OpenVPN protocol.',

  'tunnel-vpn': 'Tunnel VPN provides connectivity through encrypted tunnels to remote VPN servers and services.',

  'dynamic-blocklists': 'Dynamic Blocklists provides blocking on added urls which have IPS.',
  'intrusion-prevention':
    'Intrusion Prevention blocks scans, detects, and blocks attacks and suspicious traffic using signatures.',

  'configuration-backup':
    'Configuration Backup automatically creates backups of settings uploads them to My Account and Google Drive.',

  'branding-manager':
    'The Branding Settings are used to set the logo and contact information that will be seen by users (e.g. reports).',

  'live-support': 'Live Support provides on-demand help for any technical issues.',
}

export {
  booleanValueOptions,
  invertOptions,
  numericOptions,
  textOperatorOptions,
  booleanOperatorOptions,
  appDescription,
}
