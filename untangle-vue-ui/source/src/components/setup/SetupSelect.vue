<template>
  <v-container class="text-center flex-grow-1">
    <SetupLayout />
    <div class="d-flex flex-column align-center pt-16 pb-0 mb-16">
      <v-img :src="require('@/assets/BrandingLogo.png')" contain transition="false" max-height="80" class="my-4" />
      <br />
      <h1>{{ `${localesEn?.Thanks_for_choosing} ${rpc?.oemShortName}!` }}</h1>
      <div v-if="!rpc?.remote">
        <p class="font-weight-medium text-h6 text--secondary">
          {{ `${localesEn?.A_wizard_will_guide} ${rpc?.oemProductName}!` }}
        </p>
        <br />
        <div>
          <u-btn v-if="resuming" :small="false" class="mr-10 mt-2" @click="resumeWizard">
            <v-icon left>mdi-play</v-icon>{{ 'Resume Setup Wizard' }}
          </u-btn>
          <u-btn :small="false" class="mr-10 mt-2" @click="resetWizard">
            <v-icon left>mdi-refresh</v-icon>{{ !resuming ? 'Run Setup Wizard' : 'Restart' }}
          </u-btn>
        </div>
      </div>
      <div v-else>
        <div v-if="remoteReachable === null">
          <p class="font-weight-medium text-h6">
            {{ `Checking Internet connectivity` }}
          </p>
        </div>
        <div v-if="remoteReachable">
          <p class="font-weight-medium text-h6 text--secondary">
            To continue, you must log in using your ETM Dashboard account. If you do not have one, you can create a free
            account.
          </p>
          <br />
          <div>
            <u-btn :small="false" class="mr-10 mt-2" @click="login">Login</u-btn>
            <u-btn :small="false" class="mr-10 mt-2" @click="createAccount">Create Account</u-btn>
          </div>
        </div>
        <div v-else-if="!remoteReachable">
          <p class="font-weight-medium text-h6 text--secondary">
            To continue, you must connect to ETM Dashboard which is currently unreachable from this device.<br />
            You must configure Internet connectivity to ETM Dashboard to continue
          </p>
          <u-btn :small="false" class="mr-10 mt-2" @click="resetWizard">Configure Internet</u-btn>
        </div>
      </div>
    </div>
    <v-dialog v-model="dialog" persistent max-width="350" @keydown.enter="onClickOk">
      <v-card>
        <v-card-title>{{ $t('Authentication Required') }}</v-card-title>
        <v-card-text class="body-1">
          {{ `Please enter admin password` }}
        </v-card-text>
        <u-password v-model="newPasswordSync" density="compact" class="w-55 ml-5 mr-5" autofocus />
        <v-card-actions class="pt-5 pb-5">
          <u-btn :small="false" class="ml-5 mr-5" @click="onClickOk">OK</u-btn>
          <u-btn :small="false" class="ml-5 mr-5" @click="onClickCancel">CANCEL</u-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
    <v-dialog v-model="authFailed" max-width="400">
      <v-card>
        <v-card-title>Authentication failed</v-card-title>
        <v-card-text class="body-1">
          {{ authFailedMessage }}
        </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn text @click="closeDialog">OK</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script>
  import { mapGetters, mapActions } from 'vuex'
  import Util from '@/util/setupUtil'
  import locales from '@/locales/en'
  import AlertDialog from '@/components/Reusable/AlertDialog.vue'

  export default {
    name: 'SetupSelect',
    data() {
      return {
        resuming: false,
        remoteReachable: null,
        showLicense: false,
        localesEn: locales || null,
        presentStepFromStore: null,
        dialog: false,
        newPasswordSync: '',
        authFailed: false,
        authFailedMessage: '',
        rpcResponseForSetup: null,
        rpc: null,
        isNonDefaultPassword: null,
        isResetWizardAuthentication: false,
        warningDiaglog: false,
        windowWidth: window.innerWidth,
        adminRpc: null,
        updatedSettings: null,
        index: 0,
      }
    },
    computed: {
      ...mapGetters('setup', ['wizardSteps', 'currentStep', 'previousStep']), // from Vuex

      logo() {
        return this.$vuetify.theme.isDark ? 'BrandingLogo.png' : 'BrandingLogo.png'
      },
    },
    mounted() {
      if (!this.rpc?.wizardSettings?.wizardComplete && this.rpc?.wizardSettings?.completedStep != null) {
        this.resuming = true
      }
    },
    created() {
      this.presentStepFromStore = this.currentStep
      const rpcResponseForSetup = Util.setRpcJsonrpc('setup')
      if (rpcResponseForSetup) {
        this.rpc = rpcResponseForSetup
      }

      const setupRpc = Util.setRpcJsonrpc('setup')

      this.remoteReachable = setupRpc.jsonrpc.SetupContext.getRemoteReachable()
      const rpcResponseForAdmin = Util.setRpcJsonrpc('admin')

      if (rpcResponseForAdmin) {
        this.adminRpc = rpcResponseForAdmin
      }
    },

    methods: {
      ...mapActions('setup', ['setShowStep', 'setShowPreviousStep', 'setSetupContext']),

      handleResize() {
        this.windowWidth = window.innerWidth
      },
      showDialog() {
        this.dialog = true
      },
      closeDialog() {
        this.authFailed = false
        this.dialog = false
        this.newPasswordSync = null
        this.isResetWizardAuthentication = false
      },
      showAuthFailedDialog(message) {
        this.authFailedMessage = message
        this.authFailed = true
      },
      alertDialog(message) {
        this.$vuntangle.dialog.show({
          title: this.$t('Warning'),
          component: AlertDialog,
          componentProps: {
            alert: { message },
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
      async onClickOk() {
        try {
          await new Promise(resolve => {
            Util.authenticate(this.newPasswordSync, (error, success) => {
              if (error || !success) {
                this.showAuthFailedDialog(error)
              } else {
                resolve()
                this.simulateRpcCall()
                if (this.isResetWizardAuthentication) {
                  this.resetWizardContinue()
                } else {
                  this.dialog = false
                  this.$store.commit('setup/RESET_SYSTEM')
                  const completedStep = this.rpc.wizardSettings.completedStep
                  const currentStepIndex = this.wizardSteps.indexOf(completedStep)
                  this.setShowStep(this.wizardSteps[currentStepIndex])
                  this.setShowPreviousStep(this.wizardSteps[currentStepIndex])
                }
              }
            })
          })
        } catch (error) {
          this.alertDialog(error)
        }
      },
      onClickCancel() {
        this.dialog = false
        this.authFailed = false
        this.newPasswordSync = null
      },
      async resetWizard() {
        try {
          if (this.rpc.remote && !this.remoteReachable) {
            if (Util.setRpcJsonrpc('admin')) {
              this.resetWizardContinue()
            } else {
              await new Promise(() => {
                Util.authenticate('passwd', isNonDefaultPassword => {
                  if (isNonDefaultPassword) {
                    this.isResetWizardAuthentication = true
                    this.showDialog()
                  } else {
                    this.resetWizardContinue()
                  }
                })
                this.dialog = true
              })
            }
          } else {
            this.resetWizardContinue()
          }
        } catch (error) {
          this.alertDialog(`Failed to reset: ${error.message || error}`)
        }
      },
      async resetWizardContinue() {
        this.dialog = false
        this.resuming = false
        this.rpc.wizardSettings.completedStep = null
        this.rpc.wizardSettings.wizardComplete = false
        this.$store.commit('setup/RESET_SYSTEM')
        const currentStepIndex = this.wizardSteps.indexOf(this.currentStep)
        await Promise.resolve()
        await this.setShowStep(this.wizardSteps[currentStepIndex + 1])
        await this.setShowPreviousStep(this.wizardSteps[currentStepIndex + 1])
      },
      login() {
        window.top.location.href = `${this.rpc.remoteUrl}appliances/add/${this.rpc.serverUID}`
      },
      createAccount() {
        window.top.location.href = `${this.rpc.remoteUrl}login/create-account/add-appliance/${this.rpc.serverUID}`
      },
      async resumeWizard() {
        this.showDialog()
        await this.simulateRpcCall()
      },
      simulateRpcCall() {
        return new Promise(resolve => {
          setTimeout(() => {
            resolve('Data saved')
          }, 300000)
        })
      },
    },
  }
</script>
