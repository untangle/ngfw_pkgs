import Vue from 'vue'
import i18n from './plugins/vue-i18n'
import vuetify from './plugins/vuetify'
import vuntangle from './plugins/vuntangle'
import router from './router'
import store from './store'
import App from './App'
import './scss/common.scss'
import { RpcPlugin } from '@/plugins/rpc'

Vue.config.productionTip = false
Vue.use(RpcPlugin) // Created in the Rpc plugins then you can accessable all over the vue with using - this.$rpcClient

new Vue({
  vuetify,
  vuntangle,
  router,
  store,
  i18n,
  render: h => h(App),
}).$mount('#app')
