<template>
  <v-card
    :elevation="cardElevation"
    :outlined="hovered"
    class="app-card"
    :class="cardClasses"
    :disabled="isDisabled"
    @mouseover="hovered = true"
    @mouseleave="hovered = false"
    @click="handleCardClick"
  >
    <v-card-text class="app-card__content">
      <!-- License Message (top badge) -->
      <div v-if="app.licenseMessage" class="app-card__license-wrapper">
        <span class="app-card__license">{{ app.licenseMessage }}</span>
      </div>

      <!-- Icon Section -->
      <div class="app-card__icon-wrapper">
        <!-- Power Button (top-right badge) -->
        <PowerButton :power-cls="app.powerCls" :has-power-button="app.hasPowerButton" />

        <!-- App Icon -->
        <img
          :src="require(`@/assets/icons/apps/${app.appName}.svg`)"
          class="app-card__icon"
          :alt="`${app.displayName} icon`"
        />

        <!-- Installing Loader -->
        <span v-if="app.installing" class="app-card__loader" />
      </div>

      <!-- App Info Section -->
      <div class="app-card__info">
        <!-- App Display Name -->
        <span class="app-card__name" :class="{ 'app-card__name--clickable': isClickable }">
          {{ $vuntangle.$t(app.displayName) }}
        </span>

        <!-- Parent Policy Badge (if inherited from parent) -->
        <span v-if="app.parentPolicy" class="app-card__parent-policy"> [{{ app.parentPolicy }}] </span>
      </div>
    </v-card-text>
  </v-card>
</template>

<script>
  import PowerButton from './PowerButton.vue'

  /**
   * AppCard Component
   *
   * Displays an individual installed app as a card with icon, name, and status.
   * Supports different states: normal, installing, and inherited from parent policy.
   *
   * Features:
   * - Click to navigate to app settings
   * - Power button indicator
   * - License message badge
   * - Installing state with loader
   * - Inherited app state (grayed out)
   * - Hover effects
   *
   * @component
   */
  export default {
    name: 'AppCard',

    components: {
      PowerButton,
    },

    props: {
      /**
       * App object containing all app information
       * @type {Object}
       * @property {string} appName - Internal app name (kebab-case)
       * @property {string} displayName - Display name for UI
       * @property {string} [licenseMessage] - License status message
       * @property {string} [powerCls] - Power state CSS class
       * @property {boolean} [hasPowerButton] - Whether to show power button
       * @property {boolean} [installing] - Whether app is currently installing
       * @property {string} [parentPolicy] - Parent policy name if inherited
       */
      app: {
        type: Object,
        required: true,
        validator: app => {
          return app.appName && app.displayName
        },
      },
    },

    data() {
      return {
        // Track hover state for elevation effect
        hovered: false,
      }
    },

    computed: {
      /**
       * Card elevation based on hover state
       * @returns {number}
       */
      cardElevation() {
        return this.hovered ? 2 : 0
      },

      /**
       * Dynamic CSS classes for card state
       * @returns {Object}
       */
      cardClasses() {
        return {
          'app-card--from-parent': !!this.app.parentPolicy,
          'app-card--installing': !!this.app.installing,
        }
      },

      /**
       * Check if card should be disabled (non-clickable)
       * Disabled if inherited from parent or currently installing
       * @returns {boolean}
       */
      isDisabled() {
        return !!this.app.parentPolicy || !!this.app.installing
      },

      /**
       * Check if card is clickable
       * @returns {boolean}
       */
      isClickable() {
        return !this.app.parentPolicy && !this.app.installing
      },
    },

    methods: {
      /**
       * Handle card click - navigate to app settings
       * Only navigates if app is clickable (not from parent, not installing)
       */
      handleCardClick() {
        if (this.isClickable) {
          this.goToApp(this.app)
        }
      },

      /**
       * Navigate to app settings page
       * @param {Object} app - App object
       */
      goToApp(app) {
        const policyId = this.$route.params.policyId
        this.$router.push(`/apps/${policyId}/${app.appName}`)
      },
    },
  }
</script>

<style lang="scss" scoped>
  // Color constants
  $card-bg-hover: #f5f5f5;
  $license-color: #f44336; // Red
  $parent-badge-color: #000;
  $loader-bg-color: rgba(0, 0, 0, 0.1);
  $loader-border-color: $arista-blue;

  // Size constants
  $card-width: 150px;
  $card-height: 170px;
  $icon-size: 90px;
  $loader-size: 30px;

  .app-card {
    position: relative;
    width: $card-width;
    height: $card-height;
    flex-basis: 10%;
    transition: background-color 0.2s ease;
    display: flex;
    flex-direction: column;

    // Hover effect
    &:hover:not(.app-card--from-parent):not(.app-card--installing) {
      background-color: $card-bg-hover;
    }

    // ============================================
    // Card Content
    // ============================================

    &__content {
      padding-bottom: 0;
      text-align: center;
    }

    // ============================================
    // License Badge
    // ============================================

    &__license-wrapper {
      position: absolute;
      top: 2px;
      left: 2px;
      right: 2px;
      z-index: 1;
    }

    &__license {
      display: block;
      padding: 2px 5px;
      font-size: 0.6875rem; // 11px
      font-weight: 700;
      color: $license-color;
      text-align: center;
    }

    // ============================================
    // Icon Section
    // ============================================

    &__icon-wrapper {
      position: relative;
      display: inline-block;
      margin-top: 0.9375rem; // 15px
    }

    &__icon {
      width: $icon-size;
      height: $icon-size;
      transition: opacity 0.2s ease, filter 0.2s ease;
    }

    // ============================================
    // Installing Loader
    // ============================================

    &__loader {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      display: block;
      width: $icon-size;
      height: $icon-size;
      margin: 0 auto;
      background-color: $loader-bg-color;
      border-radius: 4px;

      // Spinning animation
      &::after {
        content: '';
        position: absolute;
        top: 50%;
        left: 50%;
        width: $loader-size;
        height: $loader-size;
        margin-top: -($loader-size / 2);
        margin-left: -($loader-size / 2);
        border: 3px solid white;
        border-top-color: $loader-border-color;
        border-radius: 50%;
        animation: spin 1s linear infinite;
      }
    }

    // ============================================
    // App Info Section
    // ============================================

    &__info {
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
    }

    &__name {
      font-size: 0.75rem; // 12px
      font-weight: 700;
      line-height: 1.2;
      color: $parent-badge-color !important;
      word-break: keep-all;
      cursor: default;

      &--clickable {
        cursor: pointer;
      }
    }

    &__parent-policy {
      margin-top: -0.25rem; // -4px
      font-size: 0.75rem; // 12px
      color: $parent-badge-color !important;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      max-width: 100%;
    }

    // ============================================
    // State Modifiers
    // ============================================

    // Installing state - hide power button, show loader, dim icon
    &--installing {
      :deep(.power-button-wrapper) {
        display: none;
      }

      .app-card__loader {
        display: block;
      }

      .app-card__icon {
        opacity: 0.1;
      }
    }

    // Inherited from parent - grayscale and dimmed
    &--from-parent {
      :deep(.power-button-wrapper) {
        opacity: 0.8;
      }

      .app-card__icon {
        filter: grayscale(1);
        opacity: 0.2;
      }
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
