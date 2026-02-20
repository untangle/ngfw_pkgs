/**
 * Reports Service
 *
 * Provides abstraction layer for accessing reports data from components
 * that don't use appStatusMixin. Components using the mixin should access
 * reports via the mixin's computed properties instead.
 *
 * This service wraps Vuex store access and provides formatted data
 * ready for UI consumption.
 */

import store from '@/store'
import { formatReportsForUI, getReportUrl, getReportIcon } from '@/util/reports'

export default {
  /**
   * Get reports for a specific app category
   * @param {String} category - App display name (e.g., 'Application Control Lite')
   * @returns {Array} - Formatted reports array ready for UI
   */
  getReportsByCategory(category) {
    const rawReports = store.getters['reports/getReportsByCategory'](category)
    return formatReportsForUI(rawReports)
  },

  /**
   * Check if Reports app is installed
   * @returns {Boolean}
   */
  isReportsInstalled() {
    return store.getters['reports/isReportsInstalled']
  },

  /**
   * Get all reports
   * @returns {Array} - All formatted reports
   */
  getAllReports() {
    const rawReports = store.getters['reports/allReports']
    return formatReportsForUI(rawReports)
  },

  /**
   * Refresh reports from backend
   * @returns {Promise<Object>} - Result object with success status
   */
  refreshReports() {
    return store.dispatch('reports/loadReports')
  },

  /**
   * Get report URL
   * Direct access to utility function for convenience
   * @param {String} category - Report category
   * @param {String} title - Report title
   * @returns {String} - Report URL
   */
  getReportUrl(category, title) {
    return getReportUrl(category, title)
  },

  /**
   * Get report icon
   * Direct access to utility function for convenience
   * @param {String} type - Report type (TEXT, PIE_GRAPH, etc.)
   * @returns {String} - MDI icon name
   */
  getReportIcon(type) {
    return getReportIcon(type)
  },

  /**
   * Check if reports are loaded
   * @returns {Boolean}
   */
  isLoaded() {
    return store.getters['reports/isLoaded']
  },

  /**
   * Get loading state
   * @returns {Boolean}
   */
  isLoading() {
    return store.getters['reports/loading']
  },

  /**
   * Get error state
   * @returns {String|null}
   */
  getError() {
    return store.getters['reports/error']
  },
}
