<template>
  <v-app>
    <app-nav />
    <app-drawer />
    <v-main class="d-flex">
      <router-view class="d-flex flex-column fill-height" />
    </v-main>

    <v-overlay v-model="$store.state.fetching">
      <v-progress-circular indeterminate size="32" color="aristaBlue" />
    </v-overlay>

    <u-framework-dialog />
    <u-framework-confirm />
    <u-framework-toast />
  </v-app>
</template>
<script>
  import AppNav from './AppNav.vue'
  import AppDrawer from './AppDrawer.vue'

  export default {
    components: { AppNav, AppDrawer },
  }
</script>
