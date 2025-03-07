<template>
  <div>
    <v-container class="text-center custom-margin" style="max-width: 800px">
      <div
        class="d-flex flex-column align-center mb-2"
        style="padding-top: 80px; padding-bottom: 0px; margin-bottom: 800px"
      >
        <v-img :src="require('@/assets/BrandingLogo.png')" contain transition="false" class="branding-logo" />
        <br />
        <h1>{{ `${localesEn?.Thanks_for_choosing} ${rpc?.oemShortName}!` }}</h1>
        <div v-if="!rpc?.remote">
          <p>
            {{ `${localesEn?.A_wizard_will_guide} ${rpc?.oemProductName}!` }}
          </p>
          <br />
          <div class="button-container">
            <u-btn v-if="resuming" :small="false" class="custom-btn" @click="resumeWizard">
              <v-icon left>mdi-play</v-icon>{{ 'Resume Setup Wizard' }}
            </u-btn>
            <u-btn :small="false" class="custom-btn" @click="resetWizard">
              <v-icon left>mdi-refresh</v-icon>{{ !resuming ? 'Run Setup Wizard' : 'Restart' }}
            </u-btn>
          </div>
        </div>
        <div v-else>
          <div v-if="remoteReachable === null">
            {{ `Checking Internet connectivity` }}
          </div>
          <div v-if="remoteReachable">
            <p>
              To continue, you must log in using your ETM Dashboard account. If you do not have one, you can create a
              free account.
            </p>
            <br />
            <div class="button-container">
              <u-btn :small="false" class="custom-btn" @click="login">Login</u-btn>
              <u-btn :small="false" class="custom-btn" @click="createAccount">Create Account</u-btn>
            </div>
          </div>
          <div v-else-if="!remoteReachable">
            <p>
              To continue, you must connect to ETM Dashboard which is currently unreachable from this device.<br />
              You must configure Internet connectivity to ETM Dashboard to continue
            </p>
            <u-btn :small="false" class="custom-btn" @click="resetWizard">Configure Internet</u-btn>
          </div>
        </div>
      </div>
      <v-dialog v-model="dialog" persistent max-width="290">
        <v-card>
          <v-card-text> Authentication Required </v-card-text>
          <label class="label-card">Please enter admin password</label>
          <u-password v-model="newPasswordSync" class="custom-password-field" />
          <!-- <v-test-field v-model="newPasswordSync" type="password" class="custom-password-field"></v-test-field> -->
          <v-card-actions class="buttons">
            <u-btn @click="onClickOk">OK</u-btn>
            <u-btn @click="onClickCancel">CANCEL</u-btn>
          </v-card-actions>
        </v-card>
      </v-dialog>
      <v-dialog v-model="authFailed" max-width="400">
        <v-card>
          <v-card-title class="headline">Authentication failed</v-card-title>
          <v-card-text>
            {{ authFailedMessage }}
          </v-card-text>
          <v-card-actions>
            <v-spacer></v-spacer>
            <v-btn color="primary" text @click="closeDialog">OK</v-btn>
          </v-card-actions>
        </v-card>
      </v-dialog>
    </v-container>
    <div v-if="isOpenSetup" class="setup-container">
      <div v-if="windowWidth >= 840" class="flex-item left-space"></div>

      <div class="setupwizard-container">
        <div class="setupwizard-box">
          <SetupWizard />
        </div>
      </div>

      <div v-if="windowWidth >= 840" class="flex-item right-space"></div>
    </div>
  </div>
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
        isOpenSetup: false,
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

      const rpcResponseForAdmin = Util.setRpcJsonrpc('admin')
      if (rpcResponseForAdmin) {
        this.adminRpc = rpcResponseForAdmin
      }
      this.remoteReachable = this.rpc.jsonrpc.SetupContext.getRemoteReachable()
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
      openSetup() {
        this.isOpenSetup = true
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
            if (Util.setRpcJsonrpc('admin') === true) {
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
<style scoped>
  .custom-btn {
    width: 300px;
    height: 50px;
    font-size: 16px;
    align-items: center;
    justify-content: center;
    border-radius: 5px;
  }
  .button-container {
    display: flex;
    justify-content: center;
    gap: 20px;
  }

  .buttons {
    margin-left: 10px;
  }
  .buttons .v-btn {
    font-size: 12px;
    height: 25px;
  }
  .custom-password-field {
    width: 90%;
    padding-left: 10%;
  }

  .label-card {
    padding-left: 10%;
  }

  .custom-password-field .v-input__control {
    background-color: #f5f5f5;
    border-radius: 8px;
  }
  .setup-container {
    /* display: flex; */
    width: 100vw; /* Full viewport width */
    height: 100vh; /* Full viewport height */
    background: white;
    align-items: center;
    justify-content: center;
    padding: 40px; /* Adjust padding as needed */
    box-sizing: border-box;
  }

  /* Left and right space to mimic the original layout */
  .flex-item {
    flex: 1;
  }

  /* Centered SetupWizard box */
  .setupwizard-container {
    flex: 1;
    display: flex;
    justify-content: center;
    align-items: center;
  }

  /* Styled box with border, padding, and margins */
  .setupwizard-box {
    width: 60vw; /* 60% of viewport width */
    max-width: 1200px; /* Max width */
    height: 90vh; /* 70% of viewport height */
    max-height: 1000px; /* Max height */
    padding: 20px;
    margin: 20px;
    border: 3px solid #aaa7a7; /* Thick square border */
    border-radius: 10px; /* Rounded corners */
    background: #f5f5f5;
    box-shadow: 4px 4px 10px rgba(214, 213, 213, 0.2);
    display: flex;
    align-items: center;
    justify-content: center;
  }

  /* Responsive adjustments */
  @media (max-width: 840px) {
    .setupwizard-box {
      width: 90vw; /* 90% width on small screens */
      height: 80vh; /* 80% height on small screens */
      margin: 10px;
    }
  }
</style>
