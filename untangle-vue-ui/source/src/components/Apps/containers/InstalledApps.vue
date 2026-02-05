<template>
  <!-- Grid container for installed apps -->
  <div class="installed-apps">
    <!-- App Card for each installed app -->
    <app-card v-for="(app, key) in installedApps" :key="key" :app="app" />
  </div>
</template>

<script>
  import AppCard from '../components/AppCard.vue'

  /**
   * InstalledApps Component
   *
   * Container component that displays a grid of installed applications.
   * Uses AppCard components to render individual app cards.
   *
   * Features:
   * - Responsive grid layout with gap spacing
   * - Dynamic rendering based on installedApps prop
   * - Delegates app-specific rendering to AppCard component
   *
   * @component
   */
  export default {
    name: 'InstalledApps',

    components: {
      AppCard,
    },

    props: {
      /**
       * Array of installed app objects
       * Each app should have properties required by AppCard component
       * @type {Array<Object>}
       */
      installedApps: {
        type: Array,
        required: true,
        default: () => [],
      },
    },
  }
</script>

<style lang="scss" scoped>
  .installed-apps {
    display: flex;
    flex-direction: row;
    flex-wrap: wrap;
    gap: 0.875rem; // 14px
  }
</style>
