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
  'web-filter': 'app_web_filter_description',
  'web-monitor': 'app_web_monitor_description',
  'virus-blocker': 'app_virus_blocker_description',
  'virus-blocker-lite': 'app_virus_blocker_lite_description',
  'spam-blocker': 'app_spam_blocker_description',
  'spam-blocker-lite': 'app_spam_blocker_lite_description',
  'phish-blocker': 'app_phish_blocker_description',
  'web-cache': 'app_web_cache_description',
  'bandwidth-control': 'app_bandwidth_control_description',
  'ssl-inspector': 'app_ssl_inspector_description',
  'application-control': 'app_application_control_description',
  'application-control-lite': 'app_application_control_lite_description',
  'captive-portal': 'app_captive_portal_description',
  'firewall': 'app_firewall_description',
  'threat-prevention': 'app_threat_prevention_description',
  'ad-blocker': 'app_ad_blocker_description',
}

export {
  booleanValueOptions,
  invertOptions,
  numericOptions,
  textOperatorOptions,
  booleanOperatorOptions,
  appDescription,
}
