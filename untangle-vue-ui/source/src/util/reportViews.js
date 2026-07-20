/**
 * Report view translation layer.
 * Converts backend report entries into view configs consumed by the display components.
 */

import {
  buildEventColumnDefs,
  tableFields,
  fieldNullDefaults,
  loginReasonMap,
  emailActionMap,
  priorityMap,
  webFilterReasonMap,
  webCategoryMap,
  icmpTypeMap,
  httpMethodMap,
  authTypeMap,
  captivePortalEventMap,
  quotaActionMap,
  directoryConnectorActionMap,
  decodeThreatCategories,
  formatMemoryMB,
  formatDiskGB,
} from './eventTableColumns'
import i18n from '@/plugins/vue-i18n'
import { protocolNameMap } from '@/constants'

// ─── Static code→name maps for detail panel formatters ─────────────────────
// These maps are shared with the column registry — single source of truth.
// Map values are i18n keys resolved to Title Case display strings at render time.

/**
 * Maps a time-based chart style to the corresponding chart type.
 * Bar variants map to 'column'; area variants to 'areaspline'; line to 'spline'.
 */
function timeStyleToChartType(timeStyle) {
  if (!timeStyle) return 'column'
  if (timeStyle === 'LINE') return 'spline'
  if (timeStyle.startsWith('AREA')) return 'areaspline'
  return 'column' // BAR, BAR_OVERLAPPED, BAR_STACKED, BAR_3D*
}

/**
 * Maps a pie/distribution chart style to the corresponding chart type.
 */
function pieStyleToChartType(pieStyle) {
  if (!pieStyle) return 'pie'
  if (pieStyle === 'COLUMN' || pieStyle === 'COLUMN_3D') return 'column'
  return 'pie' // PIE, PIE_3D, DONUT, DONUT_3D
}

/**
 * Builds the report config for a text-type report.
 * Sets the key from the unique identifier so data fetch events can match the entry.
 *
 * @param {Object} entry - report entry definition
 * @returns {Object} report config for the text display component
 */
function translateTextEntry(entry) {
  return {
    ...entry,
    key: entry.uniqueId,
    query: {}, // no pagination — TEXT reports are not paginated
  }
}

/**
 * Builds the rendering config for a time-series chart report.
 * Maps time style variants to chart type, stacking, and data grouping options.
 */
function translateTimeGraphEntry(entry) {
  const timeStyle = entry.timeStyle || ''
  return {
    key: entry.uniqueId,
    title: entry.title,
    query: {},
    rendering: {
      type: timeStyleToChartType(timeStyle),
      units: entry.units,
      stacking: timeStyle.includes('STACKED') ? 'normal' : undefined,
      overlapped: timeStyle.includes('OVERLAPPED'),
      dataGroupingApproximation: entry.approximation || 'sum',
      groupPixelWidth: 8,
      colors: Array.isArray(entry.colors) ? entry.colors.join(',') : entry.colors,
    },
  }
}

/**
 * Builds the rendering config for a dynamic time-series chart report.
 * Extends the base time-series config with a grouping column for dynamic series discovery.
 */
function translateTimeGraphDynamicEntry(entry) {
  const base = translateTimeGraphEntry(entry)
  return {
    ...base,
    query: {
      queryCategories: {
        groupColumn: entry.timeDataDynamicColumn,
      },
    },
  }
}

/**
 * Builds the config for an event list report.
 * Column defs are assembled from the column registry based on entry.table and entry.defaultColumns.
 *
 * @param {Object} entry            - report entry definition
 * @param {number} tzOffsetMs       - server timezone offset in ms
 * @param {Object} interfaceNameMap - { interfaceId: 'name [id]' } — from config store
 * @param {Object} policyNameMap    - { policyId: 'name [id]' } — from reports store
 * @param {Object} callbacks        - host-app supplied action callbacks keyed by table/action
 *   callbacks.onShowDiff(fileName) — called when user clicks 🔍 on a settings_changes row
 * @returns {Object} report config for GenericEventList
 */
function translateEventListEntry(entry, tzOffsetMs, interfaceNameMap = {}, policyNameMap = {}, callbacks = {}) {
  // Table-specific row actions — only injected when the host app supplies the relevant callback.
  // 'differences' is a virtual non-SQL action column for row-level diff inspection.
  const rowActions = []
  if (entry.table === 'settings_changes' && typeof callbacks.onShowDiff === 'function') {
    rowActions.push({
      icon: 'mdi-magnify',
      tooltip: 'Show difference between previous version',
      handler: ({ data }) => callbacks.onShowDiff(data.settings_file),
    })
  }

  return {
    key: entry.uniqueId,
    title: entry.title,
    category: entry.category, // needed for export filename: "{category}-{title}_date.csv"
    columns: buildEventColumnDefs(entry.table, entry.defaultColumns, tzOffsetMs, interfaceNameMap, policyNameMap),
    tzOffsetMs: tzOffsetMs || 0,
    // Row actions — undefined when empty so UGrid skips the action column setup
    rowActions: rowActions.length ? rowActions : undefined,
    // Full ordered field list for this table — used by GenericEventList to iterate ALL
    // schema fields in the details panel, including those that are SQL NULL in the row
    // (SQL NULLs are stripped by org.json on the backend so they are absent from the
    // row object; iterating tableFields instead ensures app groups always appear).
    tableFields: tableFields[entry.table] || [],
    // Type-aware null defaults: boolean→false, integer→0.
    // Used in GenericEventList formatDetailValue so null fields show false/0 not empty.
    fieldNullDefaults,
    // Host-app field renderers passed to GenericEventList details panel.
    // Priority order: custom formatter > built-in byte/timestamp/boolean handlers > String().
    // Mirrors Map.fields[key].col.renderer logic in PropertyGridController.
    detailFormatters: {
      // Protocol number → IANA display name (e.g. 6 → "TCP [6]")
      protocol: v => protocolNameMap[v] ?? String(v ?? ''),

      // ICMP type number → IANA name; null/unknown → 'Unassigned'
      icmp_type: v => icmpTypeMap[v] ?? 'Unassigned',

      // HTTP method single-char code → full name
      method: v => (v == null ? '' : httpMethodMap[v] ?? String(v)),

      // captive_portal auth_type → readable string
      auth_type: v => (v == null ? '' : authTypeMap[v] ?? 'Unknown'),

      // captive_portal event_info → readable string; null/'' → '', unknown → 'Unknown'
      event_info: v => (v == null || v === '' ? '' : captivePortalEventMap[v] ?? 'Unknown'),

      // quotas.action — 1→'Given', 2→'Exceeded'; null/'' → '', unknown → 'Unknown'
      action: v => (v == null || v === '' ? '' : quotaActionMap[v] ?? 'Unknown'),

      // directory_connector_login_events.type — I/U/O/A → login/update/logout/authenticate
      // Other tables use 'type' with already-readable string values so the map has no effect.
      type: v => (v == null ? '' : directoryConnectorActionMap[v] ?? String(v)),

      // Interface ID → "name [id]"; 0 and -1 treated as unset → 'None'
      client_intf: v => (!v || v === -1 ? i18n.t('none') : interfaceNameMap[v] ?? String(v)),
      server_intf: v => (!v || v === -1 ? i18n.t('none') : interfaceNameMap[v] ?? String(v)),
      interface_id: v => (!v || v === -1 ? i18n.t('none') : interfaceNameMap[v] ?? String(v)),

      // Policy ID → mapped name; null/0 → 'None'
      policy_id: v => (v == null || v === 0 ? i18n.t('none') : policyNameMap[v] || ''),

      // admin_logins: local (true=local login, false=remote login)
      local: v => (v ? 'local' : 'remote'),

      // admin_logins: succeeded (true=success, false=failed)
      succeeded: v => (v ? 'success' : 'failed'),

      // admin_logins: reason code → i18n Title Case label; unknown codes return ''
      reason: v => (loginReasonMap[v] ? i18n.t(loginReasonMap[v]) : ''),

      // bandwidth_control_priority 0-7 → i18n Title Case name; 0 falls back to raw integer
      bandwidth_control_priority: v => (priorityMap[v] ? i18n.t(priorityMap[v]) : String(v ?? '')),

      // bandwidth_control_rule: 0/null → 'None', else raw rule number
      bandwidth_control_rule: v => (v == null || v === 0 ? i18n.t('none') : String(v)),

      // ad_blocker_action: 'B' → 'Block', else 'Pass'; null/'' → ''
      ad_blocker_action: v => (v == null || v === '' ? '' : v === 'B' ? i18n.t('block') : i18n.t('pass')),

      // Spam / phish blocker action codes → i18n label + code (e.g. "Pass Message [P]"); null/'' → ''
      spam_blocker_action: v =>
        v == null || v === ''
          ? ''
          : emailActionMap[v]
          ? `${i18n.t(emailActionMap[v])} [${v}]`
          : `${i18n.t('unknown_action')} [${v}]`,
      spam_blocker_lite_action: v =>
        v == null || v === ''
          ? ''
          : emailActionMap[v]
          ? `${i18n.t(emailActionMap[v])} [${v}]`
          : `${i18n.t('unknown_action')} [${v}]`,
      phish_blocker_action: v =>
        v == null || v === ''
          ? ''
          : emailActionMap[v]
          ? `${i18n.t(emailActionMap[v])} [${v}]`
          : `${i18n.t('unknown_action')} [${v}]`,

      // Memory fields — always MB
      mem_free: v => formatMemoryMB(v),
      mem_total: v => formatMemoryMB(v),
      swap_free: v => formatMemoryMB(v),
      swap_total: v => formatMemoryMB(v),

      // Disk fields — always GB
      disk_free: v => formatDiskGB(v),
      disk_total: v => formatDiskGB(v),

      // Web filter reason code → readable label; null/unknown → 'No Rule Applied'
      web_filter_reason: v => (webFilterReasonMap[v] ? i18n.t(webFilterReasonMap[v]) : i18n.t('no_rule_applied')),

      // web_filter_category_id → category name; null → '', unknown → raw ID string
      web_filter_category_id: v => (v == null ? '' : webCategoryMap[v] ?? String(v)),

      // Threat prevention reason — same lookup as web_filter_reason; null/unknown → 'No Rule Applied'
      threat_prevention_reason: v =>
        webFilterReasonMap[v] ? i18n.t(webFilterReasonMap[v]) : i18n.t('no_rule_applied'),

      // Threat prevention rule ID — 0/null → '' (no rule); else raw ID
      threat_prevention_rule_id: v => (v == null || v === 0 ? '' : String(v)),

      // Threat prevention category bitmask → comma-separated category names
      threat_prevention_client_categories: v => decodeThreatCategories(v),
      threat_prevention_server_categories: v => decodeThreatCategories(v),

      // Threat prevention reputation score — 0/null → '', else raw score
      threat_prevention_client_reputation: v => (v == null || v === 0 ? '' : String(v)),
      threat_prevention_server_reputation: v => (v == null || v === 0 ? '' : String(v)),

      // JSON field (alerts) — decode HTML entities encoded by the backend/Jabsorb layer
      json: v => {
        if (!v) return ''
        return String(v)
          .replace(/&quot;/g, '"')
          .replace(/&amp;/g, '&')
          .replace(/&lt;/g, '<')
          .replace(/&gt;/g, '>')
          .replace(/&#39;/g, "'")
      },

      // Settings file path — strip the /usr/share/untangle/settings/ prefix
      settings_file: v =>
        String(v ?? '')
          .replace(/^.*\/settings\//, '')
          .replace(/^.*\/conf\//, ''),
    },
    query: {},
  }
}

/**
 * Builds the rendering config for a pie or column-distribution chart report.
 * Maps pie style variants to chart type and donut/slice display options.
 */
function translatePieGraphEntry(entry) {
  const pieStyle = entry.pieStyle || ''
  return {
    key: entry.uniqueId,
    title: entry.title,
    query: {},
    rendering: {
      type: pieStyleToChartType(pieStyle),
      units: entry.units,
      donutInnerSize: pieStyle.includes('DONUT') ? 40 : 0,
      slicesNumber: entry.pieNumSlices || 10,
      column: entry.pieGroupColumn, // category column used for web category label resolution
      colors: Array.isArray(entry.colors) ? entry.colors.join(',') : entry.colors,
    },
  }
}

/**
 * Builds the view config object for a given report entry based on its type.
 * Selects the correct display component and rendering options at runtime.
 * verticalLayout expands the chart to fill available height instead of a fixed minimum.
 *
 * @param {Object} entry            - report entry definition
 * @param {number} tzOffsetMs       - server timezone offset in ms
 * @param {Object} interfaceNameMap - { interfaceId: 'name [id]' } — from config store getter
 * @param {Object} policyNameMap    - { policyId: 'name [id]' } — from reports store getter
 * @param {Object} callbacks        - host-app action callbacks (e.g. { onShowDiff })
 * @returns {Object|null} view config, or null if the type is not yet supported
 */
export function buildReportView(entry, tzOffsetMs, interfaceNameMap = {}, policyNameMap = {}, callbacks = {}) {
  if (!entry) return null
  switch (entry.type) {
    case 'TIME_GRAPH':
      return {
        component: 'GenericChart',
        verticalLayout: true,
        reports: [translateTimeGraphEntry(entry)],
      }
    case 'TIME_GRAPH_DYNAMIC':
      return {
        component: 'GenericChart',
        verticalLayout: true,
        reports: [translateTimeGraphDynamicEntry(entry)],
      }
    case 'PIE_GRAPH':
      return {
        component: 'GenericChart',
        verticalLayout: true,
        reports: [translatePieGraphEntry(entry)],
      }
    case 'TEXT':
      return {
        component: 'GenericText',
        reports: [translateTextEntry(entry)],
      }
    case 'EVENT_LIST':
      return {
        component: 'GenericEventList',
        reports: [translateEventListEntry(entry, tzOffsetMs, interfaceNameMap, policyNameMap, callbacks)],
      }
    default:
      return null
  }
}
