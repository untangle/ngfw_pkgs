/**
 * Report utilities - URL encoding, icons, URL generation
 */

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
