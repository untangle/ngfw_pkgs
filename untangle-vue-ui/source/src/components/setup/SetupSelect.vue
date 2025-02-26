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
      <v-dialog v-model="warningDiaglog" max-width="400">
        <v-card>
          <v-card-title class="headline"></v-card-title>
          <v-card-text>
            {{ dialogMessage }}
          </v-card-text>
          <v-card-actions>
            <v-spacer></v-spacer>
            <v-btn color="primary" text @click="closeWarningDialog">OK</v-btn>
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
      }
    },
    computed: {
      ...mapGetters('setup', ['wizardSteps', 'currentStep', 'previousStep']),

      logo() {
        return this.$vuetify.theme.isDark ? 'BrandingLogo.png' : 'BrandingLogo.png'
      },
    },
    mounted() {
      window.addEventListener('resize', this.handleResize)
    },
    beforeDestroy() {
      window.removeEventListener('resize', this.handleResize)
    },
    created() {
      this.presentStepFromStore = this.currentStep
      this.logCurrentStep() // Log again after ensuring data is available

      // Example: Setting up RPC client
      const rpcResponseForSetup = Util.setRpcJsonrpc('setup')

      this.remoteReachable = rpcResponseForSetup?.jsonrpc?.SetupContext?.getRemoteReachable()

      if (!rpcResponseForSetup?.wizardSettings?.wizardComplete && this.rpc?.wizardSettings?.completedStep != null) {
        this.resuming = true
      }

      // TODO will get handled in wizard
      if (this.previousStep === 'System') {
        this.$store.commit('setup/RESET_SYSTEM')
      }
      if (this.previousStep !== 'License' && this.previousStep !== 'Wizard' && this.previousStep !== 'System') {
        this.resuming = true
      }
      if (rpcResponseForSetup) {
        this.rpc = rpcResponseForSetup
      } else {
        this.showWarningDialog('RPC setup failed')
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
      openSetup() {
        this.isOpenSetup = true
      },
      async onClickOk() {
        try {
          // Authenticate the updated password
          await new Promise(resolve => {
            Util.authenticate(this.newPasswordSync, (error, success) => {
              if (error || !success) {
                this.showAuthFailedDialog(error)
              } else {
                // Proceed to the next page after successful authentication
                resolve()
                this.simulateRpcCall()
                if (this.isResetWizardAuthentication) {
                  this.resetWizardContinue()
                } else {
                  this.dialog = false
                  this.setShowStep(this.previousStep)
                  // TODO
                  // this.nextPage()
                  // this.openSetup()
                }
              }
            })
          })
        } catch (error) {
          this.showWarningDialog(error)
        }
      },
      onClickCancel() {
        this.dialog = false
        this.authFailed = false
        this.newPasswordSync = null
      },
      logCurrentStep() {
        console.log('currentStep in logCurrentStep method:', this.currentStep)
        console.log('previousStep in logCurrentStep method:', this.previousStep)
      },
      showWarningDialog(message) {
        this.dialogMessage = message
        this.warningDiaglog = true
      },
      closeWarningDialog() {
        this.warningDiaglog = false
      },
      // async onContinue() {
      //   try {
      //     try {
      //       this.showLicense = true
      //       await this.setShowStep('License')
      //       await this.setShowPreviousStep('License')
      //     } catch (error) {
      //       this.showWarningDialog(`Failed to reset: ${error.message || error}`)
      //     }
      //   } catch (error) {
      //     this.showWarningDialog(`Failed to navigate: ${error.message || error}`)
      //   }
      // },
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
          this.showWarningDialog(`Failed to reset: ${error.message || error}`)
        }
      },
      resetWizardContinue() {
        this.dialog = false
        this.resuming = false
        this.rpc.wizardSettings.completedStep = null
        this.rpc.wizardSettings.wizardComplete = false
        this.$store.commit('setup/RESET_SYSTEM') // Reset system object to initial values
        this.nextPage()
        // this.openSetup()
      },
      async nextPage() {
        await Promise.resolve()
        const currentStepIndex = this.wizardSteps.indexOf(this.currentStep)
        await Util.updateWizardSettings(this.currentStep)
        await this.setShowStep(this.wizardSteps[currentStepIndex + 1])
        await this.setShowPreviousStep(this.wizardSteps[currentStepIndex + 1])
        // await this.setShowStep('License')
        // await this.setShowPreviousStep('License')
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
    width: 300px; /* Adjust the width to your desired length */
    height: 50px; /* Adjust the height to your desired size */
    font-size: 16px; /* Adjust font size if needed */
    align-items: center; /* Vertically center the text */
    justify-content: center; /* Horizontally center the text */
    border-radius: 5px; /* Optional: to make buttons rounded */
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
