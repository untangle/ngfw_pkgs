import Vue from 'vue'
import VueRouter from 'vue-router'
import Login from '@/views/Login.vue'
import Home from '@/views/Home.vue'
import Component from '@/views/Component.vue'
// import Setupwizard from '@/Setup_wizard/Setupwizard.vue'
import SetupMain from '@/Setup_wizard/SetupMain.vue'
Vue.use(VueRouter)

const routes = [
  {
    path: '/',
    name: 'home',
    component: Home,
  },
  {
    path: '/login',
    name: 'login',
    component: Login,
  },

  {
    path: '/:componentName',
    name: 'component',
    component: Component,
  },
  {
    path: '/setupwizard',
    name: 'setupwizard',
    // component: Setupwizard,
    component: SetupMain,
  },
]

const router = new VueRouter({
  mode: 'history',
  base: '/vue/',
  routes,
})

router.beforeEach((to, from, next) => {
  if (to.name === 'login' || to.name === 'setupwizard') {
    return next()
  }
  if (!window.rpc) {
    try {
      window.rpc = {}
      window.rpc.setup = new window.JSONRpcClient('/setup/JSON-RPC').SetupContext
      // window.setup = window.rpc.SetupContext
      // console.log('window.rpc.setup', window.rpc.setup)
      window.rpc.setup.getSetupWizardStartupInfo(function (result) {
        // console.log('result', result)
        window.setupWizardData = result
      })
      // console.log('window.setupWizardData', window.setupWizardData)

      if (window.rpc) {
        const startUpInfo = window.rpc.UvmContext.getWebuiStartupInfo()
        Object.assign(window.rpc, startUpInfo)
        if (to.name === 'login') next({ name: 'home' })
        else next()
      }
    } catch (ex) {
      if (to.name !== 'login') next({ name: 'login' })
      else next()
      if (to.name !== 'setupwizard') next({ name: 'setupwizard' })
      else next()
    }
  } else if (to.name === 'login') next({ name: 'home' })
  else next()
})

export default router
