/**
 * Report utilities - URL encoding, icons, URL generation, time-range adapters
 */
import util from '@/util/util'

/**
 * System (non-app) categories that always appear in the reports view.
 * RPC `getCurrentApplications` only returns app categories, so these
 * are merged in client-side. Order mirrors the Ext UI's viewPosition.
 */
export const baseCategories = [
  { name: 'hosts', displayName: 'Hosts', type: 'system', viewPosition: 1 },
  { name: 'devices', displayName: 'Devices', type: 'system', viewPosition: 2 },
  { name: 'network', displayName: 'Network', type: 'system', viewPosition: 3 },
  { name: 'administration', displayName: 'Administration', type: 'system', viewPosition: 4 },
  { name: 'system', displayName: 'System', type: 'system', viewPosition: 5 },
  { name: 'shield', displayName: 'Shield', type: 'system', viewPosition: 6 },
  { name: 'users', displayName: 'Users', type: 'system', viewPosition: 7 },
  { name: 'events', displayName: 'Events', type: 'system', viewPosition: 8 },
]

/**
 * URL encode for report URLs
 * Spaces → dashes, lowercase, encode non-ASCII
 */
export function urlEncode(url) {
  let encodedUrl = url.replace(/\s+/g, '-').toLowerCase()
  encodedUrl = encodeURIComponent(encodedUrl)
  encodedUrl = encodedUrl.replace(/%2D/g, '-')
  return encodedUrl
}

/**
 * Map report type to MDI icon
 * Types: TEXT, PIE_GRAPH, TIME_GRAPH, TIME_GRAPH_DYNAMIC, EVENT_LIST
 */
export function getReportIcon(type) {
  const iconMap = {
    TEXT: 'mdi-file-document-outline',
    PIE_GRAPH: 'mdi-chart-pie',
    TIME_GRAPH: 'mdi-chart-line',
    TIME_GRAPH_DYNAMIC: 'mdi-chart-areaspline',
    EVENT_LIST: 'mdi-table-large',
  }
  return iconMap[type] || 'mdi-file-chart'
}

/**
 * Construct report URL for given category and title
 */
export function getReportUrl(category, title) {
  return `https://${window.location.host}/admin/index.do#reports?cat=${urlEncode(category)}&rep=${urlEncode(title)}`
}

/**
 * Transform backend report to UI format for UAppStatusReports component
 */
export function formatReportForUI(report) {
  return {
    key: report.uniqueId,
    label: report.title || report.uniqueId,
    url: getReportUrl(report.category, report.title),
    icon: getReportIcon(report.type),
  }
}

/**
 * Transform reports array to UI format
 */
export function formatReportsForUI(reports) {
  if (!Array.isArray(reports)) {
    return []
  }
  return reports.map(formatReportForUI)
}

// ---------------------------------------------------------------------------
// Time-range handling — host-owned, mirrors the ExtJS
// `Ung.reports.cmp.TimeConditions` contract.
//
// Canonical shape used by the shared <NewReportDetails> component:
//   { period: [startMs]          }  → "since" only, open-ended (until = now)
//   { period: [startMs, endMs]   }  → bounded range
// ---------------------------------------------------------------------------

const HOUR_MS = 3600 * 1000
const DAY_MS = 24 * HOUR_MS

/** Server "now" in ms — falls back to Date.now() when no RPC context */
function serverNow() {
  return util.getMilliseconds() || Date.now()
}

/** Midnight of the date that contains `ms`, in the local timezone */
function startOfDay(ms) {
  const d = new Date(ms)
  d.setHours(0, 0, 0, 0)
  return d.getTime()
}

/** Default range — "Today", matching ExtJS `afterRender` initial value */
export function getDefaultReportRange() {
  return { period: [startOfDay(serverNow())] }
}

/**
 * Preset list aligned with ExtJS `TimeConditions.ranges`.
 * Each `build()` returns a fresh value using the current server clock.
 */
export const reportTimeRangePresets = [
  {
    id: 'last_hour',
    label: 'last_hour',
    build: () => ({ period: [serverNow() - HOUR_MS] }),
  },
  {
    id: 'last_6_hours',
    label: 'last_6_hours',
    build: () => ({ period: [serverNow() - 6 * HOUR_MS] }),
  },
  {
    id: 'last_24h',
    label: 'last_24h',
    build: () => ({ period: [serverNow() - 24 * HOUR_MS] }),
  },
  {
    id: 'last_48h',
    label: 'last_48h',
    build: () => ({ period: [serverNow() - 48 * HOUR_MS] }),
  },
  {
    id: 'today',
    label: 'today',
    build: () => ({ period: [startOfDay(serverNow())] }),
  },
  {
    id: 'yesterday',
    label: 'yesterday',
    build: () => ({ period: [startOfDay(serverNow()) - DAY_MS] }),
  },
  {
    id: 'this_week',
    label: 'this_week',
    build: () => {
      const today = startOfDay(serverNow())
      return { period: [today - new Date(today).getDay() * DAY_MS] }
    },
  },
  {
    id: 'last_week',
    label: 'last_week',
    build: () => {
      const today = startOfDay(serverNow())
      return { period: [today - (new Date(today).getDay() + 7) * DAY_MS] }
    },
  },
  {
    id: 'this_month',
    label: 'this_month',
    build: () => {
      const d = new Date(serverNow())
      return { period: [new Date(d.getFullYear(), d.getMonth(), 1).getTime()] }
    },
  },
]

/**
 * Convert a canonical time-range to the (startDate, endDate) pair the
 * `rpc.reportsManager.getDataForReportEntry` RPC expects. Mirrors the
 * ExtJS `Util.clientToServerDate` step in GraphReport/EventReport/TextReport.
 *
 *   { period: [startMs] }         → { startDate: Date, endDate: null }
 *   { period: [startMs, endMs] }  → { startDate: Date, endDate: Date }
 *
 * `endDate: null` is meaningful — the backend treats it as "to now".
 */
export function rangeToRpc(timeRange) {
  const period = timeRange?.period || []
  return {
    startDate: period[0] != null ? new Date(period[0]) : null,
    endDate: period.length > 1 ? new Date(period[1]) : null,
  }
}

// ---------------------------------------------------------------------------
// Per-type adapters: NGFW `ReportEntry` → vuntangle report config.
// Each host-side adapter wraps a backend entry in the shape vuntangle's
// view components (GenericText, GenericGrid, …) expect. Keeping these here
// isolates the vuntangle contract from `ReportEntry` so the backend stays
// host-agnostic.
// ---------------------------------------------------------------------------

const EVENT_GRID_DEFAULT_LIMIT = 3000

/** EVENT_LIST → vuntangle GenericGrid report config */
export function translateEventListEntry(entry) {
  return {
    title: entry.title,
    columns: {
      all: entry.defaultColumns || [],
      hidden: [],
      renamed: {},
    },
    query: {
      type: 'EVENTS',
      table: entry.table,
      conditions: entry.conditions || [],
      queryEvents: { limit: EVENT_GRID_DEFAULT_LIMIT },
    },
  }
}

/**
 * Build a vuntangle view config from a NGFW `ReportEntry`.
 * Returns null for types not yet supported in the Vue UI.
 */
export function buildReportView(entry) {
  if (!entry) return null
  switch (entry.type) {
    case 'TEXT':
      return { id: entry.uniqueId, component: 'GenericText', reports: [entry] }
    case 'EVENT_LIST':
      return { id: entry.uniqueId, component: 'GenericGrid', reports: [translateEventListEntry(entry)] }
    default:
      return null
  }
}
