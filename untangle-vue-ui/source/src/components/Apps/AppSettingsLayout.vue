<template>
  <v-container fluid :class="`shared-cmp d-flex flex-column flex-grow-1 pa-2`">
    <no-license v-if="isLicensed === false" class="mt-2">
      {{ $t('not_licensed_app', [$t(appData?.appProperties?.displayName)]) }}
      <template #actions>
        <u-btn class="ml-4" to="/settings/system/about">{{ $t('view_system_license') }}</u-btn>
        <u-btn class="ml-4" :href="manageLicenseUri" target="_blank">
          {{ $t('manage_licenses') }}
          <v-icon right> mdi-open-in-new </v-icon>
        </u-btn>
      </template>
    </no-license>
    <!-- Dynamically loaded app-specific component -->
    <component
      :is="appComponent"
      v-if="appComponent"
      :app-data="appData"
      :class="`shared-cmp d-flex flex-column flex-grow-1 ${!isLicensed && 'disabled'}`"
    />
  </v-container>
</template>

<script>
  import { NoLicense } from 'vuntangle'
  import { mapGetters } from 'vuex'
  import util from '@/util/util'
  import uris from '@/util/uris'

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
    components: {
      NoLicense,
    },

    data() {
      return {
        isLicensed: undefined,
        manageLicenseUri: undefined,
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
          return null
        }

        // Convert kebab-case to PascalCase
        const componentName = util.kebabToPascal(this.appName)

        // Return dynamic import function
        // Vue Router will handle lazy loading and code splitting
        return () =>
          import(`./apps/${componentName}/${componentName}.vue`).catch(() => {
            return { render: h => h('div', 'App component not found') }
          })
      },
    },

    created() {
      this.checkLicense()
      this.getManageLicenseUri()
    },

    methods: {
      /**
       * PROP: is-licensed
       * Checks for TP license status
       */
      async checkLicense() {
        if (!this.appName) return
        const response = await window.rpc.UvmContext.licenseManager().isLicenseValid(this.appName)
        this.isLicensed = response
      },

      /**
       * PROP: manage-license-uri
       * Fetches the URI for license management
       */
      async getManageLicenseUri() {
        this.manageLicenseUri = await window.rpc.uriManager.getUriWithPath(uris.list.subscriptions)
      },
    },
  }
</script>
