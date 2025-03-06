<template>
  <v-card width="1100" height="auto" class="mx-auto mt-4" flat>
    <SetupLayout />
    <v-container class="main-div">
      <div class="step-title">Configure the Internet Connection</div>
      <div v-if="!remoteReachable" class="warning-message">
        <p>No Internet Connection..! Click on 'Test Connectivity' to verify.</p>
      </div>
      <div v-if="wan">
        <ValidationObserver v-slot="{ passes }">
          <!-- invalid    Add invalid in v-slot parameter if we want to add disabling in invalid-->
          <v-form>
            <div class="config-type">
              <label class="sectionheader">Configuration Type</label>
              <div class="radio-group">
                <label> <input v-model="wan.v4ConfigType" type="radio" value="AUTO" /> Auto (DHCP) </label>
                <label> <input v-model="wan.v4ConfigType" type="radio" value="STATIC" /> Static </label>
                <label> <input v-model="wan.v4ConfigType" type="radio" value="PPPOE" /> PPPoE </label>
              </div>
            </div>
            <div class="column-view">
              <div class="select-Network-content">
                <!-- Static Configuration Fields -->
                <div v-if="wan.v4ConfigType === 'STATIC'" class="pppoe-config">
                  <ValidationProvider v-slot="{ errors }" :rules="{ required: true, ip: true }">
                    <label>IP Address:</label>

                    <u-text-field v-model="wan.v4StaticAddress" :error-messages="errors">
                      <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                    </u-text-field>
                  </ValidationProvider>

                  <ValidationProvider rules="required">
                    <label>Netmask:</label>
                    <v-autocomplete
                      v-model="v4StaticPrefixModel"
                      :items="v4NetmaskList"
                      outlined
                      dense
                      hide-details
                      return-object
                    />
                  </ValidationProvider>

                  <ValidationProvider v-slot="{ errors }" :rules="{ required: true, ip: true }">
                    <label>Gateway:</label>
                    <u-text-field v-model="wan.v4StaticGateway" :error-messages="errors">
                      <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                    </u-text-field>
                  </ValidationProvider>

                  <ValidationProvider v-slot="{ errors }" :rules="{ required: true, ip: true }">
                    <label>Primary DNS:</label>
                    <u-text-field v-model="wan.v4StaticDns1" :error-messages="errors">
                      <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                    </u-text-field>
                  </ValidationProvider>

                  <ValidationProvider v-slot="{ errors }" :rules="{ ip: true }">
                    <label>Secondary DNS (optional):</label>
                    <u-text-field v-model="wan.v4StaticDns2" :error-messages="errors">
                      <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                    </u-text-field>
                  </ValidationProvider>
                </div>

                <!-- Auto (DHCP) Configuration Fields -->
                <div v-if="wan.v4ConfigType === 'AUTO'" class="auto-config">
                  <div class="button-margin">
                    <u-btn :small="false" class="renew-button" :disabled="loading" @click="renewDhcp">
                      <v-icon left>mdi-autorenew</v-icon> Renew DHCP
                    </u-btn>
                  </div>
                </div>

                <!-- PPPoE Configuration Fields -->
                <div v-if="wan.v4ConfigType === 'PPPOE'">
                  <ValidationProvider v-slot="{ errors }" :rules="{ required: true }">
                    <label>User Name:</label>
                    <u-text-field v-model="wan.v4PPPoEUsername" :label="$t('User Name ')" :error-messages="errors">
                      <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                    </u-text-field>
                  </ValidationProvider>

                  <ValidationProvider v-slot="{ errors }" :rules="{ required: true, min: 3 }">
                    <label>Password:</label>
                    <u-password v-model="wan.v4PPPoEPassword" :label="$t('Password')" :error-messages="errors">
                      <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                    </u-password>
                  </ValidationProvider>
                </div>
              </div>
              <div class="status-grid">
                <p class="sectionheader">Status:</p>
                <div class="status-item">
                  <label>IP Address:</label>
                  <span>{{ wanStatus.v4Address }}</span>
                </div>
                <div class="status-item">
                  <label>Netmask:</label>
                  <span>/ {{ wanStatus.v4PrefixLength }} - {{ wanStatus.v4Netmask }}</span>
                </div>
                <div class="status-item">
                  <label>Gateway:</label>
                  <span>{{ wanStatus.v4Gateway }}</span>
                </div>
                <div class="status-item">
                  <label>Primary DNS:</label>
                  <span>{{ wanStatus.v4Dns1 }}</span>
                </div>
                <div class="status-item">
                  <label>Secondary DNS:</label>
                  <span>{{ wanStatus.v4Dns2 }}</span>
                </div>
                <div>
                  <u-btn :small="false" class="button-test-connectivity" @click="onSave('testConnectivity')">
                    <v-icon class="world-icon mr-2">mdi-earth</v-icon> Test Connectivity
                  </u-btn>
                </div>
              </div>
            </div>
            <!-- Condition is handled for disabling the Next/Prev button during the initial setup step -->
            <div v-if="wizardSteps.length > 3" class="button-container">
              <u-btn :small="false" style="margin: 8px 0" @click="onClickBack">Back</u-btn>
              <u-btn :small="false" style="margin: 8px 0" @click="passes(onSave('save'))">Next</u-btn>
            </div>
          </v-form>
        </ValidationObserver>
      </div>
      <div v-else-if="!remoteTestPassed" class="button-container">
        <div class="center-container-renew-button">
          <span class="center-text">
            You may continue configuring your Internet connection or run the Setup Wizard locally
          </span>
          <u-btn :small="false" class="renew-button" :disabled="loading" @click="resetWizard">
            <v-icon left>mdi-autorenew</v-icon> Run Setup Wizard Locally
          </u-btn>
        </div>
      </div>
      <!-- Dialog Box for show No internal interfaces -->
      <v-dialog v-model="dialog" persistent max-width="290">
        <v-card>
          <v-card-title class="headline">Warning!</v-card-title>
          <v-card-text> No internal interfaces found. Do you want to continue the setup? </v-card-text>
          <v-card-actions>
            <v-btn color="green" text @click="onConfirm">Yes</v-btn>
            <v-btn color="red" text @click="onCancel">No</v-btn>
          </v-card-actions>
        </v-card>
      </v-dialog>
    </v-container>
  </v-card>
</template>

<script>
  import { mapActions, mapGetters } from 'vuex'
  import SetupLayout from '@/layouts/SetupLayout.vue'
  import Util from '@/util/setupUtil'
  import AlertDialog from '@/components/Reusable/AlertDialog.vue'
  import confirmDialog from '@/components/Reusable/ConfirmDialog.vue'

  // import store from '@/store'
  export default {
    name: 'Internet',
    components: {
      SetupLayout,
    },
    data() {
      return {
        remoteReachable: null,
        wan: {},
        wanStatus: {},
        networkSettings: null,
        v4NetmaskList: Util.v4NetmaskList.map(n => ({ value: n[0], text: n[1] })),
        loading: false,
        rpcForAdmin: null,
        nextDisabled: false,
        remoteTestPassed: true,
        remote: false,
        rpc: null,
      }
    },
    computed: {
      v4StaticPrefixModel: {
        get() {
          return this.wan.v4StaticPrefix ?? 24
        },
        set(value) {
          this.wan.v4StaticPrefix = value
        },
      },
      passwordRequired() {
        return this.$store.state.setup?.status?.step ? this.$store.state.setup?.status.step === 'system' : true
      },
      ...mapGetters('setup', ['wizardSteps', 'currentStep', 'previousStep']), // from Vuex
    },
    created() {
      this.rpc = Util.setRpcJsonrpc('setup')
      this.rpcForAdmin = Util.setRpcJsonrpc('admin')
      // this.remoteReachable = this.rpc?.jsonrpc?.SetupContext?.getRemoteReachable()
      this.remote = this.rpc.remote
    },
    mounted() {
      this.getSettings()
    },
    methods: {
      ...mapActions('setup', ['setShowStep']),
      ...mapActions('setup', ['setShowPreviousStep']),
      async onClickBack() {
        try {
          const currentStepIndex = await this.wizardSteps.indexOf(this.currentStep)
          await this.setShowStep(this.wizardSteps[currentStepIndex - 1])
          await this.setShowPreviousStep(this.wizardSteps[currentStepIndex - 1])
        } catch (error) {
          this.alertDialog(`Failed to navigate: ${error.message || error}`)
        }
      },

      async showLoader(value) {
        await this.$store.commit('SET_LOADER', value)
      },
      alertDialog(message) {
        this.$vuntangle.dialog.show({
          title: this.$t('Internet Status'),
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
      confirmDialog({ message, onConfirmNo = null, onConfirmYes = null }) {
        this.$vuntangle.dialog.show({
          title: this.$t('Internet Status'),
          component: confirmDialog,
          componentProps: {
            alert: { message },
          },
          width: 600,
          height: 500,
          buttons: [
            {
              name: this.$t('Yes'),
              handler() {
                this.onClose()
                onConfirmYes()
              },
            },
            {
              name: this.$t('No'),
              handler() {
                this.onClose()
                onConfirmNo()
              },
            },
          ],
        })
      },

      onSave(triggeredBy, cb) {
        if (!this.wan) {
          cb()
          return
        }

        if (this.wan.v4ConfigType === 'AUTO' || this.wan.v4ConfigType === 'PPPOE') {
          this.wan.v4StaticAddress = null
          this.wan.v4StaticPrefix = null
          this.wan.v4StaticGateway = null
          this.wan.v4StaticDns1 = null
          this.wan.v4StaticDns2 = null
        }
        if (this.wan.v4ConfigType === 'STATIC') {
          this.wan.v4NatEgressTraffic = true
          if (this.wan.v4StaticPrefix && this.wan.v4StaticPrefix.value) {
            this.wan.v4StaticPrefix = this.wan.v4StaticPrefix.value
          }
        }
        if (this.wan.v4ConfigType === 'PPPOE') {
          this.wan.v4NatEgressTraffic = true
          this.wan.v4PPPoEUsePeerDns = true
        }

        const mode = triggeredBy === 'testConnectivity' ? 'manual' : 'auto'

        try {
          this.$store.commit('SET_LOADER', true)

          this.rpcForAdmin.networkManager.setNetworkSettings((response, ex) => {
            if (ex) {
              Util.handleException(ex)
              this.$store.commit('SET_LOADER', false)
              return
            }

            this.testConnectivity(mode, () => {
              if (typeof cb === 'function') {
                cb()
                // this.nextPage()
                if (mode === 'auto') {
                  this.nextPage()
                }
              }

              this.$vuntangle.toast.add(this.$t('Saving settings ...'))

              this.$store.commit('SET_LOADER', false)
            })
          }, this.networkSettings)
        } catch (error) {
          this.alertDialog('Unable to save network settings. Please try again.')
          this.$store.commit('SET_LOADER', false)
        }
      },
      async testConnectivity(testType, cb) {
        let message = null
        let nextDisabled = true

        try {
          this.$store.commit('SET_LOADER', true)

          await this.$vuntangle.toast.add(this.$t('Testing Connectivity...'))

          const result = await this.rpcForAdmin.connectivityTester.getStatus()

          if (!result.tcpWorking && !result.dnsWorking) {
            message = 'Warning! Internet tests and DNS tests failed.'
          } else if (!result.tcpWorking) {
            message = 'Warning! DNS tests succeeded, but Internet tests failed.'
          } else if (!result.dnsWorking) {
            message = 'Warning! Internet tests succeeded, but DNS tests failed.'
          } else if (this.remote) {
            this.remoteReachable = await this.rpcForAdmin.setup.getRemoteReachable()
            if (!this.remoteReachable) {
              message = 'Unable to reach ETM Dashboard!'
            } else {
              nextDisabled = false
            }
          } else {
            nextDisabled = false
            message = null
          }

          if (this.remote) {
            this.nextDisabled = nextDisabled
          }

          if (this.remote && message !== null) {
            console.log('this.remote && message !== null')
            this.remoteTestPassed = false
            message = 'You may continue configuring your Internet connection or run the Setup Wizard locally.'
          }

          if (testType === 'manual') {
            this.alertDialog(message || 'Success!')
          } else {
            if (!message) {
              cb()
              return
            }

            const warningText = `${message}<br/><br/>${this.$t(
              'It is recommended to configure valid Internet settings before continuing. Try again?',
            )}`
            this.confirmDialog({
              message: warningText,
              onConfirmYes: () => {
                this.onSave(() => {
                  this.testConnectivity(testType, cb)
                })
              },
              onConfirmNo: () => this.nextPage(),
            })
          }

          this.getInterfaceStatus()
        } catch (error) {
          this.alertDialog(`Unable to complete connectivity test, please try again. Error`)
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },

      async getSettings() {
        try {
          if (this.remote) {
            // If remote and we are here, disable the next button.
            this.nextDisabled = true
            this.remoteTestPassed = true
          }
          this.networkSettings = await this.rpcForAdmin.networkManager.getNetworkSettings()

          const firstWan = this.networkSettings.interfaces.list.find(intf => {
            return intf.isWan && intf.configType !== 'DISABLED'
          })

          this.wan = firstWan

          if (!firstWan) {
            return
          }
          this.getInterfaceStatus()
        } catch (error) {
          this.alertDialog(`Unable to fetch Network Settings. Error: ${error.message || error}`)
        }
      },
      async getInterfaceStatus() {
        try {
          const status = await this.rpcForAdmin.networkManager.getInterfaceStatus(this.wan.interfaceId)
          this.wanStatus = status
        } catch (error) {
          this.alertDialog(`Unable to get WAN status : ${error.message || error}`)
        }
      },

      async renewDhcp() {
        const self = this

        try {
          await this.$store.commit('SET_LOADER', true)
          this.rpcForAdmin.networkManager.setNetworkSettings((response, ex) => {
            if (ex) {
              Util.handleException(self.$t('Unable to set Network Settings.'))
              self.$store.commit('SET_LOADER', false)
              return
            }
            self.$vuntangle.toast.add(self.$t('Renewing DHCP Lease...'))
            self.rpcForAdmin.networkManager.renewDhcpLease((r, e) => {
              if (e) {
                Util.handleException(e)
                self.$store.commit('SET_LOADER', false)
                return
              }
              self.$vuntangle.toast.add(self.$t('DHCP lease renewed successfully.'))
              self.getSettings()
              self.$store.commit('SET_LOADER', false)
            }, self.wan.interfaceId)
          }, self.networkSettings)
        } catch (error) {
          this.alertDialog(`Error during DHCP renewal: ${error.message || error}`)
          this.$store.commit('SET_LOADER', false)
        }
      },
      async nextPage() {
        const currentStepIndex = await this.wizardSteps.indexOf(this.currentStep)
        await Util.updateWizardSettings(this.currentStep)
        await this.setShowStep(this.wizardSteps[currentStepIndex + 1])
        await this.setShowPreviousStep(this.wizardSteps[currentStepIndex + 1])
      },
      async resetWizard() {
        this.$store.commit('SET_LOADER', true)

        try {
          this.rpc.wizardSettings.steps = []
          await this.rpcForAdmin.jsonrpc.UvmContext.setRemoteSetup(false)
          this.rpcForAdmin.jsonrpc.UvmContext.setWizardSettings(this.rpc.wizardSettings)
          window.top.location.href = '/setup/index.do'
        } catch (error) {
          this.alertDialog(`Failed to reset wizard: ${error.message || error}`)
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },
    },
  }
</script>

<style scoped>
  /* Main layout adjustments */
  .main-div {
    /* max-width: 1100px; */
    display: flex;
    flex-direction: column;
    justify-content: flex-start; /* Align content to the top */
    /* align-items: center; */
    padding: 20px;
    justify-content: flex-start;
    border: 1px solid #ccc;
    border-radius: 5px;
    background-color: #f9f9f9;
    font-family: Arial, sans-serif;
    min-height: 600px; /* Ensures the minimum height remains constant */
    max-height: 700px; /* Prevents the height from changing too much */
    height: 700px; /* Set a fixed height to keep the div consistent */
    overflow-y: auto;
    position: relative; /* Ensures children stay within boundary */
  }
  .title {
    text-align: center; /* Center the text */
    color: gray; /* Set text color to gray */
    font-weight: normal; /* Normal font weight for thinner text */
    font-family: 'Roboto', 'Open Sans', 'Lato', Arial, sans-serif; /* Modern font stack */
    margin-bottom: 10px; /* Space below the title */
  }
  .config-label {
    font-size: 16px; /* Set a readable font size */
    font-weight: 600; /* Medium-bold for clarity */
    color: gray; /* Dark gray-blue for a modern UI */
    margin-bottom: 8px; /* Add spacing below the label */
    display: block; /* Ensure it appears above the radio buttons */
    text-transform: capitalize; /* Keep the text looking clean */
    letter-spacing: 0.5px; /* Improve letter spacing for readability */
  }
  .config-type {
    display: flex;
    flex-direction: column; /* Stack label above radio buttons */
    align-items: flex-start; /* Align content to the left */
    text-align: left; /* Ensure text aligns to the left */
    margin-left: 0px;
    margin-bottom: 20px; /* Add spacing below */
    width: 100%; /* Ensure it takes the full width */
  }
  .center-container-renew-button {
    display: flex;
    flex-direction: column; /* Stack text and button vertically */
    justify-content: center; /* Align vertically in the center */
    align-items: center; /* Align horizontally in the center */
    text-align: center; /* Center the text inside */
    height: 100%; /* Ensure it takes full height */
    width: 100%; /* Ensure it takes full width */
    padding: 20px; /* Add some spacing */
  }

  .center-text {
    font-size: 16px;
    font-weight: 500;
    margin-bottom: 10px; /* Space between text and button */
    display: block; /* Ensures text behaves like a block for proper spacing */
  }

  .column-view {
    display: grid;
    grid-template-columns: 1fr 1fr; /* Split into two equal columns */
    align-items: start;
    gap: 10px; /* Reduce gap between columns */
    width: 100%;
  }

  .status-item-details,
  .status-item {
    display: flex;
    justify-content: space-between;
    font: normal tahoma, arial, verdana, sans-serif;
    align-items: center;
    padding: 8px 0;
  }

  .status-item label,
  .status-item-details label {
    width: 150px;
    font-weight: bold;
  }

  .status-item span {
    flex-grow: 1;
    text-align: left;
  }
  .world-icon {
    font-size: 20px; /* Increase size */
  }

  /* Input and Select Field Styling */
  .status-item-details input,
  .status-item-details select,
  .select-Network-content input,
  .select-Network-content select {
    width: 100%;
    padding: 10px;
    border: 1px solid #ccc;
    border-radius: 5px;
    font-size: 14px;
    outline: none;
    transition: border-color 0.3s ease-in-out, box-shadow 0.3s ease-in-out;
  }

  .status-item-details input:focus,
  .status-item-details select:focus,
  .select-Network-content input:focus,
  .select-Network-content select:focus {
    border-color: #007bff;
    box-shadow: 0 0 5px rgba(0, 123, 255, 0.5);
  }

  /* Center align form */
  .select-Network-content {
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding-right: 20px;
  }

  /* Status grid styling */
  .status-grid {
    width: 100%; /* Ensure both divs take full column width */
    padding-right: 0px;
  }

  /* Configuration Radio Button Group */
  .radio-group {
    display: flex;
    justify-content: center;
    gap: 15px;
  }

  .radio-group label {
    display: flex;
    align-items: center;
    gap: 5px;
    cursor: pointer;
    font-size: 14px;
    font-weight: 700;
  }

  .radio-group input {
    cursor: pointer;
  }

  /* Config Types */
  .static-config,
  .auto-config,
  .pppoe-config {
    margin-bottom: 1rem;
  }

  .button-test-connectivity {
    /* padding: 10px 15px; */
    border-radius: 5px;
    display: flex;
    color: white;
    font-size: 14px;
    cursor: pointer;
    transition: background-color 0.3s ease-in-out, transform 0.2s ease-in-out;
  }

  /* Button Styling */
  .button-margin {
    display: flex;
    justify-content: left; /* Center the button horizontally */
    align-items: center; /* Center the button vertically */
  }
  .renew-button {
    display: flex; /* Enable flexbox for the button content */
    align-items: center; /* Vertically align the text and icon */
    justify-content: center; /* Center the text and icon horizontally */
    padding: 10px 20px; /* Adjust padding for better spacing */
    border-radius: 5px; /* Rounded corners */
    font-size: 14px; /* Font size for button text */
    border: 1px solid #ccc; /* Optional: Add a border for better visibility */
    background-color: #f5f5f5; /* Light background for the button */
    color: #333; /* Dark text color */
    cursor: pointer; /* Pointer cursor on hover */
    transition: background-color 0.3s ease-in-out, transform 0.2s ease-in-out;
    width: 400px; /* Increase width further */
  }
  .button-test-connectivity {
    display: flex; /* Enable flexbox for the button content */
    align-items: center; /* Vertically align the text and icon */
    justify-content: center; /* Center the text and icon horizontally */
    padding: 10px 20px; /* Adjust padding for better spacing */
    border-radius: 5px; /* Rounded corners */
    font-size: 14px; /* Font size for button text */
    cursor: pointer; /* Pointer cursor on hover */
    transition: background-color 0.3s ease-in-out, transform 0.2s ease-in-out;
  }

  .renew-button:hover {
    background-color: #e0e0e0; /* Slightly darker background on hover */
  }

  .renew-button v-icon {
    margin-right: 8px; /* Add spacing between the icon and text */
    font-size: 18px; /* Icon size */
  }

  .button-margin .renew-button:hover,
  .button-container u-btn:hover {
    transform: scale(1.05);
  }

  /* Button Container */
  .button-container {
    display: flex;
    justify-content: space-between; /* Places Back & Next at extreme left & right */
    align-items: center;
    width: 100%;
    position: absolute;
    bottom: 20px; /* Keeps it at a fixed position from bottom */
    left: 0;
    padding: 10px 20px; /* Adds padding for spacing */

    /* background-color: #f9f9f9; */
  }

  .no-internet {
    margin-bottom: 15px;
    font-size: smaller;
  }
  .step-title {
    font-family: 'Roboto Condensed', sans-serif;
    font-weight: 100;
    color: #999;
    font-size: 36px;
  }
  .sectionheader {
    font-family: 'Roboto Condensed', sans-serif;
    font-size: 20px;
    color: #555;
  }
</style>
