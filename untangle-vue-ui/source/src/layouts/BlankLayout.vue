<template>
  <v-app>
    <!-- Importing nav bar takes care of language setting, but keep it hidden on blank layout -->
    <app-nav v-show="false" />
    <dynamic-drawer />
    <v-main>
      <router-view class="d-flex flex-column fill-height" />
    </v-main>

    <v-overlay v-model="$store.state.pageLoad">
      <v-progress-circular indeterminate size="32" color="aristaBlue" />
    </v-overlay>

    <u-framework-dialog />
    <u-framework-confirm />
    <u-framework-toast />
  </v-app>
</template>
<script>
  import AppNav from './AppNav.vue'
  import DynamicDrawer from './DynamicDrawer.vue'

  export default {
    components: { AppNav, DynamicDrawer },
  }
</script>
