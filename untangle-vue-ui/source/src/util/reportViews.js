/**
 * Report view translation layer.
 * Converts backend report entries into view configs consumed by the display components.
 */

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
 * @param {Object} entry - report entry definition
 * @returns {Object|null} view config, or null if the type is not yet supported
 */
export function buildReportView(entry) {
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
    default:
      return null
  }
}
