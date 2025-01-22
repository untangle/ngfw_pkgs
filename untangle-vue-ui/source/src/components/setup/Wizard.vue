<template>
  <v-container class="text-center custom-margin" style="max-width: 800px">
    <v-img :src="require(`@/assets/${logo}`)" contain style="padding-bottom: 10%" />
    <h1>{{ `${localesEn?.Thanks_for_choosing} ${rpc?.oemShortName}!` }}</h1>

    <!-- Resume Wizard -->
    <div v-if="!rpc.remote">
      <p>
        {{ `${localesEn?.A_wizard_will_guide} ${rpc?.oemProductName}!` }}
      </p>
      <div class="button-group">
        <u-btn v-if="resuming" @click="resumeWizard">{{ `${localesEn?.Run_Setup_Wizard}` }}</u-btn>
        <u-btn @click="resetWizard">
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
        <u-btn :small="false" @click="login">Login</u-btn>
        <u-btn :small="false" @click="createAccount">Create Account</u-btn>
      </div>
    </div>
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
          // Navigate to the setup license page
          this.$router.push('/setup/license')
        } catch (error) {
          console.error('Failed to navigate:', error)
        }
      },
      login() {
        window.location = `${this.rpc.remoteUrl}appliances/add/${this.rpc.serverUID}`
      },
      createAccount() {
        window.location = `${this.rpc.remoteUrl}/login/create-account/add-appliance/${this.rpc.serverUID}`
      },
    },
  }
</script>

<style scoped>
  .custom-margin {
    margin-top: 10px;
  }
  /* Button container for spacing */
</style>
