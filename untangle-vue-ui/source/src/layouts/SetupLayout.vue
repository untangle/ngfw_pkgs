<template>
  <!-- <v-app> -->
  <div>
    <v-app-bar app dark flat height="120" class="ut-app-bar">
      <v-spacer />
      <div class="d-flex flex-column">
        <div class="d-flex flex-column align-center mb-2">
          <v-img :src="require('@/assets/arista-logo-white.svg')" contain width="240" height="40" transition="false" />
        </div>
        <div v-if="status" class="d-flex flex-row">
          <div v-for="(step, idx) in steps" :key="idx">
            <v-btn
              small
              text
              :to="`/setup/${step}`"
              class="mx-2"
              :disabled="status.completed || steps.indexOf(currentStep) < idx"
              rounded
            >
              <!-- steps: 'license', 'system', 'wan', 'lte', 'wifi' -->
              {{ $t(step) }}
            </v-btn>
            <v-icon small :disabled="steps.indexOf(currentStep) <= idx"> mdi-chevron-right </v-icon>
          </div>
        </div>
      </div>
      <v-spacer />
    </v-app-bar>
    <!-- 
    <v-main>
      <router-view />
    </v-main> -->
    <v-overlay v-model="$store.state.pageLoad">
      <v-progress-circular indeterminate size="32" />
    </v-overlay>
    <u-framework-toast />
    <!-- </v-app> -->
  </div>
</template>

<script>
  // import store from '@/store'

  export default {
    computed: {
      steps() {
        // return store.getters['setup/steps']
        return ['license', 'system', 'network', 'internet', 'interface', 'autoupgrades', 'complete']
      },

      status() {
        // return store.getters['settings/setupWizard']
        return {
          'completed': true,
        }
      },
      currentStep() {
        return this.status?.step || this.steps[0]
      },
    },
    mounted() {
      // console.log('Steps:', this.steps)
      // console.log('status:', this.status)
    },
  }
</script>
