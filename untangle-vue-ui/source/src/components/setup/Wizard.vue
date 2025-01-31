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
  import Network from '@/components/setup/Network.vue'
  import Internet from '@/components/setup/Internet.vue'

  export default {
    name: 'Wizard',
    components: {
      License,
      System,
      SetupLayout,
      SetupSelect,
      Internet,
    },
    computed: {
      ...mapGetters('setup', ['currentStep']), // Get currentStep from Vuex
      // Dynamically choose the component based on currentStep
      currentStepComponent() {
        switch (this.currentStep) {
          case 'Wizard':
            return SetupSelect
          case 'License':
            return License
          case 'System':
            return System
          case 'Network':
            return Network
          case 'Internet':
            return Internet
          default:
            return SetupSelect
        }
      },
    },
    async beforeMount() {
      // If the page is refreshed, force set currentStep to 'Wizard'
      if (
        this.currentStep === 'License' ||
        this.currentStep === 'System' ||
        this.currentStep === 'Network' ||
        this.currentStep === 'Internet'
      ) {
        await this.setShowStep('Wizard') // Reset step to 'Wizard'
      }
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
