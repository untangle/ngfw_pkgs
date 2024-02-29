import Vue from 'vue'
import VueRouter from 'vue-router'

import Login from '@/views/Login.vue'
import Home from '@/views/Home.vue'
import Component from '@/views/Component.vue'

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
]

const router = new VueRouter({
  mode: 'history',
  base: '/vue/',
  routes,
})

router.beforeEach((to, from, next) => {
  if (!window.rpc) {
    try {
      window.rpc = new window.JSONRpcClient('/admin/JSON-RPC')
      if (window.rpc) {
        const startUpInfo = window.rpc.UvmContext.getWebuiStartupInfo()
        Object.assign(window.rpc, startUpInfo)
        if (to.name === 'login') next({ name: 'home' })
        else next()
      }
    } catch (ex) {
      if (to.name !== 'login') next({ name: 'login' })
      else next()
    }
  } else if (to.name === 'login') next({ name: 'home' })
  else next()
})

export default router
