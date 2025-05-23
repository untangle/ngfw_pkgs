<template>
  <div>
    <v-app-bar app dark flat height="120" class="ut-app-bar">
      <v-spacer />
      <div class="d-flex flex-column">
        <div class="d-flex flex-column align-center mb-2">
          <v-img :src="require('@/assets/arista-logo-white.svg')" contain width="240" height="40" transition="false" />
        </div>

        <!-- Step Wizard -->
        <div v-if="status" class="d-flex flex-nowrap align-center px-2 text-no-wrap" style="overflow-x: auto">
          <div v-for="(step, idx) in wizardSteps" :key="idx" class="d-flex align-center">
            <span
              class="text-white font-weight-medium text-uppercase px-2 d-inline-block text-center"
              :class="{
                'opacity-4 pointer-events-none cursor-default':
                  status.completed || wizardSteps.indexOf(currentStep) < idx,
              }"
            >
              {{ $t(getStepLabel(step)) }}
            </span>
            <v-icon
              v-if="idx < wizardSteps.length - 1"
              small
              class="text-white"
              :class="{
                'opacity-4 pointer-events-none cursor-default': wizardSteps.indexOf(currentStep) <= idx,
              }"
            >
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
      ...mapGetters('setup', ['stepper', 'previousStep', 'wizardSteps']),
      currentStep() {
        const previousStepIndex = this.wizardSteps.indexOf(this.previousStep)
        if (previousStepIndex >= 0 && previousStepIndex < this.wizardSteps.length) {
          return this.wizardSteps[previousStepIndex]
        }
        return this.stepper[0]
      },
      status() {
        return { completed: false }
      },
    },

    methods: {
      getStepLabel(step) {
        const customLabels = {
          ServerSettings: 'Settings',
          InternalNetwork: 'Network',
        }
        return customLabels[step] || step
      },
    },
  }
</script>

<style scoped>
  .opacity-4 {
    opacity: 0.4 !important;
  }
  .pointer-events-none {
    pointer-events: none !important;
  }
  .cursor-default {
    cursor: default !important;
  }
</style>
