import Vue from 'vue'
import VueRouter, { isNavigationFailure, NavigationFailureType } from 'vue-router'
import { UPageNotFound } from 'vuntangle'
import setup from './setup'
import auth from './auth'
import setting from './setting'
import wizard from './wizard'
import Dashboard from '@/components/Dashboard/Main'
import Util from '@/util/setupUtil'

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

const routes = baseRoutes.concat(auth, setup, setting, wizard, {
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

    // Redirect logic
    if (!from?.name && to?.name?.includes('setup-') && to?.name !== 'setup-wizard') {
      return next({ name: 'wizard' })
    }

    if (to?.name === 'login') {
      return next({ name: 'home' })
    }

    next()
  } catch (error) {
    Util.handleException(error)
    // Fallback redirect on initialization failure
    if (to?.name === 'setup') {
      return next({ name: 'wizard' })
    }
    next()
  }
})

export default router
