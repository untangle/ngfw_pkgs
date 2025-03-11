<template>
  <v-card width="900" height="auto" class="mx-auto mt-4" flat>
    <SetupLayout />
    <v-container class="main-div">
      <div class="step-title">Configure the Internet Connection</div>
      <div v-if="!remoteReachable" class="warning-message">
        <p>No Internet Connection..! Click on 'Test Connectivity' to verify.</p>
      </div>
      <div v-if="wan">
        <ValidationObserver v-slot="{ passes }">
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
              <div v-if="wan.v4ConfigType === 'STATIC'" class="auto-config">
                <ValidationProvider v-slot="{ errors }" :rules="{ required: true, ip: true }">
                  <label>IP Address:</label>

                  <u-text-field v-model="wan.v4StaticAddress" :error-messages="errors">
                    <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                  </u-text-field>
                </ValidationProvider>
                <ValidationProvider v-slot="{ errors }" rules="required">
                  <label>Netmask:</label>
                  <v-autocomplete
                    v-model="v4StaticPrefixModel"
                    :items="v4NetmaskList"
                    outlined
                    dense
                    hide-details
                    return-object
                    :error-messages="errors"
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

              <div v-if="wan.v4ConfigType === 'AUTO'" class="auto-config">
                <div class="button-margin">
                  <u-btn :small="false" class="renew-button" :disabled="loading" @click="renewDhcp">
                    <v-icon left>mdi-autorenew</v-icon> Renew DHCP
                  </u-btn>
                </div>
              </div>

              <div v-if="wan.v4ConfigType === 'PPPOE'">
                <ValidationProvider v-slot="{ errors }" :rules="{ required: true }">
                  <label>User Name:</label>
                  <u-text-field v-model="wan.v4PPPoEUsername" :error-messages="errors">
                    <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                  </u-text-field>
                </ValidationProvider>

                <ValidationProvider v-slot="{ errors }" :rules="{ required: true, min: 3 }">
                  <label>Password:</label>
                  <u-password v-model="wan.v4PPPoEPassword" :error-messages="errors" :errors="errors">
                    <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                  </u-password>
                </ValidationProvider>
              </div>
            </div>
            <div class="status-grid">
              <p class="sectionheader">Status:</p>
              <div class="status-item">
                <label>IP Address: </label>
                <span>{{ wanStatus.v4Address }}</span>
              </div>
              <div class="status-item">
                <label>Netmask: </label>
                <span>/ {{ wanStatus.v4PrefixLength }} - {{ wanStatus.v4Netmask }}</span>
              </div>
              <div class="status-item">
                <label>Gateway: </label>
                <span>{{ wanStatus.v4Gateway }}</span>
              </div>
              <div class="status-item">
                <label>Primary DNS: </label>
                <span>{{ wanStatus.v4Dns1 }}</span>
              </div>
              <div class="status-item">
                <label>Secondary DNS: </label>
                <span>{{ wanStatus.v4Dns2 }}</span>
              </div>
              <div>
                <u-btn
                  :small="false"
                  class="button-test-connectivity"
                  @click="passes(() => onSave('testConnectivity'))"
                >
                  <v-icon class="world-icon mr-2">mdi-earth</v-icon> Test Connectivity
                </u-btn>
              </div>
            </div>
          </div>
          <br />
          <div class="custom-margin">
            <div v-if="!nextDisabled" class="button-container">
              <u-btn :small="false" style="margin: 8px 0" @click="onClickBack">Back</u-btn>
              <u-btn :small="false" style="margin: 8px 0" @click="passes(() => onSave('save'))">Next</u-btn>
            </div>
          </div>
        </ValidationObserver>
      </div>
      <!-- In Remote mode, allow Local as a backup if Internet fails.  Disabled by default. -->
      <div v-if="!remoteTestPassed" class="button-container">
        <div class="center-container-renew-button">
          <span class="center-text">
            You may continue configuring your Internet connection or run the Setup Wizard locally
          </span>
          <u-btn :small="false" class="renew-button" :disabled="loading" @click="resetWizard">
            <v-icon left>mdi-autorenew</v-icon> Run Setup Wizard Locally
          </u-btn>
        </div>
      </div>
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

  export default {
    name: 'Internet',
    components: {
      SetupLayout,
    },
    data() {
      return {
        remoteReachable: false,
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
      ...mapGetters('setup', ['wizardSteps', 'currentStep', 'previousStep']),
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
        try {
          // build test fail message if any
          let message = ''
          let nextDisabled = true
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
            const rpcSetup = Util.setRpcJsonrpc('setup')
            this.remoteReachable = rpcSetup.jsonrpc.SetupContext.getRemoteReachable()
            const adminRpc = Util.setRpcJsonrpc('admin')
            if (adminRpc) {
              this.rpcForAdmin = adminRpc
            }
            if (this.remoteReachable) {
              message = 'Unable to reach ETM Dashboard!'
            } else {
              nextDisabled = false
            }
          } else {
            message = null
            nextDisabled = false
          }
          if (this.remote) {
            this.nextDisabled = nextDisabled
          }

          if (this.remote && message !== null) {
            this.remoteTestPassed = false
            message = 'You may continue configuring your Internet connection or run the Setup Wizard locally.'
          }

          if (testType === 'manual') {
            // on manual test just show the message
            this.alertDialog(message || 'Success!')
          } else {
            // on next step just move forward if no failures
            if (!message) {
              cb()
              this.nextPage()
              return
            }

            // otherwise show a warning message
            const warningText = `${message}<br/><br/>${this.$t(
              'It is recommended to configure valid Internet settings before continuing. Try again?',
            )}`
            this.confirmDialog({
              message: warningText,
              onConfirmYes: () => {
                // Do nothing
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
          // save settings before
          self.$vuntangle.toast.add(self.$t('Saving settings ...'))
          this.rpcForAdmin.networkManager.setNetworkSettings((response, ex) => {
            if (ex) {
              Util.handleException(self.$t('Unable to set Network Settings.'))
              self.$store.commit('SET_LOADER', false)
              return
            }
            // then force the DHCP lease renew just in case
            // setNetworkSettings is not guaranteed to restart networking
            self.$vuntangle.toast.add(self.$t('Renewing DHCP Lease...'))
            self.rpcForAdmin.networkManager.renewDhcpLease((r, e) => {
              if (e) {
                Util.handleException(e)
                self.$store.commit('SET_LOADER', false)
                return
              }
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
  .main-div {
    display: flex;
    flex-direction: column;
    justify-content: flex-start;
    padding: 20px;
    justify-content: flex-start;
    border: 1px solid #ccc;
    border-radius: 5px;
    background-color: #f9f9f9;
    font-family: Arial, sans-serif;
    min-height: 600px;
    max-height: 700px;
    height: 700px;
    overflow-y: auto;
    position: relative;
  }
  .title {
    text-align: center;
    color: gray;
    font-weight: normal;
    font-family: 'Roboto', 'Open Sans', 'Lato', Arial, sans-serif;
    margin-bottom: 10px;
  }
  .config-label {
    font-size: 16px;
    font-weight: 600;
    color: gray;
    margin-bottom: 8px;
    display: block;
    text-transform: capitalize;
    letter-spacing: 0.5px;
  }
  .config-type {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    text-align: left;
    margin-left: 0px;
    margin-bottom: 20px;
    width: 100%;
  }
  .center-container-renew-button {
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    text-align: center;
    height: 100%;
    width: 100%;
    padding: 20px;
  }

  .center-text {
    font-size: 16px;
    font-weight: 500;
    margin-bottom: 10px;
    display: block;
  }

  .column-view {
    display: grid;
    grid-template-columns: 1fr 1fr;
    align-items: start;
    gap: 10px;
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
    margin-top: -8px;
  }
  .world-icon {
    font-size: 20px;
  }

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

  .select-Network-content {
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding-right: 20px;
  }

  .status-grid {
    width: 100%;
    padding-right: 0px;
  }

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

  .static-config,
  .auto-config,
  .pppoe-config {
    margin-bottom: 1rem;
  }

  .button-test-connectivity {
    border-radius: 5px;
    display: flex;
    color: white;
    font-size: 14px;
    cursor: pointer;
    transition: background-color 0.3s ease-in-out, transform 0.2s ease-in-out;
  }

  .button-margin {
    display: flex;
    justify-content: left;
    align-items: center;
  }
  .renew-button {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 10px 20px;
    border-radius: 5px;
    font-size: 14px;
    border: 1px solid #ccc;
    background-color: #f5f5f5;
    color: #333;
    cursor: pointer;
    transition: background-color 0.3s ease-in-out, transform 0.2s ease-in-out;
    width: 400px;
  }
  .button-test-connectivity {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 10px 20px;
    border-radius: 5px;
    font-size: 14px;
    cursor: pointer;
    transition: background-color 0.3s ease-in-out, transform 0.2s ease-in-out;
  }

  .renew-button:hover {
    background-color: #e0e0e0;
  }

  .renew-button v-icon {
    margin-right: 8px;
    font-size: 18px;
  }

  .button-margin .renew-button:hover,
  .button-container u-btn:hover {
    transform: scale(1.05);
  }

  .button-container {
    display: flex;
    justify-content: space-between;
    align-items: center;
    width: 100%;
    position: absolute;
    bottom: 20px;
    left: 0;
    padding: 10px 20px;
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
