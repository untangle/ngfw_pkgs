<template>
  <v-container fluid class="apps-view">
    <!-- Apps Toolbar - Policy selector and action buttons -->
    <apps-toolbar
      v-if="selectedPolicy"
      :policy-manager-installed="policyManagerInstalled"
      :install-mode="installMode"
      :selected-policy="selectedPolicy"
      :hierarchical-policies="hierarchicalPolicies"
      :auto-install-apps="autoInstallApps"
      :show-install-button="showInstallButton"
      @policy-change="onPolicyChange"
      @manage-policies="managePolicies"
      @install-apps="installApps"
      @back-to-policy="backToPolicy"
    />

    <!-- Main Content Area -->
    <div v-if="selectedPolicy" class="apps-view__content">
      <!-- Page Title -->
      <h1 class="apps-view__title">{{ $vuntangle.$t('apps') }}</h1>

      <!-- Divider -->
      <v-divider class="apps-view__divider" />

      <!-- Installed Apps Grid (default view) -->
      <installed-apps v-if="!installMode" :installed-apps="installedApps" />

      <!-- Installable Apps Grid (install mode) -->
      <installable-apps v-else :apps="installableApps" :policy-id="policyId" />
    </div>
  </v-container>
</template>

<script>
  import InstalledApps from './containers/InstalledApps.vue'
  import InstallableApps from './containers/InstallableApps.vue'
  import AppsToolbar from './components/AppsToolbar.vue'
  import util from '@/util/util'
  import { buildPolicyHierarchy, getInstalledApps, getInstallableApps } from '@/utils/appFiltering'

  // Constants
  const DEFAULT_POLICY_ID = 1
  const AUTO_INSTALL_POLL_INTERVAL = 1000 // milliseconds (1 second - reasonable backend load)
  const INSTALL_STATUS_FINISHED = 'finish'

  // Session-scoped variables for one-time initialization
  // Matches ExtJS onAfterRender behavior: runs once per session regardless of navigation
  let sessionInitialized = false // Tracks if license reload and auto install monitor have been started
  let autoInstallTimer = null // Polling timer reference persists across component instances

  /**
   * AppsView Component
   *
   * Main view for managing installed and installable applications.
   * Supports policy-based app management with dynamic filtering.
   *
   * Features:
   * - View installed apps for a policy
   * - Install new apps for a policy
   * - Policy hierarchy navigation
   * - Auto-install monitoring with polling
   * - Installation status tracking
   *
   * @component
   */
  export default {
    name: 'AppsView',

    components: {
      InstalledApps,
      InstallableApps,
      AppsToolbar,
    },

    data() {
      return {
        // Toggle between installed apps view and install mode
        installMode: false,
      }
    },

    computed: {
      // ============================================
      // System State Computed Properties
      // ============================================

      /**
       * Check if policy manager is installed
       * @returns {boolean}
       */
      policyManagerInstalled() {
        return !!util.isPolicyManagerInstalled()
      },

      /**
       * Check if system is in restricted mode
       * @returns {boolean}
       */
      isRestricted() {
        return !!util.isRestricted()
      },

      /**
       * Check if system is registered with Untangle
       * @returns {boolean}
       */
      isRegistered() {
        return !!util.isRegistered()
      },

      /**
       * Check if license server is reachable
       * @returns {boolean}
       */
      licenseServerConnectivity() {
        return !!util.getLicenseServerConnectivity()
      },

      /**
       * Determine if install button should be shown
       * Requires: not in install mode, not restricted, registered, and license server connectivity
       * @returns {boolean}
       */
      showInstallButton() {
        return !this.installMode && !this.isRestricted && this.isRegistered && this.licenseServerConnectivity
      },

      // ============================================
      // Vuex Store Computed Properties
      // ============================================

      /**
       * Get policy manager settings from store
       * @returns {Object|null}
       */
      policyManagerSettings: ({ $store }) => $store.getters['apps/getSettings']('policy-manager'),

      /**
       * Get list of all policies
       * @returns {Array<Object>}
       */
      policies: ({ policyManagerSettings }) => (policyManagerSettings ? policyManagerSettings.policies || [] : []),

      /**
       * Get normalized app views by policy ID (O(1) lookup)
       * @returns {Object<number, Object>}
       */
      appViewsByPolicy: ({ $store }) => $store.getters['apps/appViewsByPolicy'],

      /**
       * Get apps currently being installed
       * @returns {Object<string, {policyId: number, status: string}>}
       */
      installingApps: ({ $store }) => $store.getters['apps/installingApps'],

      /**
       * Check if auto install is currently running
       * @returns {boolean}
       */
      autoInstallApps: ({ $store }) => $store.getters['apps/autoInstallApps'],

      // ============================================
      // Route and Policy Computed Properties
      // ============================================

      /**
       * Get current policy ID from route params
       * @returns {number}
       */
      policyId: ({ $route }) => parseInt($route.params.policyId, 10) || DEFAULT_POLICY_ID,

      /**
       * Get currently selected policy object
       * @returns {Object|null}
       */
      selectedPolicy({ policies, policyId }) {
        if (!policies || policies.length === 0) {
          return null
        }
        // Find policy matching the route param, fallback to first policy
        return policies.find(p => p.policyId.toString() === policyId.toString()) || policies[0]
      },

      /**
       * Build hierarchical structure of policies (parent-child relationships)
       * @returns {Array<Object>}
       */
      hierarchicalPolicies({ policies }) {
        return buildPolicyHierarchy(policies)
      },

      // ============================================
      // App Lists Computed Properties
      // ============================================

      /**
       * Get list of installed apps for current policy
       * Includes apps from parent policies (marked as inherited)
       * @returns {Array<Object>}
       */
      installedApps() {
        return getInstalledApps({
          appViewsByPolicy: this.appViewsByPolicy,
          selectedPolicy: this.selectedPolicy,
          policies: this.policies,
          $vuntangle: this.$vuntangle,
          installingApps: this.installingApps,
        })
      },

      /**
       * Get list of installable apps for current policy
       * Filters out already installed apps
       * @returns {Array<Object>}
       */
      installableApps() {
        return getInstallableApps({
          appViewsByPolicy: this.appViewsByPolicy,
          selectedPolicy: this.selectedPolicy,
          installingApps: this.installingApps,
        })
      },
    },

    watch: {
      /**
       * Watch install mode changes to clear installation statuses
       * Clears 'finish' statuses when navigating between views
       */
      installMode(newVal, oldVal) {
        // Clear finished installation statuses when toggling between views
        if (newVal !== oldVal) {
          this.clearFinishedInstallStatuses()
        }
      },

      /**
       * Watch selected policy changes
       * Saves selected policy ID to store for persistence
       */
      selectedPolicy: {
        immediate: true,
        handler(newPolicy) {
          if (newPolicy && newPolicy.policyId) {
            this.$store.commit('apps/SET_SELECTED_POLICY_ID', newPolicy.policyId)
          }
        },
      },

      /**
       * Watch policy ID changes from route
       * Validates policy exists and redirects to default if not found
       */
      policyId: {
        immediate: true,
        handler(newPolicyId) {
          // Only validate after policies are loaded
          if (newPolicyId && this.policies.length > 0) {
            const policyExists = this.policies.find(p => p.policyId === newPolicyId)
            if (!policyExists) {
              // Policy doesn't exist, redirect to default policy
              this.$router.replace(`/apps/${DEFAULT_POLICY_ID}`)
            }
          }
        },
      },
    },

    created() {
      // One-time session initialization - reload licenses (matches ExtJS onAfterRender behavior)
      // Uses module-scoped flag to ensure it only runs on first load, not on policy switches
      if (!sessionInitialized) {
        window.rpc.UvmContext.licenseManager().reloadLicenses(true)
      }

      // Load policy manager settings
      this.$store.dispatch('apps/loadAppData', 'policy-manager')

      // Load app views for all policies
      this.$store.dispatch('apps/getAppViews', false)

      // Load app view for current policy
      this.$store.dispatch('apps/getAppView', this.policyId)
    },

    mounted() {
      // One-time session initialization - start auto-install monitor (matches ExtJS onAfterRender behavior)
      // Runs after app views are loaded, uses module-scoped flag to prevent restart on navigation
      // Monitor persists across component lifecycle and stops when auto install completes
      if (!sessionInitialized) {
        this.startAutoInstallMonitor()
        sessionInitialized = true
      }
    },

    methods: {
      /**
       * Handle policy change from toolbar dropdown
       * @param {number} policyId - Selected policy ID
       */
      onPolicyChange(policyId) {
        const changedPolicy = this.policies.find(p => p.policyId === policyId)
        if (changedPolicy) {
          this.$router.push(`/apps/${changedPolicy.policyId}`)
        }
      },

      /**
       * Navigate to policy management settings
       */
      managePolicies() {
        this.$router.push('/settings/services/dynamic-blocklist')
      },

      /**
       * Enter install mode to show installable apps
       */
      installApps() {
        this.installMode = true
      },

      /**
       * Exit install mode and return to installed apps view
       */
      backToPolicy() {
        this.installMode = false
      },

      /**
       * Clear installation statuses for apps that have finished installing
       * Only clears apps with 'finish' status, preserves 'progress' status
       */
      clearFinishedInstallStatuses() {
        const installingApps = this.installingApps

        Object.keys(installingApps).forEach(appName => {
          if (installingApps[appName].status === INSTALL_STATUS_FINISHED) {
            this.$store.commit('apps/SET_APP_INSTALL_STATUS', {
              appName,
              policyId: installingApps[appName].policyId,
              status: null, // Clear status
            })
          }
        })
      },

      /**
       * Start monitoring auto-install status
       * Polls backend flag and refreshes app views while auto-installing
       * Follows ExtJS pattern: poll flag + refresh views
       * Runs once per session and persists across component instances
       */
      startAutoInstallMonitor() {
        // Initial check of auto-install flag
        this.$store.dispatch('apps/checkAutoInstallFlag')

        // Set up polling interval (persists across component lifecycle)
        autoInstallTimer = setInterval(() => {
          // Check if auto install is still running (updates store state)
          this.$store.dispatch('apps/checkAutoInstallFlag')

          // Check the store state (not dispatch return value) to decide next action
          if (this.$store.getters['apps/autoInstallApps']) {
            // While auto-installing, refresh app views to show newly installed apps
            // This mirrors ExtJS behavior: me.getApps() during polling
            this.$store.dispatch('apps/getAppView', this.$route.params.policyId || DEFAULT_POLICY_ID)
          } else if (autoInstallTimer) {
            // Auto install completed - stop monitoring
            clearInterval(autoInstallTimer)
            autoInstallTimer = null
          }
        }, AUTO_INSTALL_POLL_INTERVAL)
      },
    },
  }
</script>

<style lang="scss" scoped>
  .apps-view {
    display: flex;
    flex-direction: column;
    flex-grow: 1;
    padding-left: 0.75rem;
    padding-top: 0.5rem;

    &__content {
      display: flex;
      flex-direction: column;
      height: 100%;
    }

    &__title {
      font-size: 1.5rem;
      font-weight: 400;
      margin-bottom: 0.5rem;
      margin-top: 1.25rem;
    }

    &__divider {
      margin-top: 0.5rem;
      margin-bottom: 0.5rem;
      padding-top: 0.5rem;
    }
  }
</style>
