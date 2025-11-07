<!-- This component is required for rendering vue pages in ExtJs project using iFrame. It can be removed once all the code is migrated to vue -->
<template>
  <v-app>
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
  import DynamicDrawer from './DynamicDrawer.vue'

  export default {
    name: 'DynamicLayout',
    components: { DynamicDrawer },
  }
</script>
