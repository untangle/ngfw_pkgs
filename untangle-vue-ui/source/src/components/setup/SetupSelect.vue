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
          <!-- Check if previousStep is 'Wizard' or 'License' -->
          <u-btn
            v-if="previousStep === 'Wizard' || previousStep === 'License'"
            :small="false"
            class="custom-btn"
            @click="resetWizard"
          >
            {{ 'Run Setup Wizard' }}
          </u-btn>

          <!-- If previousStep is not 'Wizard' or 'License', show Resume and Restart buttons -->
          <div v-else class="button-container">
            <u-btn :small="false" class="custom-btn" @click="resumeWizard">
              <v-icon left>mdi-play</v-icon>{{ 'Resume' }}
            </u-btn>

            <u-btn :small="false" class="custom-btn" @click="restartWizard">
              <v-icon left>mdi-refresh</v-icon>{{ 'Restart' }}
            </u-btn>
          </div>
        </div>
      </div>

      <!-- Handle remoteReachable for continuation -->
      <div v-else>
        <p v-if="remoteReachable">
          {{ `${localesEn?.To_continue_you_must_log_account_online}` }}
        </p>
        <p v-if="remoteReachable === false">
          {{ `${localesEn?.A_wizard_will_guide} ${rpc?.oemProductName}!` }}
        </p>

        <div v-if="remoteReachable === false" class="button-container">
          <!-- Check if remoteReachable is false, show the onContinue button -->

          <div v-if="previousStep === 'Wizard' || previousStep === 'License'">
            <u-btn :small="false" class="custom-btn" @click="onContinue">
              <v-icon left>mdi-play</v-icon>{{ `${localesEn?.Run_Setup_Wizard}` }}
            </u-btn>
          </div>
          <!-- /// -->
          <div v-else class="button-container">
            <u-btn :small="false" class="custom-btn" @click="resumeWizard">
              <v-icon left>mdi-play</v-icon>{{ 'Resume' }}
            </u-btn>

            <u-btn :small="false" class="custom-btn" @click="restartWizard">
              <v-icon left>mdi-refresh</v-icon>{{ 'Restart' }}
            </u-btn>
          </div>
        </div>

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
      ...mapGetters('setup', ['previousStep']),

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
      ...mapActions('setup', ['setShowStep', 'setShowPreviousStep']),

      logCurrentStep() {
        console.log('currentStep in logCurrentStep method:', this.currentStep)
        console.log('previousStep in logCurrentStep method:', this.previousStep)
      },

      async onContinue() {
        try {
          // await Promise.resolve()
          // this.$router.push('/setup/license')
          try {
            this.showLicense = true
            await this.setShowStep('License')
            await this.setShowPreviousStep('License')
            // console.log(this.showLicense)
          } catch (error) {
            console.error('Failed to reset:', error)
          }
        } catch (error) {
          console.error('Failed to navigate:', error)
        }
      },
      async resetWizard() {
        try {
          this.showLicense = true
          await this.setShowStep('License')
          await this.setShowPreviousStep('License')
          // console.log(this.showLicense)
        } catch (error) {
          console.error('Failed to reset:', error)
        }
      },
      login() {
        window.top.location.href = `${this.rpc.remoteUrl}appliances/add/${this.rpc.serverUID}`
      },
      createAccount() {
        window.top.location.href = `${this.rpc.remoteUrl}login/create-account/add-appliance/${this.rpc.serverUID}`
      },
      someMethodToTriggerLicense() {
        // Trigger License component rendering
        this.showLicense = true
      },
      async resumeWizard() {
        console.log('currentStep ', this.currentStep) // Log currentStep again to confirm it's updated
        console.log('previousStep', this.previousStep)
        await this.setShowStep(this.previousStep)
      },
      async restartWizard() {
        await this.$store.commit('setup/RESET_SYSTEM') // Reset system object to initial values

        await this.setShowStep('License')
        await this.setShowPreviousStep('Wizard')
        console.log(this.previousStep)
      },
    },
  }
</script>
<style scoped>
  .button-container {
    display: flex;
    justify-content: center;
    gap: 10px;
  }
</style>
