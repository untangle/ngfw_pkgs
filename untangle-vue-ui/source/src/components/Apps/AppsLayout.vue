<template>
  <!-- Root layout container for all apps-related routes -->
  <v-container class="apps-layout" fluid>
    <!-- Child routes (AppsView or AppSettingsLayout) will render here -->
    <router-view />
  </v-container>
</template>

<script>
  /**
   * AppsLayout Component
   *
   * Root layout component for the Apps module.
   * Provides a container for child routes (AppsView and AppSettingsLayout).
   *
   * Routes:
   * - /apps/:policyId -> AppsView
   * - /apps/:policyId/:appName -> AppSettingsLayout
   *
   * @component
   */
  export default {
    name: 'AppsLayout',
  }
</script>

<style lang="scss" scoped>
  .apps-layout {
    display: flex;
    align-items: stretch;
    height: 100%;
    padding: 0.5rem;
  }
</style>
