import Vue from 'vue'
import VueRouter, { isNavigationFailure, NavigationFailureType } from 'vue-router'
import { UPageNotFound } from 'vuntangle'
import auth from './auth'
import setting from './setting'
import wizard from './wizard'
import quarantine from './quarantine'
import userapi from './userapi'
import appRouter from './apps'
import reports from './reports'
import Dashboard from '@/components/Dashboard/Main'
import store from '@/store'
import MetricsPollingService from '@/services/MetricsPollingService'

/**
 * Override .push() to catch navigation failures.
 * Log nav guard redirection
 */

const originalPush = VueRouter.prototype.push
VueRouter.prototype.push = function push(location) {
  return originalPush.call(this, location).catch(err => {
    // do not show a navigation duplicated error, this is done when the users clicks on the same page they are at
    if (isNavigationFailure(err, NavigationFailureType.duplicated)) {
      return
    }

    if (isNavigationFailure(err, NavigationFailureType.redirected)) {
      // eslint-disable-next-line
      console.debug('redirected by navigation guard')
    } else {
      // eslint-disable-next-line
      console.error(err)
    }
  })
}

Vue.use(VueRouter)

const baseRoutes = [
  {
    path: '/dashboard',
    name: 'dashboard',
    component: Dashboard,
    meta: { helpContext: 'dashboard' },
  },
]

const routes = baseRoutes.concat(auth, setting, wizard, quarantine, userapi, appRouter, reports, {
  path: '*',
  name: 'page-not-found',
  component: UPageNotFound,
  meta: { title: 'page_not_found' },
})

const router = new VueRouter({
  mode: 'history',
  base: process.env.VUE_APP_BASE_URL,
  routes,
})

/**
 * Vue Router navigation guard to initialize shared JSON-RPC client.
 *
 * This ensures the `window.rpc` is only initialized once per session,
 * even when Vue is loaded inside an iframe that reloads on tab changes.
 * The client is reused across iframe loads to prevent redundant `getNonce` or `listMethods` calls.
 *
 * Note: Quarantine routes are public and should NOT initialize admin RPC
 * to avoid authentication calls. They use /quarantine/JSON-RPC instead.
 */
router.beforeEach(async (to, from, next) => {
  try {
    // Skip admin RPC initialization for public quarantine routes
    // These routes use /quarantine/JSON-RPC endpoint without authentication
    const isQuarantineRoute = to.path?.startsWith('/quarantine')

    if (isQuarantineRoute) {
      return next()
    }

    // Initialize application context from URL query string on first navigation
    if (!store.getters['session/isAdminContextInitialized'] && !store.state.session.reportsContextInitialized) {
      store.dispatch('context/initContext')
    }

    const isReportsContext = store.getters['context/isReports']
    const rpcEndpoint = store.getters['context/rpcEndpoint']

    const rpcOwner = window.top || window.parent

    // Reuse shared RPC client if available from parent (Admin iframe case)
    if (!isReportsContext && rpcOwner?.rpc && !window.rpc) {
      window.rpc = rpcOwner.rpc
    }

    // Initialize RPC client if not already set
    if (!window.rpc) {
      const rpcClient = new window.JSONRpcClient(rpcEndpoint)

      if (isReportsContext) {
        // Standalone Reports — initialize timezone from ReportsContext
        const tzOffset = rpcClient?.ReportsContext?.getTimeZoneOffset()
        if (tzOffset != null) {
          rpcClient.timeZoneOffset = tzOffset
        }
      } else {
        // Admin — initialize from UvmContext startup info
        const startupInfo = rpcClient?.UvmContext?.getWebuiStartupInfo()
        if (startupInfo && typeof startupInfo === 'object') {
          Object.assign(rpcClient, startupInfo)
        }
      }

      window.rpc = rpcClient
    }

    // Block routes that require admin context when running in REPORTS mode
    const requiresAdmin = to.matched.some(({ meta }) => meta.requiresAdmin)
    if (isReportsContext && requiresAdmin) {
      return next({ name: 'reports', replace: true })
    }

    const requiresReportsApp = to.matched.some(({ meta }) => meta.requiresReportsApp)

    if (isReportsContext) {
      // Standalone Reports context — lightweight initialization (reports + timezone only)
      const initialization = store.dispatch('session/initializeReportsContext')

      if (requiresReportsApp) {
        await initialization
      }
    } else {
      // Admin context
      const nonAdminSegments = ['setup', 'login', 'wizard']
      const isAdminRoute = !nonAdminSegments.some(
        segment => to.name?.includes(segment) || to.path?.startsWith(`/${segment}`),
      )

      if (isAdminRoute) {
        const initialization = store.dispatch('session/initializeAdminContext')

        if (requiresReportsApp) {
          await initialization

          if (store.getters['reports/reportsAvailability'] === false) {
            return next({ path: '/settings/services/reports', replace: true })
          }
        }
      }
    }

    // Start/stop metrics polling based on whether the route requires it
    // /apps routes always require metrics; other routes opt-in via meta.requiresMetrics
    // Metrics are not available in standalone Reports context
    if (!isReportsContext) {
      const fromRequiresMetrics = from?.path?.startsWith('/apps') || from?.meta?.requiresMetrics
      const toRequiresMetrics = to?.path?.startsWith('/apps') || to?.meta?.requiresMetrics
      if (toRequiresMetrics && !fromRequiresMetrics) {
        MetricsPollingService.start()
      } else if (fromRequiresMetrics && !toRequiresMetrics) {
        MetricsPollingService.stop()
      }
    }

    // Redirect logic
    if (!from?.name && to?.name?.includes('setup-') && to?.name !== 'setup-wizard') {
      return next({ name: 'wizard' })
    }

    if (to?.name === 'login') {
      return next({ name: 'home' })
    }

    next()
  } catch (error) {
    // Fallback redirect on initialization failure
    if (to?.name === 'setup') {
      return next({ name: 'wizard' })
    }
    next()
  }
})

export default router
