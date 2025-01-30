<template>
  <!-- Render the rest of the content when showLicense is false -->
  <div>
    <v-container class="text-center custom-margin" style="max-width: 800px">
      <div
        class="d-flex flex-column align-center mb-2"
        style="padding-top: 80px; padding-bottom: 0px; margin-bottom: 800px"
      >
        <v-img :src="require('@/assets/BrandingLogo.png')" contain transition="false" class="branding-logo" />
      </div>
      <h1>{{ `${localesEn?.Thanks_for_choosing} ${rpc?.oemShortName}!` }}</h1>

      <!-- Resume Wizard -->
      <div v-if="!rpc?.remote">
        <p>
          {{ `${localesEn?.A_wizard_will_guide} ${rpc?.oemProductName}!` }}
        </p>
        <div class="button-container">
          <u-btn v-if="resuming" :small="false" class="custom-btn" @click="resumeWizard">{{
            `${localesEn?.Run_Setup_Wizard}`
          }}</u-btn>
          <u-btn :small="false" class="custom-btn" @click="resetWizard">
            {{ !resuming ? 'Run Setup Wizard' : 'Restart' }}
          </u-btn>
        </div>
      </div>

      <div v-else>
        <p v-if="remoteReachable">
          {{ `${localesEn?.To_continue_you_must_log_account_online}` }}
        </p>
        <p v-if="remoteReachable === false">
          {{ `${localesEn?.A_wizard_will_guide} ${rpc?.oemProductName}!` }}
        </p>

        <u-btn v-if="remoteReachable === false" :small="false" @click="onContinue">{{
          `${localesEn?.Run_Setup_Wizard}`
        }}</u-btn>

        <div v-if="remoteReachable" class="button-container">
          <u-btn :small="false" class="custom-btn" @click="login">Login</u-btn>
          <u-btn :small="false" class="custom-btn" @click="createAccount">Create Account</u-btn>
        </div>
      </div>
    </v-container>
  </div>
</template>

<script>
  import { mapGetters, mapActions } from 'vuex' // Import map helpers
  import Util from '@/util/setupUtil' // Assuming Util is in the utils directory
  import locales from '@/locales/en' // Import the locale from the locales/en.js file
  export default {
    name: 'SetupSelect',
    data() {
      return {
        showLicense: false, // To control rendering of License component
        rpc: null,
        localesEn: locales || null,
        remoteReachable: null,
        resuming: false,
        presentStepFromStore: null,
      }
    },
    computed: {
      ...mapGetters('setup', ['currentStep']),

      logo() {
        return this.$vuetify.theme.isDark ? 'BrandingLogo.png' : 'BrandingLogo.png'
      },
    },
    created() {
      // Log currentStep from Vuex store
      console.log('currentStep from Vuex:', this.currentStep) // This should log the value correctly
      this.presentStepFromStore = this.currentStep
      this.logCurrentStep() // Log again after ensuring data is available

      // Example: Setting up RPC client
      const rpcResponseForSetup = Util.setRpcJsonrpc('setup')
      console.log(rpcResponseForSetup)

      this.remoteReachable = rpcResponseForSetup?.jsonrpc?.SetupContext?.getRemoteReachable()
      this.resuming = rpcResponseForSetup?.wizardSettings?.wizardComplete
      if (rpcResponseForSetup) {
        this.rpc = rpcResponseForSetup
      } else {
        console.error('RPC setup failed')
      }
    },
    methods: {
      ...mapActions('setup', ['setShowStep']), // Map the setShowStep action from Vuex store

      // New method to log currentStep from Vuex
      logCurrentStep() {
        console.log('currentStep in logCurrentStep method:', this.currentStep) // Log currentStep again to confirm it's updated
        console.log('this.presentStepFromStore', this.presentStepFromStore)
      },

      async onContinue() {
        try {
          await Promise.resolve()
          this.$router.push('/setup/license')
        } catch (error) {
          console.error('Failed to navigate:', error)
        }
      },
      async resetWizard() {
        try {
          this.showLicense = true
          await this.setShowStep('License')
          console.log(this.showLicense)
        } catch (error) {
          console.error('Failed to reset:', error)
        }
      },
      login() {
        window.location = `${this.rpc.remoteUrl}appliances/add/${this.rpc.serverUID}`
      },
      createAccount() {
        window.location = `${this.rpc.remoteUrl}login/create-account/add-appliance/${this.rpc.serverUID}`
      },
      someMethodToTriggerLicense() {
        // Trigger License component rendering
        this.showLicense = true
      },
    },
  }
</script>
