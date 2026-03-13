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
      @refreshLicenseStatus="checkLicense"
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
   * Handles license checking and displays appropriate messages if the app is not licensed.
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
      policyId: ({ $route }) => ($route.params.policyId ? parseInt($route.params.policyId, 10) : null),

      /**
       * Get appName from route params
       * @returns {string|null} App name
       */
      appName: ({ $route }) => $route.params.appName || null,

      /**
       * Icon path for the app using webpack require
       * @returns {string|null} Icon path or null if appName is not available
       */
      iconPath: ({ appName }) => (appName ? require(`@/assets/icons/apps/${appName}.svg`) : null),

      /**
       * Get complete app data including license, instance, properties, and metrics
       * Also adds computed properties like iconPath
       * @returns {Object|null} App data object
       */
      appData: ({ getAppData, policyId, appName, iconPath }) => {
        if (!policyId || !appName) return null

        // Fetch base app data from Vuex store using the getter
        const baseAppData = getAppData({ policyId, appName })

        // Add icon path
        return { ...baseAppData, iconPath }
      },

      /**
       * Dynamically imports the app-specific component based on route params
       * @returns {Function} Dynamic import function
       */
      appComponent: ({ appName }) => {
        if (!appName) return null

        // Convert kebab-case to PascalCase
        const componentName = util.kebabToPascal(appName)

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
       * Checks if the app is licensed by calling the license manager via RPC
       * Sets the isLicensed data property based on the response
       */
      async checkLicense() {
        if (!this.appName) return
        const response = await window.rpc.UvmContext.licenseManager().isLicenseValid(this.appName)
        this.isLicensed = response
      },

      /**
       * Fetches the URI for managing licenses and sets the manageLicenseUri data property
       */
      async getManageLicenseUri() {
        this.manageLicenseUri = await window.rpc.uriManager.getUriWithPath(uris.list.subscriptions)
      },
    },
  }
</script>
