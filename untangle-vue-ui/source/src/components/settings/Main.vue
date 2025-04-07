<template>
  <v-container class="d-flex fill-height align-stretch pa-2" fluid>
    <router-view />
  </v-container>
</template>
<script>
  export default {
    // redirect to first sub menu route from /settings
    beforeRouteEnter(to, from, next) {
      to.name === 'settings' ? next({ path: '/settings/network/interfaces' }) : next()
    },
    beforeRouteUpdate(to, from, next) {
      to.name === 'settings' ? next({ path: '/settings/network/interfaces' }) : next()
    },
  }
</script>
