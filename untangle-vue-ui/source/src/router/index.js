import Vue from 'vue'
import VueRouter, { isNavigationFailure, NavigationFailureType } from 'vue-router'
import { UPageNotFound } from 'vuntangle'
import auth from './auth'
import setting from './setting'
import wizard from './wizard'
import appRouter from './apps'
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

const routes = baseRoutes.concat(auth, setting, wizard, appRouter, {
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
 */
router.beforeEach((to, from, next) => {
  try {
    const rpcOwner = window.top || window.parent

    // Reuse shared RPC client if available from parent
    if (rpcOwner?.rpc && !window.rpc) {
      window.rpc = rpcOwner.rpc
    }

    // Initialize RPC client if not already set
    if (!window.rpc) {
      const rpcClient = new window.JSONRpcClient('/admin/JSON-RPC')
      const startupInfo = rpcClient?.UvmContext?.getWebuiStartupInfo()

      if (startupInfo && typeof startupInfo === 'object') {
        Object.assign(rpcClient, startupInfo)
      }

      window.rpc = rpcClient
    }

    // Initialize admin context on first admin route navigation
    // Session module is NOT persisted, so it resets on every page load/hard refresh
    // This ensures RPC calls run on every session start
    // But skips re-initialization during route navigation within same session
    const isAdminRoute =
      to.name && !to.name.includes('setup') && !to.name.includes('login') && !to.name.includes('wizard')

    if (isAdminRoute) {
      // Initialize admin context (loads apps, policy-manager, reports)
      // Fire and forget - don't block navigation
      store.dispatch('session/initializeAdminContext')
    }

    // Stop metrics polling when leaving /apps section
    // Polling is started via beforeEnter guard in /apps route
    const leavingAppsSection = from?.path?.startsWith('/apps') && !to?.path?.startsWith('/apps')
    if (leavingAppsSection) {
      MetricsPollingService.stop()
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
