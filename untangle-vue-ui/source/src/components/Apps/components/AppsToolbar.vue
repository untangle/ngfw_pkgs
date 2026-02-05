<template>
  <div class="apps-toolbar">
    <!-- Policy Selector (shown in normal mode when policy manager is installed) -->
    <v-menu v-if="showPolicySelector" offset-y content-class="apps-toolbar__policy-menu">
      <template #activator="{ on }">
        <u-btn color="primary" v-on="on">
          <v-icon small class="mr-2">mdi-file-document-outline</v-icon>
          {{ selectedPolicy.name }}
          <v-icon small class="ml-2">mdi-chevron-down</v-icon>
        </u-btn>
      </template>

      <!-- Hierarchical Policy Tree -->
      <v-treeview
        :items="hierarchicalPolicies"
        item-key="policyId"
        item-text="name"
        activatable
        hoverable
        dense
        open-all
        @update:active="onPolicyChange"
      />
    </v-menu>

    <!-- Install Apps Button (shown when conditions are met) -->
    <u-btn v-if="showInstallButton" color="primary" class="ml-2" @click="handleInstallAppsClick">
      <v-icon small class="mr-2">mdi-plus</v-icon>
      {{ $vuntangle.$t('install_apps') }}
    </u-btn>

    <!-- Back Button (shown in install mode) -->
    <u-btn v-if="installMode" color="primary" @click="handleBackClick">
      <v-icon small class="mr-2">mdi-arrow-left</v-icon>
      {{ $vuntangle.$t('back_to_apps') }} [{{ selectedPolicy.name }}]
    </u-btn>

    <!-- Auto Install Status Message -->
    <p v-if="autoInstallApps" class="apps-toolbar__message">
      {{ $vuntangle.$t('installing_recommended_apps') }}
    </p>

    <!-- Install Mode Context Message -->
    <p v-if="showInstallModeMessage" class="apps-toolbar__message">
      {{ $vuntangle.$t('available_apps_for') }}
      <span>
        <v-icon small class="apps-toolbar__message-icon">mdi-file-document-outline</v-icon>
        <strong>{{ selectedPolicy.name }}</strong>
      </span>
    </p>

    <!-- Spacer to push right-side buttons to the end -->
    <v-spacer />

    <!-- Manage Policies Button (shown in normal mode when policy manager is installed) -->
    <u-btn v-if="showManagePoliciesButton" color="primary" class="ml-2" @click="handleManagePoliciesClick">
      <v-icon small class="mr-2">mdi-cog</v-icon>
      {{ $vuntangle.$t('manage_policies') }}
    </u-btn>

    <!-- Refresh Button (always shown to refresh app views from backend) -->
    <u-btn class="ml-2" @click="handleRefreshClick">
      <v-icon small>mdi-refresh</v-icon>
      {{ $vuntangle.$t('refresh') }}
    </u-btn>
  </div>
</template>

<script>
  /**
   * AppsToolbar Component
   *
   * Toolbar for the Apps view with policy selection and action buttons.
   * Displays different UI elements based on current mode and system state.
   *
   * Features:
   * - Policy selector dropdown with hierarchical tree
   * - Install mode toggle
   * - Manage policies navigation
   * - Auto-install status indicator
   * - Contextual messaging
   *
   * @component
   */
  export default {
    name: 'AppsToolbar',

    props: {
      /**
       * Whether Policy Manager app is installed
       * @type {boolean}
       */
      policyManagerInstalled: {
        type: Boolean,
        required: true,
      },

      /**
       * Whether currently in install mode (viewing installable apps)
       * @type {boolean}
       */
      installMode: {
        type: Boolean,
        required: true,
      },

      /**
       * Currently selected policy object
       * @type {Object}
       * @property {number} policyId - Policy ID
       * @property {string} name - Policy name
       */
      selectedPolicy: {
        type: Object,
        required: true,
        validator: policy => {
          return policy && policy.policyId && policy.name
        },
      },

      /**
       * Hierarchical list of policies (with parent-child relationships)
       * @type {Array<Object>}
       */
      hierarchicalPolicies: {
        type: Array,
        required: true,
        default: () => [],
      },

      /**
       * Whether auto-install is currently running
       * @type {boolean}
       */
      autoInstallApps: {
        type: Boolean,
        default: false,
      },

      /**
       * Whether to show the Install Apps button
       * Based on system state (registration, license connectivity, etc.)
       * @type {boolean}
       */
      showInstallButton: {
        type: Boolean,
        default: false,
      },
    },

    emits: [
      /**
       * Emitted when user selects a different policy
       * @param {number} policyId - Selected policy ID
       */
      'policy-change',

      /**
       * Emitted when user clicks Manage Policies button
       */
      'manage-policies',

      /**
       * Emitted when user clicks Install Apps button
       */
      'install-apps',

      /**
       * Emitted when user clicks Back button in install mode
       */
      'back-to-policy',

      /**
       * Emitted when user clicks Refresh button
       * Triggers refresh of app views from backend
       */
      'refresh',
    ],

    computed: {
      /**
       * Show policy selector dropdown
       * Only shown in normal mode when policy manager is installed
       * @returns {boolean}
       */
      showPolicySelector() {
        return this.policyManagerInstalled && !this.installMode
      },

      /**
       * Show manage policies button
       * Only shown in normal mode when policy manager is installed
       * @returns {boolean}
       */
      showManagePoliciesButton() {
        return this.policyManagerInstalled && !this.installMode
      },

      /**
       * Show install mode context message
       * Shows which policy the user is installing apps for
       * @returns {boolean}
       */
      showInstallModeMessage() {
        return this.policyManagerInstalled && this.installMode
      },
    },

    methods: {
      /**
       * Handle policy selection change from tree
       * @param {Array<number>} active - Array of selected policy IDs
       */
      onPolicyChange(active) {
        // Tree emits array of selected items, we only care about the first one
        if (active && active.length > 0) {
          this.$emit('policy-change', active[0])
        }
      },

      /**
       * Handle manage policies button click
       * Emits event for parent to navigate to policy management
       */
      handleManagePoliciesClick() {
        this.$emit('manage-policies')
      },

      /**
       * Handle install apps button click
       * Emits event to enter install mode
       */
      handleInstallAppsClick() {
        this.$emit('install-apps')
      },

      /**
       * Handle back button click in install mode
       * Emits event to return to installed apps view
       */
      handleBackClick() {
        this.$emit('back-to-policy')
      },

      /**
       * Handle refresh button click
       * Emits event to trigger refresh of app views from backend
       */
      handleRefreshClick() {
        this.$emit('refresh')
      },
    },
  }
</script>

<style lang="scss" scoped>
  .apps-toolbar {
    display: flex;
    align-items: center;
    margin-bottom: 0.5rem;

    // ============================================
    // Messages (status and context)
    // ============================================

    &__message {
      margin-bottom: 0;
      margin-left: 0.75rem;
      font-size: 0.875rem; // body-3 equivalent
      line-height: 1.5;
    }

    &__message-icon {
      margin-bottom: 0.25rem;
      margin-right: 0.25rem;
    }

    // ============================================
    // Policy Menu Dropdown
    // ============================================

    &__policy-menu {
      background-color: #fff;
      z-index: 1;
    }
  }
</style>
