import Vue from 'vue'
import VueRouter, { isNavigationFailure, NavigationFailureType } from 'vue-router'
import { UPageNotFound } from 'vuntangle'
import setup from './setup'
import auth from './auth'
import setting from './setting'
import wizard from './wizard'
import Dashboard from '@/components/Dashboard/Main'

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
router.beforeEach((to, from, next) => {
  /**
   * On every iframe URL change, the iframe's window context is reset,
   * causing `window.rpc` to become null and triggering the JSONRpcClient constructor.
   * As a result, methods like `nonce` and `listMethod` are called repeatedly.
   *
   * To prevent this, when the app is accessed via an iframe, the `rpc` instance is retrieved
   * from the parent ExtJS tab (`rpcOwner`) and assigned to the current window.
   * This ensures the JSONRpcClient is not reinitialized on every load.
   *
   * Local or console-based execution flows remain unaffected.
   */
  const rpcOwner = window.top || window.parent
  if (rpcOwner.rpc && !window.rpc) window.rpc = rpcOwner.rpc
  if (!window.rpc) {
    try {
      window.rpc = new window.JSONRpcClient('/admin/JSON-RPC')
      if (window.rpc) {
        const startUpInfo = window.rpc.UvmContext.getWebuiStartupInfo()
        Object.assign(window.rpc, startUpInfo)
        if (!from.name && to.name?.includes('setup-') && to.name !== 'setup-wizard') {
          next({ name: 'wizard' })
        } else if (to.name === 'login') next({ name: 'home' })
        else {
          next()
        }
      }
    } catch (ex) {
      console.log(ex)
      if (to.name === 'setup') {
        return next({ name: 'wizard' })
      }
      next()
    }
  } else if (to.name === 'login') {
    next({ name: 'home' })
  } else next()
})

export default router
