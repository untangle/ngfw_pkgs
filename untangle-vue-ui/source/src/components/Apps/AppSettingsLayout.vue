<template>
  <div class="app-settings-layout">
    <!-- Dynamically loaded app-specific component -->
    <component :is="appComponent" v-if="appComponent" :app-data="appData" />
  </div>
</template>

<script>
  import { mapGetters } from 'vuex'
  import util from '@/util/util'

  /**
   * AppSettingsLayout Component
   *
   * Dynamically loads app-specific components based on the route parameter.
   * Converts kebab-case app names to PascalCase component names.
   * Fetches and passes app data (license, instance, properties, metrics) to the component.
   *
   * Example:
   * - Route: /apps/1/web-filter -> Loads ./apps/WebFilter/WebFilter.vue
   * - Route: /apps/1/captive-portal -> Loads ./apps/CaptivePortal/CaptivePortal.vue
   *
   * @component
   */
  export default {
    name: 'AppSettingsLayout',

    provide() {
      return {
        isReportsInstalled: !!util.isReportsInstalled(),
      }
    },

    computed: {
      ...mapGetters('apps', ['getAppData']),

      /**
       * Get policyId from route params
       * @returns {number|null} Policy ID
       */
      policyId() {
        const id = this.$route.params.policyId
        return id ? parseInt(id, 10) : null
      },

      /**
       * Get appName from route params
       * @returns {string|null} App name
       */
      appName() {
        return this.$route.params.appName || null
      },

      /**
       * Get complete app data including license, instance, properties, and metrics
       * Also adds computed properties like iconPath
       * @returns {Object|null} App data object
       */
      appData() {
        if (!this.policyId || !this.appName) {
          return null
        }

        const baseAppData = this.getAppData({
          policyId: this.policyId,
          appName: this.appName,
        })

        // Add icon path (common for all apps)
        return {
          ...baseAppData,
          iconPath: this.iconPath,
        }
      },

      /**
       * Icon path for the app using webpack require
       * @returns {string|null} Icon path or null if not found
       */
      iconPath() {
        if (!this.appName) return null

        try {
          return require(`@/assets/icons/apps/${this.appName}.svg`)
        } catch (e) {
          return null
        }
      },

      /**
       * Dynamically imports the app-specific component based on route params
       * @returns {Function} Dynamic import function
       */
      appComponent() {
        if (!this.appName) {
          console.error('[AppSettingsLayout] No appName found in route params')
          return null
        }

        // Convert kebab-case to PascalCase
        // Example: 'web-filter' -> 'WebFilter'
        const componentName = this.kebabToPascal(this.appName)

        // Return dynamic import function
        // Vue Router will handle lazy loading and code splitting
        return () =>
          import(
            /* webpackChunkName: "app-[request]" */
            `./apps/${componentName}/${componentName}.vue`
          ).catch(error => {
            console.error(`[AppSettingsLayout] Failed to load component for app: ${this.appName}`, error)
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
