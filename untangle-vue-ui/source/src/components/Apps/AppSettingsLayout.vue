<template>
  <div class="app-settings-layout">
    <!-- Dynamically loaded app-specific component -->
    <component :is="appComponent" v-if="appComponent" />
  </div>
</template>

<script>
  /**
   * AppSettingsLayout Component
   *
   * Dynamically loads app-specific components based on the route parameter.
   * Converts kebab-case app names to PascalCase component names.
   *
   * Example:
   * - Route: /apps/1/web-filter -> Loads ./apps/WebFilter/WebFilter.vue
   * - Route: /apps/1/captive-portal -> Loads ./apps/CaptivePortal/CaptivePortal.vue
   *
   * @component
   */
  export default {
    name: 'AppSettingsLayout',

    computed: {
      /**
       * Dynamically imports the app-specific component based on route params
       * @returns {Function} Dynamic import function
       */
      appComponent() {
        const appName = this.$route.params.appName

        if (!appName) {
          console.error('[AppSettingsLayout] No appName found in route params')
          return null
        }

        // Convert kebab-case to PascalCase
        // Example: 'web-filter' -> 'WebFilter'
        const componentName = this.kebabToPascal(appName)

        // Return dynamic import function
        // Vue Router will handle lazy loading and code splitting
        return () =>
          import(
            /* webpackChunkName: "app-[request]" */
            `./apps/${componentName}/${componentName}.vue`
          ).catch(error => {
            console.error(`[AppSettingsLayout] Failed to load component for app: ${appName}`, error)
            // Return null component on error
            return { render: h => h('div', 'App component not found') }
          })
      },
    },

    methods: {
      /**
       * Converts kebab-case string to PascalCase
       * @param {string} str - kebab-case string
       * @returns {string} PascalCase string
       * @example kebabToPascal('web-filter') // returns 'WebFilter'
       */
      kebabToPascal(str) {
        return str
          .split('-')
          .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
          .join('')
      },
    },
  }
</script>

<style lang="scss" scoped>
  .app-settings-layout {
    width: 100%;
    height: 100%;
  }
</style>
