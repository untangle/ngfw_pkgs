<template>
  <v-container class="d-flex pa-2">
    <component :is="componentName" v-if="componentName"> </component>
  </v-container>
</template>
<script>
  import { NgfwAbout, NgfwDns, NgfwDhcp, NgfwStaticRoutes, Settings } from '@/ngfw'
  import { DynamicBlockLists } from '@/services'
  import store from '@/store'

  export default {
    components: { NgfwAbout, NgfwDns, NgfwDhcp, NgfwStaticRoutes, Settings, DynamicBlockLists },

    async beforeRouteEnter(to, from, next) {
      await store.dispatch('settings/fetchNetworkSettings')
      next()
    },

    computed: {
      componentName: ({ $route }) => $route?.params?.componentName,
    },
  }
</script>
