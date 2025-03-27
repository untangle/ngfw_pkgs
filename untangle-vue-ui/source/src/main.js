import Vue from 'vue'
import i18n from './plugins/vue-i18n'
import vuetify from './plugins/vuetify'
import vuntangle from './plugins/vuntangle'
import router from './router'
import store from './store'
import App from './App'
import './scss/common.scss'

new Vue({
  vuetify,
  vuntangle,
  router,
  store,
  i18n,
  render: h => h(App),
}).$mount('#app')
