<template>
  <div>
    <!-- Dynamically render components based on currentStep -->
    <component :is="currentStepComponent" />
  </div>
</template>

<script>
  import { mapGetters, mapActions } from 'vuex'
  import License from '@/components/setup/License.vue' // Import License component
  import System from '@/components/setup/System.vue' // Import System component
  import SetupLayout from '@/layouts/SetupLayout.vue' // Import Layout component
  import SetupSelect from '@/components/setup/SetupSelect.vue' // Import System component

  export default {
    name: 'Wizard',
    components: {
      License,
      System,
      SetupLayout,
      SetupSelect,
    },
    computed: {
      ...mapGetters('setup', ['currentStep']), // Get currentStep from Vuex
      // Dynamically choose the component based on currentStep
      currentStepComponent() {
        switch (this.currentStep) {
          case 'License':
            return License
          case 'System':
            return System
          case 'Wizard':
            return SetupSelect
          default:
            return SetupSelect
        }
      },
    },
    methods: {
      ...mapActions('setup', ['setShowStep']), // Map Vuex action to change step

      async onContinue() {
        try {
          // Change the step to 'System' and render the System component
          await this.setShowStep('System')
        } catch (error) {
          console.error('Failed to navigate to System step:', error)
        }
      },

      async onClickDisagree() {
        try {
          // If 'Disagree' is clicked, move to the 'Wizard' step
          await this.setShowStep('Wizard')
        } catch (error) {
          console.error('Failed to navigate to Wizard step:', error)
        }
      },
    },
  }
</script>

<style scoped>
  /* Add custom styles here */
</style>
