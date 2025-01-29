<template>
  <div>
    <div>
      <SetupLayout />
      <v-container class="text-center" style="max-width: 600px">
        <h1 class="d-flex font-weight-light text-center faint-color">
          License
          <v-spacer />
        </h1>
        <br />
        <p>{{ $t('setup_review_license') }}</p>

        <p :style="paragraphStyle">
          {{ $t('setup_license_available_at') }} <a :href="remoteEulaSrc" target="_blank">{{ remoteEulaSrc }}</a>
        </p>
        <p>
          <b>{{ $t('setup_legal_links_available_at') }}</b>
        </p>

        <div class="button-container">
          <u-btn :small="false" style="margin: 8px 0" @click="onClickDisagree">Disagree</u-btn>
          <u-btn :small="false" style="margin: 8px 0" @click="onContinue">Agree</u-btn>
        </div>
      </v-container>
    </div>
  </div>
</template>

<script>
  import { mapGetters, mapActions } from 'vuex' // Import mapGetters to map currentStep
  import uris from '@/util/uris'
  import SetupLayout from '@/layouts/SetupLayout.vue'
  // import System from '@/components/setup/System.vue'
  // import Wizard from '@/components/setup/Wizard.vue'

  export default {
    name: 'License',
    components: {
      SetupLayout,
      // System,
      // Wizard,
    },
    data: () => ({
      remoteEulaSrc: null,
      eulaSrc: null,
    }),
    computed: {
      ...mapGetters('setup', ['currentStep']), // Map currentStep from Vuex store
    },
    watch: {
      // Watch for changes in currentStep
      currentStep(newValue) {
        console.log('currentStep updated in License.vue:', newValue)
      },
    },
    mounted() {
      this.setEulaSrc()
    },
    methods: {
      ...mapActions('setup', ['setShowStep']), // Map the setShowStep action from Vuex store
      async onContinue() {
        try {
          await this.setShowStep('System') // Change currentStep to 'System' using Vuex action
          console.log('Navigating to System setup, currentStep is:', this.currentStep) // Log currentStep when navigating
        } catch (error) {
          console.error('Failed to navigate:', error)
        }
        // store.commit('SET_LOADER', true)
        // this.$router.push(`/setup/system/`)
        // const nextStep = await store.dispatch('setup/setStatus', 'license')
        // store.commit('SET_LOADER', false)
        // if (nextStep) {
        //   this.$router.push(`/setup/${nextStep}`)
        // }
      },
      async onClickDisagree() {
        try {
          await this.setShowStep('Wizard') // Change currentStep to 'Wizard' using Vuex action
          console.log('Navigating to Wizard setup')
        } catch (error) {
          console.error('Failed to navigate:', error)
        }
      },
      async setEulaSrc() {
        this.remoteEulaSrc = await uris.translate(uris.list.legal)
      },
    },
  }
</script>

<style scoped>
  .faint-color {
    color: rgba(0, 0, 0, 0.5); /* Adjust the color and opacity */
  }
  .button-container {
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 50px;
  }
</style>
