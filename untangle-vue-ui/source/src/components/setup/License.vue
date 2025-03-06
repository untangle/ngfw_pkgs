<template>
  <div>
    <SetupLayout />
    <v-container class="text-center" style="max-width: 600px">
      <h1 class="d-flex font-weight-light text-center faint-color">
        License
        <v-spacer />
      </h1>
      <br />
      <p>{{ $t('setup_review_license') }}</p>
      <p>
        {{ $t('setup_license_available_at') }}
        <a :href="remoteEulaSrc" target="_blank">{{ remoteEulaSrc }}</a>
      </p>
      <p>
        <b>{{ $t('setup_legal_links_available_at') }}</b>
      </p>

      <div class="button-container">
        <u-btn :small="false" style="margin: 8px 0" @click="onDisagree">Disagree</u-btn>
        <u-btn :small="false" style="margin: 8px 0" @click="onContinue">Agree</u-btn>
      </div>
    </v-container>
  </div>
</template>

<script>
  import { mapActions, mapGetters } from 'vuex'
  import uris from '@/util/uris'
  import SetupLayout from '@/layouts/SetupLayout.vue'
  import Util from '@/util/setupUtil'

  export default {
    name: 'License',
    components: {
      SetupLayout,
    },
    data: () => ({
      remoteEulaSrc: null,
    }),
    mounted() {
      this.setEulaSrc()
    },
    computed: {
      ...mapGetters('setup', ['wizardSteps', 'currentStep', 'previousStep']),
    },
    created() {
      const rpcResponseForSetup = Util.setRpcJsonrpc('setup')
      if (rpcResponseForSetup) {
        this.rpc = rpcResponseForSetup
      } else {
        this.showWarningDialog('RPC setup failed')
      }
      const rpcResponseForAdmin = Util.setRpcJsonrpc('admin')
      if (rpcResponseForAdmin) {
        this.rpcForAdmin = rpcResponseForAdmin
      } else {
        this.showWarningDialog('RPC setup failed')
      }
    },
    methods: {
      ...mapActions('setup', ['setShowStep']),
      ...mapActions('setup', ['setShowPreviousStep']),

      async setEulaSrc() {
        this.remoteEulaSrc = await uris.translate(uris.list.legal)
      },

      async onContinue() {
        try {
          const currentStepIndex = this.wizardSteps.indexOf(this.currentStep)
          await this.setShowStep(this.wizardSteps[currentStepIndex + 1])
          await this.setShowPreviousStep(this.wizardSteps[currentStepIndex + 1])
        } catch (error) {
          this.$vuntangle.toast.add(this.$t(`Failed to navigate: ${error || error.message}`))
        }
      },

      async onDisagree() {
        await Util.updateWizardSettings(null)
        const currentStepIndex = this.wizardSteps.indexOf(this.currentStep)
        try {
          await this.setShowStep(this.wizardSteps[currentStepIndex - 1])
          await this.setShowPreviousStep(this.wizardSteps[currentStepIndex - 1])
        } catch (error) {
          this.$vuntangle.toast.add(this.$t(`Failed to navigate: ${error || error.message}`))
        }
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
