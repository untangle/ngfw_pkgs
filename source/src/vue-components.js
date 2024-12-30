import Vue from 'vue'
import VueComponent from './VueComponent.vue'

import vuetify from '@/plugins/vuetify'
import vuntangle from '@/plugins/vuntangle'
import i18n from '@/plugins/vue-i18n'
import store from '@/store'

import 'vuetify/dist/vuetify.min.css'
import '@mdi/font/css/materialdesignicons.css'
import './scss/common.scss'

/**
 * Adds specified component into the dom
 * @param {String} component - component name (used as id too) (e.g. `NgfwAbout`)
 */
window.loadNgfwComponent = function (component) {
  new Vue({
    vuetify,
    vuntangle,
    i18n,
    store,
    render: h =>
      h(VueComponent, {
        props: {
          component,
        },
      }),
  }).$mount(`#${component}`)
}
