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
