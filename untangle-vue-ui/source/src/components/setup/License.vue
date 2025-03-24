<template>
  <v-container class="text-center flex-grow-1" style="max-width: 820px">
    <SetupLayout />
    <!-- <v-container class="text-center" style="max-width: 820px"> -->
    <h1 class="d-flex font-weight-thin">License</h1>
    <br />
    <p class="font-weight-medium text-h6 text--secondary">
      To continue installing and using this software, you must agree to the terms and conditions of the software license
      agreement. Please review the whole license agreement by navigating to the provided website link and scrolling
      through to the end of the agreement.
    </p>
    <p class="font-weight-medium text-h6 text--secondary">
      {{ $t('setup_license_available_at') }}
      <a :href="remoteEulaSrc" target="_blank">{{ remoteEulaSrc }}</a>
    </p>
    <p class="font-weight-medium text-h6 text--secondary">
      <b>{{ $t('setup_legal_links_available_at') }}</b>
    </p>

    <div>
      <u-btn :small="false" class="mr-10 mt-3" @click="onDisagree">{{ $t('Disagree') }}</u-btn>
      <u-btn :small="false" class="mr-10 mt-3" @click="onContinue">{{ $t('Agree') }}</u-btn>
    </div>
    <!-- <div class="d-flex justify-space-between pa-7" style="position: relative">
        <u-btn :small="false" @click="onDisagree">{{ `Disagree` }}</u-btn>
        <u-btn :small="false" @click="onContinue">{{ `Agree` }}</u-btn>
      </div> -->
    <!-- </v-container> -->
  </v-container>
</template>

<script>
  import { mapActions, mapGetters } from 'vuex'
  import uris from '@/util/uris'
  import SetupLayout from '@/layouts/SetupLayout.vue'
  import Util from '@/util/setupUtil'
  import AlertDialog from '@/components/Reusable/AlertDialog.vue'

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
        this.alertDialog('RPC setup failed')
      }
      const rpcResponseForAdmin = Util.setRpcJsonrpc('admin')
      if (rpcResponseForAdmin) {
        this.rpcForAdmin = rpcResponseForAdmin
      } else {
        this.alertDialog('RPC setup failed')
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
      alertDialog(message) {
        this.$vuntangle.dialog.show({
          title: this.$t('Warning'),
          component: AlertDialog,
          componentProps: {
            alert: { message }, // Pass the plain message in an object
          },
          width: 600,
          height: 500,
          buttons: [
            {
              name: this.$t('close'),
              handler() {
                this.onClose()
              },
            },
          ],
        })
      },
    },
  }
</script>
