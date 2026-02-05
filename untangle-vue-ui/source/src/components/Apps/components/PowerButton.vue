<template>
  <div v-if="hasPowerButton" class="power-button-wrapper">
    <span class="power-button" :class="`power-button--${powerCls}`">
      <v-icon small class="power-button__icon">mdi-power</v-icon>
    </span>
  </div>
</template>

<script>
  /**
   * PowerButton Component
   *
   * Displays a power status indicator badge for apps.
   * Shows different colors based on app power state.
   *
   * Power States:
   * - on: Green - App is running
   * - off: Gray - App is stopped
   * - powering: Orange - App is transitioning (starting/stopping)
   * - inconsistent: Red - App is in an inconsistent state
   *
   * @component
   */
  export default {
    name: 'PowerButton',

    props: {
      /**
       * Power state CSS class
       * Determines the badge color
       * @type {string}
       * @values 'on' | 'off' | 'powering' | 'inconsistent'
       */
      powerCls: {
        type: String,
        default: 'off',
      },

      /**
       * Whether to show the power button
       * Hides the button entirely if false
       * @type {boolean}
       */
      hasPowerButton: {
        type: Boolean,
        default: true,
      },
    },
  }
</script>

<style lang="scss" scoped>
  // Color constants for power states
  $power-state-on: #69be4d; // Green - running
  $power-state-off: #858585; // Gray - stopped
  $power-state-powering: #ff9800; // Orange - transitioning
  $power-state-inconsistent: #ff6347; // Tomato Red - error state
  $icon-color: #fff;

  // Size constants
  $button-size: 20px;
  $icon-size: 14px;

  .power-button-wrapper {
    position: absolute;
    top: 0;
    right: 0;
    z-index: 2;
  }

  .power-button {
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    width: $button-size;
    height: $button-size;
    border-radius: 50%;
    transform: translate(25%, -25%);
    transition: background-color 0.3s ease;

    // Default background (gray/off state)
    background-color: $power-state-off;

    // ============================================
    // Power State Colors
    // ============================================

    // Running state - green
    &--on {
      background-color: $power-state-on;
    }

    // Stopped state - gray (explicit override for off state)
    &--off {
      background-color: $power-state-off;
    }

    // Transitioning state - orange (starting or stopping)
    &--powering {
      background-color: $power-state-powering;
    }

    // Inconsistent/Error state - red
    &--inconsistent {
      background-color: $power-state-inconsistent;
    }

    // ============================================
    // Icon Styles
    // ============================================

    &__icon {
      color: $icon-color !important;
      font-size: $icon-size !important;
    }
  }
</style>
