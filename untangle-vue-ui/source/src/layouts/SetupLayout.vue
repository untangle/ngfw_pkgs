<template>
  <div>
    <v-app-bar app dark flat height="120" class="ut-app-bar">
      <v-spacer />
      <div class="d-flex flex-column">
        <div class="d-flex flex-column align-center mb-2">
          <v-img :src="require('@/assets/arista-logo-white.svg')" contain width="240" height="40" transition="false" />
        </div>
        <div v-if="status" class="d-flex flex-row">
          <div v-for="(step, idx) in stepper" :key="idx">
            <v-btn small text class="mx-2" :disabled="status.completed || stepper.indexOf(currentStep) < idx">
              {{ $t(step) }}
            </v-btn>
            <v-icon v-if="idx < stepper.length - 1" small :disabled="stepper.indexOf(currentStep) <= idx">
              mdi-chevron-right
            </v-icon>
          </div>
        </div>
      </div>
      <v-spacer />
    </v-app-bar>
    <v-overlay v-model="$store.state.pageLoad">
      <v-progress-circular indeterminate size="32" />
    </v-overlay>
    <u-framework-toast />
  </div>
</template>

<script>
  import { mapGetters } from 'vuex'

  export default {
    computed: {
      ...mapGetters('setup', ['stepper', 'previousStep']), // Map the stepper and previousStep getters
      currentStep() {
        // If previousStep exists, determine the next step; otherwise, default to the first step in stepper
        const previousStepIndex = this.stepper.indexOf(this.previousStep)
        if (previousStepIndex >= 0 && previousStepIndex < this.stepper.length) {
          return this.stepper[previousStepIndex]
        }
        return this.stepper[0] // Default to the first step if no previousStep or invalid index
      },
      status() {
        return { completed: false } // Example status
      },
    },
    mounted() {
      console.log('Stepper from Vuex Store:', this.stepper) // Debugging log
      console.log('Previous Step from Vuex Store:', this.previousStep) // Debugging log
      console.log('Calculated Current Step:', this.currentStep) // Debugging log
    },
  }
</script>
