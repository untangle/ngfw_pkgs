<template>
  <v-container class="text-center custom-margin" style="max-width: 800px">
    <div
      class="d-flex flex-column align-center mb-2"
      style="padding-top: 80px; padding-bottom: 0px; margin-bottom: 800px"
    >
      <v-img :src="require('@/assets/BrandingLogo.png')" contain transition="false" class="branding-logo" />
    </div>
    <!-- <v-img :src="require(`@/assets/${logo}`)" contain width="240" height="40" transition="false" /> -->
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
    <!-- <div class="button-container">
      <u-btn :small="false" class="custom-btn login-btn" @click="login">Login</u-btn>
      <u-btn :small="false" class="custom-btn create-account-btn" @click="createAccount">Create Account</u-btn>
      <button :small="false" class="custom-btn login-btn" @click="login">Login</button>
      <button :small="false" class="custom-btn create-account-btn" @click="createAccount">Create Account</button>
    </div> -->
  </v-container>
</template>

<script>
  import Util from '@/util/setupUtil' // Assuming Util is in the utils directory
  import locales from '@/locales/en' // Import the locale from the locales/en.js file

  export default {
    data() {
      return {
        rpc: null,
        localesEn: locales || null,
        remoteReachable: null,
        resuming: false,
      }
    },
    computed: {
      logo() {
        return this.$vuetify.theme.isDark ? 'BrandingLogo.png' : 'BrandingLogo.png'
      },
    },

    created() {
      // Set up the RPC client and fetch relevant data
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
          await Promise.resolve()
          localStorage.clear()
          this.$router.push('/setup/license')
        } catch (error) {
          console.error('Failed to navigate:', error)
        }
      },
      login() {
        window.location = `${this.rpc.remoteUrl}appliances/add/${this.rpc.serverUID}`
      },
      createAccount() {
        window.location = `${this.rpc.remoteUrl}login/create-account/add-appliance/${this.rpc.serverUID}`
      },
    },
  }
</script>

<style scoped>
  /* Button container for spacing */
  .branding-logo {
    margin-bottom: 0;
    width: 400px;
    height: 100px;
  }
  .custom-margin {
    margin-top: 10px;
  }
  .button-container {
    display: flex;
    flex-direction: column; /* Stack the buttons vertically */
    justify-content: center; /* Center buttons vertically within the container */
    align-items: center; /* Center buttons horizontally */
    gap: 0px; /* Space between the buttons */
    margin-top: 1px; /* Space above the buttons */
    margin-bottom: 1px; /* Space below the buttons */
  }

  .custom-btn {
    margin: 5px 0; /* Margin for spacing between buttons */
    width: 300px; /* Fixed width for buttons */
    height: 50px; /* Fixed height for buttons */
    font-size: 16px; /* Text size */
    border-radius: 5px; /* Optional: rounded corners */
    text-align: center; /* Center text */
  }

  .login-btn {
    background-color: #007bff; /* Blue color for Login button */
    color: white; /* White text color */
    border: none; /* Remove border */
  }

  .create-account-btn {
    background-color: #28a745; /* Green color for Create Account button */
    color: white; /* White text color */
    border: none; /* Remove border */
  }

  p {
    white-space: nowrap; /* Prevents text from wrapping */
    overflow: hidden; /* Hides overflow if the text exceeds container width */
    text-overflow: ellipsis; /* Optionally adds "..." if the text overflows */
    max-width: 100%; /* Adjusts the width to 100% of the parent container */
    width: 100%; /* Ensures the container takes up full available width */
    display: inline-block; /* Ensures the element is inline but still allows width adjustments */
  }
</style>
