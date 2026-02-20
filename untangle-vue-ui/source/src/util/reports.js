/**
 * Report utilities
 */

/**
 * URL encode for report URLs matching ExtJS Util.urlEncode behavior
 * From ExtJS Util.js:
 * - Spaces replaced with dashes
 * - Convert to lowercase
 * - All other non-ASCII characters URL encoded
 *
 * @param {String} url - URL component to encode
 * @returns {String} - Encoded URL component
 */
export function urlEncode(url) {
  // Replace all spaces with dashes and convert to lowercase
  let encodedUrl = url.replace(/\s+/g, '-').toLowerCase()

  // URL encode the string (mimics Ext.Object.toQueryString({'':encodedUrl}).substr(1))
  encodedUrl = encodeURIComponent(encodedUrl)

  // Decode the dashes back since they should remain as dashes (not %2D)
  encodedUrl = encodedUrl.replace(/%2D/g, '-')

  return encodedUrl
}

/**
 * Map report type to Material Design Icon
 * Report types from backend: TEXT, PIE_GRAPH, TIME_GRAPH, TIME_GRAPH_DYNAMIC, EVENT_LIST
 * @param {String} type - Report type
 * @returns {String} - MDI icon name
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
 * Construct report URL for navigation to ExtJS Reports page
 * Matches ExtJS format from EntryController.js:
 * Ung.app.redirectTo('#reports?cat=' + Util.urlEncode(entry.get('category')) + '&rep=' + Util.urlEncode(entry.get('title')))
 * @param {String} category - Report category (e.g., 'Application Control Lite')
 * @param {String} title - Report title (e.g., 'Application Control Lite Summary')
 * @returns {String} - Full report URL with URL-encoded parameters
 */
export function getReportUrl(category, title) {
  return `https://192.168.56.186/admin/index.do#reports?cat=${urlEncode(category)}&rep=${urlEncode(title)}`
}

/**
 * Transform backend report to UI format
 * Converts raw report object from backend to the format expected by UAppStatusReports component
 * @param {Object} report - Raw report from backend
 * @param {String} report.uniqueId - Unique report identifier
 * @param {String} report.category - Report category (app display name)
 * @param {String} report.title - Report title
 * @param {String} report.type - Report type (TEXT, PIE_GRAPH, TIME_GRAPH, etc.)
 * @returns {Object} - Formatted report for UI
 * @returns {String} return.key - Unique identifier
 * @returns {String} return.label - Display label
 * @returns {String} return.url - Navigation URL
 * @returns {String} return.icon - MDI icon name
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
 * Transform reports list for UI consumption
 * @param {Array} reports - Array of backend reports
 * @returns {Array} - Array of formatted reports
 */
export function formatReportsForUI(reports) {
  if (!Array.isArray(reports)) {
    return []
  }
  return reports.map(formatReportForUI)
}
