<template>
  <!-- Grid container for installable apps -->
  <div class="installable-apps">
    <!-- Installable App Card -->
    <v-card
      v-for="(app, key) in apps"
      :key="key"
      :elevation="hoveredApp === key ? 2 : 0"
      :outlined="hoveredApp === key"
      class="installable-apps__card"
      :class="getAppStatusClass(app.name)"
      @mouseover="hoveredApp = key"
      @mouseleave="hoveredApp = null"
    >
      <div class="installable-apps__card-content">
        <!-- Icon Section -->
        <div class="installable-apps__icon-section">
          <v-hover v-slot="{ hover }">
            <div
              class="installable-apps__icon-wrapper"
              :class="{ 'installable-apps__icon-wrapper--clickable': !isAppInstalling(app.name) }"
              @click="handleAppClick(app)"
            >
              <!-- App Icon -->
              <div class="installable-apps__icon-container">
                <img
                  :src="require(`@/assets/icons/apps/${app.name}.svg`)"
                  class="installable-apps__icon"
                  :class="{
                    'installable-apps__icon--blurred': hover && !getAppStatus(app.name),
                    'installable-apps__icon--dimmed': isAppInstalling(app.name) || isAppFinished(app.name),
                    'installable-apps__icon--hover': hover && !getAppStatus(app.name),
                  }"
                  :alt="`${app.displayName} icon`"
                />

                <!-- Progress Loader -->
                <span v-if="isAppInstalling(app.name)" class="installable-apps__loader" />
              </div>

              <!-- Download Icon (shown on hover when app is not being installed) -->
              <v-icon
                v-if="hover && !getAppStatus(app.name)"
                class="installable-apps__action-icon"
                size="52"
                color="black"
              >
                mdi-download
              </v-icon>

              <!-- Success Check Icon (shown when installation is finished) -->
              <v-icon v-if="isAppFinished(app.name)" class="installable-apps__action-icon" size="52" color="success">
                mdi-check-bold
              </v-icon>
            </div>
          </v-hover>
        </div>

        <!-- Text Content Section -->
        <div class="installable-apps__text-section">
          <!-- App Title -->
          <v-card-title class="installable-apps__title" :class="titleColorClass">
            <div class="d-flex flex-column">
              <span class="font-weight-medium text-left">
                {{ $vuntangle.$t(app.displayName) }}
              </span>
            </div>
          </v-card-title>

          <!-- App Description -->
          <v-card-text class="installable-apps__description">
            <span class="caption text-left text-justify">
              {{ $vuntangle.$t(app.description) }}
            </span>
          </v-card-text>
        </div>
      </div>
    </v-card>
  </div>
</template>

<script>
  import { mapGetters } from 'vuex'
  import util from '@/util/util'

  // Constants
  const INSTALL_STATUS = {
    PROGRESS: 'progress',
    FINISH: 'finish',
  }

  /**
   * InstallableApps Component
   *
   * Container component that displays a grid of apps available for installation.
   * Shows installation progress and success states with visual feedback.
   *
   * Features:
   * - Responsive card grid layout
   * - Hover effects with download icon
   * - Installation progress indicator
   * - Success state with check icon
   * - Click to install functionality
   * - Disabled state during installation
   *
   * @component
   */
  export default {
    name: 'InstallableApps',

    props: {
      /**
       * Array of installable app objects
       * @type {Array<Object>}
       */
      apps: {
        type: Array,
        required: true,
        default: () => [],
      },

      /**
       * Policy ID for which apps can be installed
       * @type {number}
       */
      policyId: {
        type: Number,
        required: true,
      },
    },

    data() {
      return {
        // Track which app card is currently being hovered
        hoveredApp: null,
      }
    },

    computed: {
      /**
       * Map Vuex getters for installing apps
       */
      ...mapGetters('apps', ['installingApps']),

      /**
       * Get CSS class for title color based on theme
       * @returns {string}
       */
      titleColorClass() {
        return `py-0 subtitle-1 ${this.$vuntangle.theme === 'dark' ? '' : 'primary--text'}`
      },
    },

    methods: {
      /**
       * Handle app card click - initiate installation
       * @param {Object} app - App object to install
       */
      async handleAppClick(app) {
        // Check if user is registered or if CC is hidden
        if (!util.isRegistered() && !util.isCCHidden()) {
          return
        }
        // Don't allow installation if app is already being installed
        if (this.isAppInstalling(app.name)) {
          return
        }

        // Dispatch install action
        await this.$store.dispatch('apps/installApp', {
          appName: app.name,
          policyId: this.policyId,
        })
      },

      /**
       * Get installation status for an app
       * @param {string} appName - Name of the app
       * @returns {string|null} Status ('progress', 'finish') or null
       */
      getAppStatus(appName) {
        const installing = this.installingApps[appName]
        return installing ? installing.status : null
      },

      /**
       * Check if app is currently being installed
       * @param {string} appName - Name of the app
       * @returns {boolean}
       */
      isAppInstalling(appName) {
        return this.getAppStatus(appName) === INSTALL_STATUS.PROGRESS
      },

      /**
       * Check if app installation has finished
       * @param {string} appName - Name of the app
       * @returns {boolean}
       */
      isAppFinished(appName) {
        return this.getAppStatus(appName) === INSTALL_STATUS.FINISH
      },

      /**
       * Get CSS class based on app installation status
       * @param {string} appName - Name of the app
       * @returns {string} CSS class name
       */
      getAppStatusClass(appName) {
        const status = this.getAppStatus(appName)
        if (status === INSTALL_STATUS.PROGRESS) return 'installable-apps__card--installing'
        if (status === INSTALL_STATUS.FINISH) return 'installable-apps__card--finished'
        return ''
      },
    },
  }
</script>

<style lang="scss" scoped>
  @import '@/scss/common.scss';

  // Component-specific sizes
  $card-height: 150px;
  $card-flex-basis: 24%;
  $icon-section-width: 120px;

  .installable-apps {
    // Using common grid mixin from common.scss
    @include app-grid-container($app-card-gap);

    // ============================================
    // Card Styles
    // ============================================

    &__card {
      position: relative;
      flex-basis: $card-flex-basis;
      min-width: 0; // Prevent overflow
      min-height: $card-height; // Allow cards to grow dynamically
      transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);

      // Responsive breakpoints for proper alignment
      @media (max-width: 1400px) {
        flex-basis: calc(33.333% - #{$app-card-gap}); // 3 cards per row
      }

      @media (max-width: 1024px) {
        flex-basis: calc(50% - #{$app-card-gap}); // 2 cards per row
      }

      @media (max-width: 768px) {
        flex-basis: 100%; // 1 card per row
      }

      // Installing state - dimmed and non-interactive
      &--installing {
        opacity: 0.8;
        pointer-events: none;
      }

      // Finished state - success background color
      &--finished {
        background-color: $app-success-bg;
      }
    }

    &__card-content {
      display: flex;
      align-items: center;
      height: 100%;
    }

    // ============================================
    // Icon Section
    // ============================================

    &__icon-section {
      width: $icon-section-width;
      flex-shrink: 0;
    }

    &__icon-wrapper {
      position: relative;
      text-align: center;
      padding: 0.5rem;

      &--clickable {
        cursor: pointer;
      }
    }

    &__icon-container {
      position: relative;
      display: inline-block;
    }

    &__icon {
      width: $app-icon-size-small;
      height: $app-icon-size-small;
      transition: filter 0.2s ease, opacity 0.2s ease;

      // Hover states (using common pattern)
      &--blurred {
        filter: blur(2px);
      }

      &--dimmed {
        opacity: 0.1;
      }

      &--hover {
        opacity: 0.6;
      }
    }

    // Action icons (download, check) - using common absolute-center pattern
    &__action-icon {
      @include absolute-center;
      pointer-events: none;
    }

    // ============================================
    // Progress Loader
    // ============================================

    &__loader {
      // Using common loader mixin from common.scss
      @include app-loader($app-icon-size-small, $app-loader-spinner-size);
      // Component-specific positioning
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      margin: 0 auto;
      transform: none; // Remove centering transform
    }

    // ============================================
    // Text Section
    // ============================================

    &__text-section {
      flex: 1;
      min-width: 0; // Prevent flex overflow
      display: flex;
      flex-direction: column;
    }

    &__title {
      padding-top: 0;
      padding-bottom: 0;
      font-size: 0.875rem;
      word-break: break-word;
    }

    &__description {
      line-height: 1.2 !important;
      word-break: break-word;
    }
  }

  // ============================================
  // Animations
  // ============================================

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
</style>
