/**
 * NGFW event table column registry.
 *
 * Provides:
 *  - tableFields  — ordered field list per table
 *  - FIELD_META    — rendering metadata per field (width, valueFormatter, sort)
 *  - buildEventColumnDefs(table, defaultColumns) — builds AG-Grid column def array
 *
 * Column headers are resolved via i18n.t(field) at build time.
 */

import i18n from '@/plugins/vue-i18n'
import { protocolNameMap } from '@/constants'

// ─── Static code→name maps ───────────────────────────────────────────────────

// bandwidth_control_priority 0–7 → en.js i18n keys; 0 = no priority assigned → null (formatter returns '')
export const priorityMap = {
  0: null,
  1: 'very_high',
  2: 'high',
  3: 'medium',
  4: 'low',
  5: 'limited',
  6: 'limited_more',
  7: 'limited_severely',
}

// admin_logins.reason codes → en.js i18n keys.
// Not in FIELD_META because reason also appears in quotas table as a readable string.
// Applied table-specifically inside buildEventColumnDefs.
export const loginReasonMap = {
  U: 'invalid_username',
  P: 'invalid_password',
  T: 'invalid_totp',
  I: 'logged_in_successfully',
  O: 'logged_out_successfully',
}

// spam/phish blocker action codes → en.js i18n keys
export const emailActionMap = {
  P: 'pass_message',
  M: 'mark_message',
  D: 'drop_message',
  B: 'block_message',
  Q: 'quarantine_message',
  S: 'pass_safelist_message',
  Z: 'pass_oversize_message',
  O: 'pass_outbound_message',
  F: 'block_message_scan_failure',
  G: 'pass_message_scan_failure',
  Y: 'block_message_greylist',
}

// web_filter_reason single-char codes → en.js i18n keys
// Unknown codes fall back to 'no_rule_applied'
export const webFilterReasonMap = {
  D: 'in_categories_block_list',
  U: 'in_site_block_list',
  T: 'in_search_term_list',
  E: 'in_file_block_list',
  M: 'in_mime_types_block_list',
  H: 'hostname_is_an_ip_address',
  I: 'in_site_pass_list',
  R: 'referer_in_site_pass_list',
  C: 'in_clients_pass_list',
  B: 'in_temporary_unblocked_list',
  F: 'in_rules_list',
  K: 'kid_friendly_redirect',
}

// HTTP method single-char code → full name; unknown → raw value
export const httpMethodMap = {
  O: 'OPTIONS (O)',
  G: 'GET (G)',
  H: 'HEAD (H)',
  P: 'POST (P)',
  U: 'PUT (U)',
  D: 'DELETE (D)',
  T: 'TRACE (T)',
  C: 'CONNECT (C)',
  X: 'NON-STANDARD (X)',
}

// captive_portal_user_events.auth_type → readable string
export const authTypeMap = {
  NONE: 'None',
  LOCAL_DIRECTORY: 'Local Directory',
  ACTIVE_DIRECTORY: 'Active Directory',
  RADIUS: 'RADIUS',
  GOOGLE: 'Google Account',
  MICROSOFT: 'Microsoft Account',
  CUSTOM: 'Custom',
}

// captive_portal_user_events.event_info → readable string
export const captivePortalEventMap = {
  LOGIN: 'Login Success',
  FAILED: 'Login Failure',
  TIMEOUT: 'Session Timeout',
  INACTIVE: 'Idle Timeout',
  USER_LOGOUT: 'User Logout',
  ADMIN_LOGOUT: 'Admin Logout',
  HOST_CHANGE: 'Host Change Logout',
}

// quotas.action — 1→'Given', 2→'Exceeded' (table-specific: applied via tableMeta for 'quotas')
// Note: wan_failover_action_events also has an 'action' field with different string values
export const quotaActionMap = {
  1: 'Given',
  2: 'Exceeded',
}

// directory_connector_login_events.type — I/U/O/A → login/update/logout/authenticate (table-specific)
// Note: other VPN event tables use 'type' with already-readable values — no conversion needed
export const directoryConnectorActionMap = {
  I: 'login',
  U: 'update',
  O: 'logout',
  A: 'authenticate',
}

// Threat prevention category bitmask — each key is the BIT INDEX (not the bitmask value).
// Use Math.pow(2, key) & value to test membership.
export const threatCategoryMap = {
  0: 'Spam Sources',
  1: 'Windows Exploits',
  2: 'Web Attacks',
  3: 'Botnets',
  4: 'Scanners',
  5: 'Denial of Service',
  6: 'Reputation',
  7: 'Phishing',
  8: 'Proxy',
  11: 'Mobile Threats',
  13: 'Tor Proxy',
  16: 'Keyloggers',
  17: 'Malware',
  18: 'Spyware',
}

// Decodes threat category bitmask into comma-separated category names; 0 → ''
export function decodeThreatCategories(value) {
  if (!value) return ''
  const bits = Object.keys(threatCategoryMap)
  return bits
    .filter(bit => Math.pow(2, Number(bit)) & value)
    .map(bit => threatCategoryMap[bit])
    .join(', ')
}

// icmp_type integer → IANA ICMP type name; exported so detailFormatters share the same map.
// Fallback 'Unassigned' for null/unknown values.
export const icmpTypeMap = {
  0: 'Echo Reply',
  1: 'Unassigned',
  2: 'Unassigned',
  3: 'Destination Unreachable',
  4: 'Source Quench (Deprecated)',
  5: 'Redirect',
  6: 'Alternate Host Address (Deprecated)',
  7: 'Unassigned',
  8: 'Echo',
  9: 'Router Advertisement',
  10: 'Router Solicitation',
  11: 'Time Exceeded',
  12: 'Parameter Problem',
  13: 'Timestamp',
  14: 'Timestamp Reply',
  15: 'Information Request (Deprecated)',
  16: 'Information Reply (Deprecated)',
  17: 'Address Mask Request (Deprecated)',
  18: 'Address Mask Reply (Deprecated)',
  19: 'Reserved (for Security)',
  20: 'Reserved (for Robustness Experiment)',
  21: 'Reserved (for Robustness Experiment)',
  22: 'Reserved (for Robustness Experiment)',
  23: 'Reserved (for Robustness Experiment)',
  24: 'Reserved (for Robustness Experiment)',
  25: 'Reserved (for Robustness Experiment)',
  26: 'Reserved (for Robustness Experiment)',
  27: 'Reserved (for Robustness Experiment)',
  28: 'Reserved (for Robustness Experiment)',
  29: 'Reserved (for Robustness Experiment)',
  30: 'Traceroute (Deprecated)',
  31: 'Datagram Conversion Error (Deprecated)',
  32: 'Mobile Host Redirect (Deprecated)',
  33: 'IPv6 Where-Are-You (Deprecated)',
  34: 'IPv6 I-Am-Here (Deprecated)',
  35: 'Mobile Registration Request (Deprecated)',
  36: 'Mobile Registration Reply (Deprecated)',
  37: 'Domain Name Request (Deprecated)',
  38: 'Domain Name Reply (Deprecated)',
  39: 'SKIP (Deprecated)',
  40: 'Photuris',
  41: 'ICMP messages utilized by experimental mobility protocols',
  253: 'RFC3692-style Experiment 1',
  254: 'RFC3692-style Experiment 2',
}

// Static lookup table that maps web filter category IDs (integers) to human-readable category names.
// Used by the web_filter_category_id column formatter and details panel renderer.
// Unknown IDs fall back to the raw numeric string; null is handled by the caller.
export const webCategoryMap = {
  0: 'Uncategorized',
  1: 'Real Estate',
  2: 'Computer and Internet Security',
  3: 'Financial Services',
  4: 'Business and Economy',
  5: 'Computer and Internet Info',
  6: 'Auctions',
  7: 'Shopping',
  8: 'Cult and Occult',
  9: 'Travel',
  10: 'Abused Drugs',
  11: 'Adult and Pornography',
  12: 'Home and Garden',
  13: 'Military',
  14: 'Social Networking',
  15: 'Dead Sites',
  16: 'Individual Stock Advice and Tools',
  17: 'Training and Tools',
  18: 'Dating',
  19: 'Sex Education',
  20: 'Religion',
  21: 'Entertainment and Arts',
  22: 'Personal sites and Blogs',
  23: 'Legal',
  24: 'Local Information',
  25: 'Streaming Media',
  26: 'Job Search',
  27: 'Gambling',
  28: 'Translation',
  29: 'Reference and Research',
  30: 'Shareware and Freeware',
  31: 'Peer to Peer',
  32: 'Marijuana',
  33: 'Hacking',
  34: 'Games',
  35: 'Philosophy and Political Advocacy',
  36: 'Weapons',
  37: 'Pay to Surf',
  38: 'Hunting and Fishing',
  39: 'Society',
  40: 'Educational Institutions',
  41: 'Online Greeting Cards',
  42: 'Sports',
  43: 'Swimsuits and Intimate Apparel',
  44: 'Questionable',
  45: 'Kids',
  46: 'Hate and Racism',
  47: 'Personal Storage',
  48: 'Violence',
  49: 'Keyloggers and Monitoring',
  50: 'Search Engines',
  51: 'Internet Portals',
  52: 'Web Advertisements',
  53: 'Cheating',
  54: 'Gross',
  55: 'Web-based Email',
  56: 'Malware Sites',
  57: 'Phishing and Other Frauds',
  58: 'Proxy Avoidance and Anonymizers',
  59: 'Spyware and Adware',
  60: 'Music',
  61: 'Government',
  62: 'Nudity',
  63: 'News and Media',
  64: 'Illegal',
  65: 'Content Delivery Networks',
  66: 'Internet Communications',
  67: 'Bot Nets',
  68: 'Abortion',
  69: 'Health and Medicine',
  71: 'SPAM URLs',
  74: 'Dynamically Generated Content',
  75: 'Parked Domains',
  76: 'Alcohol and Tobacco',
  78: 'Image and Video Search',
  79: 'Fashion and Beauty',
  80: 'Recreation and Hobbies',
  81: 'Motor Vehicles',
  82: 'Web Hosting',
}

// Boolean formatter — null/undefined (SQL NULL absent from row) → 'false', true → 'true', false → 'false'
const boolFormatter = ({ value }) => (value == null ? 'false' : value ? 'true' : 'false')

// ─── Rendering metadata ─────────────────────────────────────────────────────
// Only fields that need special width, sort, or valueFormatter are listed.
// All other fields get { flex: 1 } from buildEventColumnDefs.

const FIELD_META = {
  // time_stamp and second-based timestamps have timezone-aware formatters
  // built dynamically in buildEventColumnDefs using tzOffsetMs.
  time_stamp: { width: 160, sort: 'desc' },
  // Byte fields — human-readable sizes
  c2p_bytes: { width: 100, valueFormatter: ({ value }) => formatBytes(value) },
  c2s_bytes: { width: 100, valueFormatter: ({ value }) => formatBytes(value) },
  s2c_bytes: { width: 100, valueFormatter: ({ value }) => formatBytes(value) },
  s2p_bytes: { width: 100, valueFormatter: ({ value }) => formatBytes(value) },
  p2c_bytes: { width: 100, valueFormatter: ({ value }) => formatBytes(value) },
  p2s_bytes: { width: 100, valueFormatter: ({ value }) => formatBytes(value) },
  in_bytes: { width: 100, valueFormatter: ({ value }) => formatBytes(value) },
  out_bytes: { width: 100, valueFormatter: ({ value }) => formatBytes(value) },
  rx_bytes: { width: 100, valueFormatter: ({ value }) => formatBytes(value) },
  tx_bytes: { width: 100, valueFormatter: ({ value }) => formatBytes(value) },
  hit_bytes: { width: 100, valueFormatter: ({ value }) => formatBytes(value) },
  miss_bytes: { width: 100, valueFormatter: ({ value }) => formatBytes(value) },
  // Protocol — number → display name
  protocol: {
    width: 90,
    valueFormatter: ({ value }) => protocolNameMap[value] ?? String(value ?? ''),
  },
  // Generic boolean fields — null/undefined (SQL NULL) → 'false', true → 'true'
  blocked: { width: 80, valueFormatter: boolFormatter },
  flagged: { width: 80, valueFormatter: boolFormatter },
  bypassed: { width: 80, valueFormatter: boolFormatter },
  entitled: { width: 80, valueFormatter: boolFormatter },
  success: { width: 80, valueFormatter: boolFormatter },

  // ICMP type number → IANA name; null/unknown → 'Unassigned' (even for TCP/UDP rows)
  icmp_type: { width: 150, valueFormatter: ({ value }) => icmpTypeMap[value] ?? 'Unassigned' },

  // HTTP method single-char code → full name; used in http_events, ftp_events, http_query_events
  method: { width: 80, valueFormatter: ({ value }) => (value == null ? '' : httpMethodMap[value] ?? String(value)) },

  // captive_portal auth_type → readable string; unknown → 'Unknown'
  auth_type: { width: 150, valueFormatter: ({ value }) => (value == null ? '' : authTypeMap[value] ?? 'Unknown') },

  // captive_portal event_info → readable string; null/'' → '', unknown → 'Unknown'
  event_info: {
    width: 150,
    valueFormatter: ({ value }) => (value == null || value === '' ? '' : captivePortalEventMap[value] ?? 'Unknown'),
  },

  // App-specific boolean fields — null/undefined → 'false', true → 'true'
  firewall_blocked: { width: 80, valueFormatter: boolFormatter },
  firewall_flagged: { width: 80, valueFormatter: boolFormatter },
  application_control_blocked: { width: 80, valueFormatter: boolFormatter },
  application_control_flagged: { width: 80, valueFormatter: boolFormatter },
  application_control_lite_blocked: { width: 80, valueFormatter: boolFormatter },
  captive_portal_blocked: { width: 80, valueFormatter: boolFormatter },
  phish_blocker_is_spam: { width: 80, valueFormatter: boolFormatter },
  spam_blocker_is_spam: { width: 80, valueFormatter: boolFormatter },
  spam_blocker_lite_is_spam: { width: 80, valueFormatter: boolFormatter },
  virus_blocker_clean: { width: 80, valueFormatter: boolFormatter },
  virus_blocker_lite_clean: { width: 80, valueFormatter: boolFormatter },
  web_filter_blocked: { width: 80, valueFormatter: boolFormatter },
  web_filter_flagged: { width: 80, valueFormatter: boolFormatter },
  threat_prevention_blocked: { width: 80, valueFormatter: boolFormatter },
  threat_prevention_flagged: { width: 80, valueFormatter: boolFormatter },
  // Server load fields
  load_1: { width: 100 },
  load_5: { width: 80 },
  load_15: { width: 80 },
  // Numeric rate fields
  rx_rate: { width: 100 },
  tx_rate: { width: 100 },
  // JSON field (alerts table) — backend HTML-encodes embedded quotes; decode explicitly for AG-Grid text nodes
  json: {
    flex: 1,
    valueFormatter: ({ value }) => {
      if (!value) return ''
      const s = String(value)
      return s
        .replace(/&quot;/g, '"')
        .replace(/&amp;/g, '&')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&#39;/g, "'")
    },
  },
  // Wide text fields
  uri: { width: 250 },
  host: { width: 200 },
  domain: { width: 180 },
  description: { width: 200 },
  summary_text: { width: 200 },
  msg: { width: 180 },
  operation: { width: 200 },
  // connect/goodbye/start/end are java.sql.Timestamp in DB — normalizeTimestampsInRow converts to epoch ms
  connect_stamp: { width: 150 },
  goodbye_stamp: { width: 150 },
  start_time: { width: 150 },
  end_time: { width: 150 },
  // Boolean fields with human-readable labels
  local: { width: 80, valueFormatter: ({ value }) => (value ? 'local' : 'remote') },
  succeeded: { width: 80, valueFormatter: ({ value }) => (value ? 'success' : 'failed') },

  // bandwidth_control_priority 0-7 → i18n Title Case name; 0/null → '' (no priority assigned)
  bandwidth_control_priority: {
    width: 120,
    valueFormatter: ({ value }) => (priorityMap[value] ? i18n.t(priorityMap[value]) : ''),
  },

  // bandwidth_control_rule — 0/null → 'None', else raw rule number
  bandwidth_control_rule: {
    width: 120,
    valueFormatter: ({ value }) => (value == null || value === 0 ? i18n.t('none') : String(value)),
  },

  // ad_blocker_action — 'B' → 'Block', else 'Pass'; null/'' → ''
  ad_blocker_action: {
    width: 80,
    valueFormatter: ({ value }) =>
      value == null || value === '' ? '' : value === 'B' ? i18n.t('block') : i18n.t('pass'),
  },

  // spam/phish blocker action codes → i18n label + code (e.g. "Pass Message [P]"); null/'' → '', unknown → 'Unknown Action [code]'
  spam_blocker_action: {
    valueFormatter: ({ value }) =>
      value == null || value === ''
        ? ''
        : emailActionMap[value]
        ? `${i18n.t(emailActionMap[value])} [${value}]`
        : `${i18n.t('unknown_action')} [${value}]`,
  },
  spam_blocker_lite_action: {
    valueFormatter: ({ value }) =>
      value == null || value === ''
        ? ''
        : emailActionMap[value]
        ? `${i18n.t(emailActionMap[value])} [${value}]`
        : `${i18n.t('unknown_action')} [${value}]`,
  },
  phish_blocker_action: {
    valueFormatter: ({ value }) =>
      value == null || value === ''
        ? ''
        : emailActionMap[value]
        ? `${i18n.t(emailActionMap[value])} [${value}]`
        : `${i18n.t('unknown_action')} [${value}]`,
  },

  // Memory fields — always MB, no auto-scaling
  mem_free: { width: 100, valueFormatter: ({ value }) => formatMemoryMB(value) },
  mem_total: { width: 100, valueFormatter: ({ value }) => formatMemoryMB(value) },
  swap_free: { width: 100, valueFormatter: ({ value }) => formatMemoryMB(value) },
  swap_total: { width: 100, valueFormatter: ({ value }) => formatMemoryMB(value) },

  // Disk fields — always GB, no auto-scaling
  disk_free: { width: 100, valueFormatter: ({ value }) => formatDiskGB(value) },
  disk_total: { width: 100, valueFormatter: ({ value }) => formatDiskGB(value) },

  // web_filter_reason code → readable label; null/unknown → 'No Rule Applied'
  web_filter_reason: {
    valueFormatter: ({ value }) =>
      webFilterReasonMap[value] ? i18n.t(webFilterReasonMap[value]) : i18n.t('no_rule_applied'),
  },

  // Renders web_filter_category_id as a human-readable category name using webCategoryMap.
  // null renders as empty string; unknown IDs fall back to the raw numeric string.
  web_filter_category_id: {
    valueFormatter: ({ value }) => (value == null ? '' : webCategoryMap[value] ?? String(value)),
  },

  // Threat prevention reason — same lookup as web_filter_reason; null/unknown → 'No Rule Applied'
  threat_prevention_reason: {
    valueFormatter: ({ value }) =>
      webFilterReasonMap[value] ? i18n.t(webFilterReasonMap[value]) : i18n.t('no_rule_applied'),
  },

  // Threat prevention rule ID — 0/null → '' (no rule assigned); else raw numeric ID
  threat_prevention_rule_id: {
    width: 120,
    valueFormatter: ({ value }) => (value == null || value === 0 ? '' : String(value)),
  },

  // Threat prevention category bitmask → comma-separated category names
  threat_prevention_client_categories: {
    width: 150,
    valueFormatter: ({ value }) => decodeThreatCategories(value),
  },
  threat_prevention_server_categories: {
    width: 150,
    valueFormatter: ({ value }) => decodeThreatCategories(value),
  },

  // Threat prevention reputation score — 0/null → '', else raw score
  threat_prevention_client_reputation: {
    width: 150,
    valueFormatter: ({ value }) => (value == null || value === 0 ? '' : String(value)),
  },
  threat_prevention_server_reputation: {
    width: 150,
    valueFormatter: ({ value }) => (value == null || value === 0 ? '' : String(value)),
  },

  // Tags — JSON object { list: [{name}] } or raw JSON string; join tag names with space
  tags: {
    valueFormatter: ({ value }) => {
      if (!value) return ''
      try {
        const parsed = typeof value === 'string' ? JSON.parse(value) : value
        if (parsed?.list?.length > 0) {
          return parsed.list
            .map(t => String(t.name || '').trim())
            .filter(Boolean)
            .join(' ')
        }
      } catch {}
      return ''
    },
  },

  // Settings file path — strip the leading /usr/share/untangle/settings/ prefix
  settings_file: {
    width: 200,
    valueFormatter: ({ value }) =>
      String(value ?? '')
        .replace(/^.*\/settings\//, '')
        .replace(/^.*\/conf\//, ''),
  },

  // Address fields
  c_client_addr: { width: 130 },
  c_server_addr: { width: 130 },
  s_client_addr: { width: 130 },
  s_server_addr: { width: 130 },
  c_client_port: { width: 110 },
  c_server_port: { width: 110 },
  s_client_port: { width: 110 },
  s_server_port: { width: 110 },
  source_addr: { width: 130 },
  dest_addr: { width: 130 },
  remote_addr: { width: 130 },
  local_addr: { width: 130 },
  peer_address: { width: 130 },
  pool_address: { width: 130 },
  client_addr: { width: 130 },
  address: { width: 130 },
}

// ─── Null defaults ──────────────────────────────────────────────────────────
// When a field is SQL NULL it is absent from the row object.
// These defaults ensure the details panel shows false/0 for boolean/integer fields
// instead of empty string, matching the model field type definitions.
export const fieldNullDefaults = {
  // Boolean fields (fld: { type: 'boolean' }) → false
  blocked: false,
  bypassed: false,
  entitled: false,
  flagged: false,
  local: false,
  succeeded: false,
  success: false,
  application_control_blocked: false,
  application_control_flagged: false,
  application_control_lite_blocked: false,
  captive_portal_blocked: false,
  firewall_blocked: false,
  firewall_flagged: false,
  phish_blocker_is_spam: false,
  spam_blocker_is_spam: false,
  spam_blocker_lite_is_spam: false,
  virus_blocker_clean: false,
  virus_blocker_lite_clean: false,
  web_filter_blocked: false,
  web_filter_flagged: false,
  threat_prevention_blocked: false,
  threat_prevention_flagged: false,
  // Integer/number app rule ID and score fields (fld: { type: 'integer' }) → 0
  application_control_ruleid: 0,
  application_control_confidence: 0,
  firewall_rule_index: 0,
  captive_portal_rule_index: 0,
  bandwidth_control_priority: 0,
  bandwidth_control_rule: 0,
  ssl_inspector_ruleid: 0,
  web_filter_rule_id: 0,
  policy_id: 0,
  policy_rule_id: 0,
  threat_prevention_rule_id: 0,
  threat_prevention_client_reputation: 0,
  threat_prevention_client_categories: 0,
  threat_prevention_server_reputation: 0,
  threat_prevention_server_categories: 0,
}

// ─── Table → ordered field list ─────────────────────────────────────────────
// Field names are actual DB column names.

export const tableFields = {
  admin_logins: ['time_stamp', 'login', 'local', 'client_addr', 'succeeded', 'reason'],
  alerts: ['time_stamp', 'description', 'summary_text', 'json'],
  captive_portal_user_events: [
    'time_stamp',
    'policy_id',
    'event_id',
    'login_name',
    'event_info',
    'auth_type',
    'client_addr',
  ],
  configuration_backup_events: ['time_stamp', 'success', 'description', 'destination', 'event_id'],
  device_table_updates: ['time_stamp', 'mac_address', 'key', 'value', 'old_value'],
  directory_connector_login_events: ['time_stamp', 'login_name', 'domain', 'type', 'client_addr'],
  ftp_events: [
    'time_stamp',
    'event_id',
    'session_id',
    'client_intf',
    'server_intf',
    'c_client_addr',
    's_client_addr',
    'c_server_addr',
    's_server_addr',
    'policy_id',
    'username',
    'hostname',
    'request_id',
    'method',
    'uri',
  ],
  host_table_updates: ['time_stamp', 'address', 'key', 'value', 'old_value'],
  interface_stat_events: ['time_stamp', 'interface_id', 'rx_rate', 'rx_bytes', 'tx_rate', 'tx_bytes'],
  ipsec_user_events: [
    'event_id',
    'time_stamp',
    'connect_stamp',
    'goodbye_stamp',
    'client_address',
    'client_protocol',
    'client_username',
    'net_process',
    'net_interface',
    'elapsed_time',
    'rx_bytes',
    'tx_bytes',
  ],
  ipsec_vpn_events: ['event_id', 'time_stamp', 'local_address', 'remote_address', 'tunnel_description', 'event_type'],
  ipsec_tunnel_stats: ['time_stamp', 'tunnel_name', 'in_bytes', 'out_bytes', 'event_id'],
  wireguard_vpn_stats: ['time_stamp', 'tunnel_name', 'peer_address', 'in_bytes', 'out_bytes', 'event_id'],
  wireguard_vpn_events: ['event_id', 'time_stamp', 'tunnel_name', 'event_type'],
  intrusion_prevention_events: [
    'time_stamp',
    'sig_id',
    'gen_id',
    'class_id',
    'source_addr',
    'source_port',
    'dest_addr',
    'dest_port',
    'protocol_name',
    'blocked',
    'category',
    'classtype',
    'msg',
    'rid',
    'rule_id',
  ],
  openvpn_events: ['time_stamp', 'remote_address', 'pool_address', 'client_name', 'type'],
  openvpn_stats: [
    'time_stamp',
    'start_time',
    'end_time',
    'rx_bytes',
    'tx_bytes',
    'remote_address',
    'pool_address',
    'remote_port',
    'client_name',
    'event_id',
  ],
  quotas: ['time_stamp', 'entity', 'action', 'size', 'reason'],
  server_events: [
    'time_stamp',
    'load_1',
    'load_5',
    'load_15',
    'cpu_user',
    'cpu_system',
    'mem_total',
    'mem_free',
    'disk_total',
    'disk_free',
    'swap_total',
    'swap_free',
    'active_hosts',
  ],
  settings_changes: ['time_stamp', 'settings_file', 'username', 'hostname'],
  system_operations: ['time_stamp', 'operation', 'username', 'hostname'],
  critical_alerts: ['time_stamp', 'component', 'message', 'problem'],
  smtp_tarpit_events: ['time_stamp', 'ipaddr', 'hostname', 'policy_id', 'vendor_name', 'event_id'],
  tunnel_vpn_events: ['event_id', 'time_stamp', 'tunnel_name', 'server_address', 'local_address', 'event_type'],
  tunnel_vpn_stats: ['time_stamp', 'tunnel_name', 'in_bytes', 'out_bytes', 'event_id'],
  user_table_updates: ['time_stamp', 'username', 'key', 'value', 'old_value'],
  wan_failover_action_events: ['time_stamp', 'interface_id', 'action', 'os_name', 'name', 'event_id'],
  wan_failover_test_events: ['time_stamp', 'interface_id', 'name', 'description', 'success', 'event_id'],
  web_cache_stats: ['time_stamp', 'hits', 'misses', 'bypasses', 'systems', 'hit_bytes', 'miss_bytes', 'event_id'],
  http_events: [
    'request_id',
    'time_stamp',
    'session_id',
    'client_intf',
    'server_intf',
    'c_client_addr',
    's_client_addr',
    'c_server_addr',
    's_server_addr',
    'c_client_port',
    's_client_port',
    'c_server_port',
    's_server_port',
    'client_country',
    'client_latitude',
    'client_longitude',
    'server_country',
    'server_latitude',
    'server_longitude',
    'policy_id',
    'username',
    'hostname',
    'method',
    'host',
    'uri',
    'domain',
    'referer',
    'c2s_content_length',
    's2c_content_length',
    's2c_content_type',
    's2c_content_filename',
    'ad_blocker_cookie_ident',
    'ad_blocker_action',
    'web_filter_reason',
    'web_filter_category_id',
    'web_filter_rule_id',
    'web_filter_blocked',
    'web_filter_flagged',
    'virus_blocker_lite_clean',
    'virus_blocker_lite_name',
    'virus_blocker_clean',
    'virus_blocker_name',
    // Threat Prevention fields
    'threat_prevention_blocked',
    'threat_prevention_flagged',
    'threat_prevention_reason',
    'threat_prevention_rule_id',
    'threat_prevention_client_reputation',
    'threat_prevention_client_categories',
    'threat_prevention_server_reputation',
    'threat_prevention_server_categories',
  ],
  http_query_events: [
    'event_id',
    'time_stamp',
    'session_id',
    'client_intf',
    'server_intf',
    'c_client_addr',
    's_client_addr',
    'c_server_addr',
    's_server_addr',
    'c_client_port',
    's_client_port',
    'c_server_port',
    's_server_port',
    'policy_id',
    'username',
    'hostname',
    'request_id',
    'method',
    'term',
    'host',
    'uri',
    'c2s_content_length',
    's2c_content_length',
    's2c_content_type',
    'blocked',
    'flagged',
    'web_filter_reason',
  ],
  mail_addrs: [
    'time_stamp',
    'session_id',
    'server_intf',
    'c_client_addr',
    'c_server_addr',
    'c_client_port',
    'c_server_port',
    's_client_addr',
    's_server_addr',
    's_client_port',
    's_server_port',
    'policy_id',
    'username',
    'msg_id',
    'subject',
    'addr',
    'addr_name',
    'addr_kind',
    'hostname',
    'event_id',
    'sender',
    'virus_blocker_lite_clean',
    'virus_blocker_lite_name',
    'virus_blocker_clean',
    'virus_blocker_name',
    'spam_blocker_lite_score',
    'spam_blocker_lite_is_spam',
    'spam_blocker_lite_action',
    'spam_blocker_lite_tests_string',
    'spam_blocker_score',
    'spam_blocker_is_spam',
    'spam_blocker_action',
    'spam_blocker_tests_string',
    'phish_blocker_score',
    'phish_blocker_is_spam',
    'phish_blocker_tests_string',
    'phish_blocker_action',
  ],
  mail_msgs: [
    'time_stamp',
    'session_id',
    'server_intf',
    'c_client_addr',
    's_server_addr',
    'c_client_port',
    's_server_port',
    'policy_id',
    'username',
    'msg_id',
    'subject',
    'hostname',
    'event_id',
    'sender',
    'receiver',
    'virus_blocker_lite_clean',
    'virus_blocker_lite_name',
    'virus_blocker_clean',
    'virus_blocker_name',
    'spam_blocker_lite_score',
    'spam_blocker_lite_is_spam',
    'spam_blocker_lite_tests_string',
    'spam_blocker_lite_action',
    'spam_blocker_score',
    'spam_blocker_is_spam',
    'spam_blocker_tests_string',
    'spam_blocker_action',
    'phish_blocker_score',
    'phish_blocker_is_spam',
    'phish_blocker_tests_string',
    'phish_blocker_action',
  ],
  session_minutes: [
    'session_id',
    'time_stamp',
    'c2s_bytes',
    's2c_bytes',
    'start_time',
    'end_time',
    'bypassed',
    'entitled',
    'protocol',
    'icmp_type',
    'hostname',
    'username',
    'policy_id',
    'policy_rule_id',
    'local_addr',
    'remote_addr',
    'c_client_addr',
    'c_server_addr',
    'c_client_port',
    'c_server_port',
    's_client_addr',
    's_server_addr',
    's_client_port',
    's_server_port',
    'client_intf',
    'server_intf',
    'client_country',
    'client_latitude',
    'client_longitude',
    'server_country',
    'server_latitude',
    'server_longitude',
    'filter_prefix',
    'firewall_blocked',
    'firewall_flagged',
    'firewall_rule_index',
    'application_control_lite_protocol',
    'application_control_lite_blocked',
    'captive_portal_blocked',
    'captive_portal_rule_index',
    'application_control_application',
    'application_control_protochain',
    'application_control_category',
    'application_control_blocked',
    'application_control_flagged',
    'application_control_confidence',
    'application_control_ruleid',
    'application_control_detail',
    'bandwidth_control_priority',
    'bandwidth_control_rule',
    'ssl_inspector_ruleid',
    'ssl_inspector_status',
    'ssl_inspector_detail',
    // Threat Prevention fields
    'threat_prevention_blocked',
    'threat_prevention_flagged',
    'threat_prevention_reason',
    'threat_prevention_rule_id',
    'threat_prevention_client_reputation',
    'threat_prevention_client_categories',
    'threat_prevention_server_reputation',
    'threat_prevention_server_categories',
    'tags',
  ],
  sessions: [
    'session_id',
    'time_stamp',
    'end_time',
    'bypassed',
    'entitled',
    'protocol',
    'icmp_type',
    'hostname',
    'username',
    'policy_id',
    'policy_rule_id',
    'local_addr',
    'remote_addr',
    'c_client_addr',
    'c_server_addr',
    'c_client_port',
    'c_server_port',
    's_client_addr',
    's_server_addr',
    's_client_port',
    's_server_port',
    'client_intf',
    'server_intf',
    'client_country',
    'client_latitude',
    'client_longitude',
    'server_country',
    'server_latitude',
    'server_longitude',
    'c2p_bytes',
    'p2c_bytes',
    's2p_bytes',
    'p2s_bytes',
    'filter_prefix',
    'firewall_blocked',
    'firewall_flagged',
    'firewall_rule_index',
    'application_control_lite_protocol',
    'application_control_lite_blocked',
    'captive_portal_blocked',
    'captive_portal_rule_index',
    'application_control_application',
    'application_control_protochain',
    'application_control_category',
    'application_control_blocked',
    'application_control_flagged',
    'application_control_confidence',
    'application_control_ruleid',
    'application_control_detail',
    'bandwidth_control_priority',
    'bandwidth_control_rule',
    'ssl_inspector_ruleid',
    'ssl_inspector_status',
    'ssl_inspector_detail',
    // Threat Prevention fields
    'threat_prevention_blocked',
    'threat_prevention_flagged',
    'threat_prevention_reason',
    'threat_prevention_rule_id',
    'threat_prevention_client_reputation',
    'threat_prevention_client_categories',
    'threat_prevention_server_reputation',
    'threat_prevention_server_categories',
    'tags',
  ],
}

// ─── Helpers ────────────────────────────────────────────────────────────────

function formatBytes(value) {
  if (value === null || value === undefined) return ''
  const n = Number(value)
  if (n === 0) return '0 B'
  const units = ['B', 'KB', 'MB', 'GB', 'TB']
  const i = Math.floor(Math.log(Math.abs(n)) / Math.log(1024))
  return (n / Math.pow(1024, i)).toFixed(1) + ' ' + units[Math.min(i, units.length - 1)]
}

/**
 * Formats a byte value as megabytes — always MB, no auto-scaling.
 * Used for mem_free, mem_total, swap_free, swap_total.
 */
export function formatMemoryMB(value) {
  if (value == null) return ''
  const meg = Number(value) / 1024 / 1024
  return `${Math.round(meg * 10) / 10} MB`
}

/**
 * Formats a byte value as gigabytes — always GB, no auto-scaling.
 * Used for disk_free, disk_total.
 */
export function formatDiskGB(value) {
  if (value == null) return ''
  const gig = Number(value) / 1024 / 1024 / 1024
  return `${Math.round(gig * 10) / 10} GB`
}

/**
 * Formats an epoch-ms timestamp as YYYY-MM-DD hh:mm:ss am/pm in server local time.
 * Applies tzOffsetMs so the displayed time matches the server's timezone.
 *
 * @param {number} ms         - epoch milliseconds from the backend
 * @param {number} tzOffsetMs - server timezone offset in ms
 */
function formatTimestamp(ms, tzOffsetMs = 0) {
  if (!ms) return ''
  const d = new Date(ms + tzOffsetMs)
  const Y = d.getUTCFullYear()
  const m = String(d.getUTCMonth() + 1).padStart(2, '0')
  const dd = String(d.getUTCDate()).padStart(2, '0')
  let h = d.getUTCHours()
  const min = String(d.getUTCMinutes()).padStart(2, '0')
  const s = String(d.getUTCSeconds()).padStart(2, '0')
  const ampm = h >= 12 ? 'pm' : 'am'
  h = h % 12 || 12
  return `${Y}-${m}-${dd} ${String(h).padStart(2, '0')}:${min}:${s} ${ampm}`
}

// ─── Public API ─────────────────────────────────────────────────────────────

/**
 * Builds an AG-Grid columnDefs array for the given event table.
 *
 * - Column order follows tableFields[table].
 * - Columns in entry.defaultColumns are visible; all others are hidden.
 * - headerName is resolved via i18n.t(field) at call time.
 * - Timestamp formatters use tzOffsetMs to show server local time.
 * - Special rendering (formatters, widths) comes from FIELD_META[field].
 * - interfaceNameMap / policyNameMap are runtime-resolved maps for displaying
 *   interface and policy names instead of raw IDs.
 *
 * @param {string}   table            - DB table name, e.g. 'sessions', 'http_events'
 * @param {string[]} defaultColumns   - from entry.defaultColumns
 * @param {number}   tzOffsetMs       - server timezone offset in ms
 * @param {Object}   interfaceNameMap - { interfaceId: 'name [id]' } from config store
 * @param {Object}   policyNameMap    - { policyId: 'name [id]' } from reports store
 * @returns {Array} AG-Grid columnDef objects
 */
export function buildEventColumnDefs(table, defaultColumns, tzOffsetMs = 0, interfaceNameMap = {}, policyNameMap = {}) {
  const fields = tableFields[table] || []
  const visible = new Set(defaultColumns || [])

  // Build timestamp field meta with timezone-aware formatters
  const timestampMeta = {
    time_stamp: {
      width: 160,
      sort: 'desc',
      valueFormatter: ({ value }) => formatTimestamp(value, tzOffsetMs),
    },
    connect_stamp: { width: 150, valueFormatter: ({ value }) => (value ? formatTimestamp(value, tzOffsetMs) : '') },
    goodbye_stamp: { width: 150, valueFormatter: ({ value }) => (value ? formatTimestamp(value, tzOffsetMs) : '') },
    start_time: { width: 150, valueFormatter: ({ value }) => (value ? formatTimestamp(value, tzOffsetMs) : '') },
    end_time: { width: 150, valueFormatter: ({ value }) => (value ? formatTimestamp(value, tzOffsetMs) : '') },
  }

  // Dynamic formatters that close over runtime maps — applied after FIELD_META so they take precedence.
  const dynamicMeta = {
    // 0 and -1 are treated as unset → 'None'
    client_intf: {
      width: 100,
      valueFormatter: ({ value }) =>
        !value || value === -1 ? i18n.t('none') : interfaceNameMap[value] ?? String(value),
    },
    server_intf: {
      width: 100,
      valueFormatter: ({ value }) =>
        !value || value === -1 ? i18n.t('none') : interfaceNameMap[value] ?? String(value),
    },
    interface_id: {
      width: 100,
      valueFormatter: ({ value }) =>
        !value || value === -1 ? i18n.t('none') : interfaceNameMap[value] ?? String(value),
    },
    // 0 → 'None', null/not-in-map → '', else mapped name
    policy_id: {
      width: 120,
      valueFormatter: ({ value }) => (value == null || value === 0 ? i18n.t('none') : policyNameMap[value] || ''),
    },
  }

  // Table-specific formatters — fields whose meaning differs across tables.
  // Only injected for the specific table where the converter applies.
  const tableMeta = {}

  // admin_logins.reason — single-char login reason codes → i18n label
  // quotas.reason is already human-readable, so this only applies for admin_logins.
  if (table === 'admin_logins') {
    tableMeta.reason = {
      valueFormatter: ({ value }) => (loginReasonMap[value] ? i18n.t(loginReasonMap[value]) : ''),
    }
  }

  // quotas.action — 1→'Given', 2→'Exceeded'
  // wan_failover_action_events.action contains different string values — not converted.
  if (table === 'quotas') {
    tableMeta.action = {
      valueFormatter: ({ value }) => (value == null ? '' : quotaActionMap[value] ?? 'Unknown'),
    }
  }

  // directory_connector_login_events.type — I/U/O/A → login/update/logout/authenticate
  // Other VPN event tables use 'type' with already-readable values — no conversion needed.
  if (table === 'directory_connector_login_events') {
    tableMeta.type = {
      valueFormatter: ({ value }) => (value == null ? '' : directoryConnectorActionMap[value] ?? 'unknown'),
    }
  }

  return fields.map(field => {
    const colDef = {
      field,
      headerName: i18n.t(field),
      hide: !visible.has(field),
      flex: 1,
      ...(FIELD_META[field] || {}),
      ...(dynamicMeta[field] || {}), // runtime-resolved overrides static FIELD_META
      ...(tableMeta[field] || {}), // table-specific overrides (e.g. reason for admin_logins)
      ...(timestampMeta[field] || {}), // timestamp formatters always win
    }

    // AG-Grid ignores `width` when `flex` is also set.
    // If an explicit width was contributed by any meta layer, drop flex so the
    // width is actually respected in the grid layout.
    if (colDef.width) colDef.flex = 0

    return colDef
  })
}
