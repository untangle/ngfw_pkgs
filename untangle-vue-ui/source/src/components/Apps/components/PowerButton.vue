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
  // All power button styles are now in common.scss
  // No component-specific styles needed - using global .power-button classes
</style>
