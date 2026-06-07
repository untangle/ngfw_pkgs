/**
 * Report utilities - URL encoding, icons, URL generation, category helpers
 */

/**
 * System report categories that are always present regardless of which apps are installed.
 */
export const baseCategories = [
  { name: 'hosts', type: 'system', displayName: 'Hosts', viewPosition: 1 },
  { name: 'devices', type: 'system', displayName: 'Devices', viewPosition: 2 },
  { name: 'users', type: 'system', displayName: 'Users', viewPosition: 3 },
  { name: 'network', type: 'system', displayName: 'Network', viewPosition: 4 },
  { name: 'administration', type: 'system', displayName: 'Administration', viewPosition: 5 },
  { name: 'events', type: 'system', displayName: 'Events', viewPosition: 6 },
  { name: 'system', type: 'system', displayName: 'System', viewPosition: 7 },
  { name: 'shield', type: 'system', displayName: 'Shield', viewPosition: 8 },
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
 * Transforms a single backend report entry into the UI display format.
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

/**
 * Exports report definitions for a category (or all reports) as a downloadable JSON file.
 * Strips UI-computed fields and triggers a client-side Blob download.
 * @param {Array}  allReports   - full reports array from the store
 * @param {string} categoryName - category to export; if omitted exports all reports
 */
export function exportCategoryReports(allReports, categoryName) {
  const COMPUTED_FIELDS = ['localizedTitle', 'localizedDescription', 'slug', 'categorySlug', 'url', 'icon', '_id']

  const source = categoryName ? allReports.filter(r => r.category === categoryName) : allReports

  const data = source.map(report => {
    const rep = { ...report }
    COMPUTED_FIELDS.forEach(field => delete rep[field])
    return rep
  })

  const filename = `AllReports${categoryName ? '_' + categoryName.replace(/ /g, '_') : ''}.json`
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}
