<template>
  <v-card width="900" class="mx-auto ma-2" flat>
    <SetupLayout />

    <div
      class="pa-3 mt-4 mx-auto grey lighten-4 border rounded d-flex flex-column position-relative"
      style="width: 100%; min-height: 500px; border: 1px solid #e0e0e0 !important"
    >
      <h1 class="font-weight-light faint-color text-h4 ma-2">Configure the Internet Connection</h1>
      <div v-if="!remoteReachable" class="red--text text--darken-2 ml-2">
        <p>No Internet Connection..! Click on 'Test Connectivity' to verify.</p>
      </div>
      <v-container class="flex-grow-1">
        <div v-if="wan">
          <ValidationObserver v-slot="{ passes }">
            <div>
              <span class="text-h6 font-weight-medium grey--text text--darken-2 ma-0 pa-0">Configuration Type</span>

              <v-radio-group v-model="wan.v4ConfigType" row class="d-flex justify-center ga-3 mt-0">
                <v-radio label="Auto (DHCP)" value="AUTO" class="font-weight-medium text-body-2"></v-radio>

                <v-radio label="Static" value="STATIC" class="font-weight-medium text-body-2"></v-radio>

                <v-radio label="PPPoE" value="PPPOE" class="font-weight-medium text-body-2"></v-radio>
              </v-radio-group>
            </div>
            <v-row>
              <v-col cols="12" md="6">
                <div>
                  <div v-if="wan.v4ConfigType === 'STATIC'">
                    <ValidationProvider v-slot="{ errors }" :rules="{ required: true, ip: true }">
                      <v-card-text class="pa-0 mt-2">IP Address:</v-card-text>

                      <u-text-field v-model="wan.v4StaticAddress" :error-messages="errors">
                        <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                      </u-text-field>
                    </ValidationProvider>
                    <ValidationProvider v-slot="{ errors }" rules="required">
                      <v-card-text class="pa-0 mt-2">Netmask:</v-card-text>
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
                      <v-card-text class="pa-0 mt-2">Gateway:</v-card-text>
                      <u-text-field v-model="wan.v4StaticGateway" :error-messages="errors">
                        <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                      </u-text-field>
                    </ValidationProvider>

                    <ValidationProvider v-slot="{ errors }" :rules="{ required: true, ip: true }">
                      <v-card-text class="pa-0 mt-2">Primary DNS:</v-card-text>
                      <u-text-field v-model="wan.v4StaticDns1" :error-messages="errors">
                        <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                      </u-text-field>
                    </ValidationProvider>

                    <ValidationProvider v-slot="{ errors }" :rules="{ ip: true }">
                      <v-card-text class="pa-0 mt-2">Secondary DNS (optional):</v-card-text>
                      <u-text-field v-model="wan.v4StaticDns2" :error-messages="errors">
                        <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                      </u-text-field>
                    </ValidationProvider>
                  </div>

                  <div v-if="wan.v4ConfigType === 'AUTO'">
                    <div>
                      <u-btn
                        :small="false"
                        class="font-weight-bold px-4 py-2 text--darken-4 w-100"
                        :disabled="loading"
                        @click="renewDhcp"
                      >
                        <v-icon left>mdi-autorenew</v-icon> Renew DHCP
                      </u-btn>
                    </div>
                  </div>

                  <div v-if="wan.v4ConfigType === 'PPPOE'">
                    <ValidationProvider v-slot="{ errors }" :rules="{ required: true }">
                      <v-card-text class="ma-0 pa-0">User Name:</v-card-text>
                      <u-text-field v-model="wan.v4PPPoEUsername" :error-messages="errors">
                        <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                      </u-text-field>
                    </ValidationProvider>

                    <ValidationProvider v-slot="{ errors }" :rules="{ required: true, min: 3 }">
                      <v-card-text class="mt-2 pa-0"> Password:</v-card-text>
                      <u-password v-model="wan.v4PPPoEPassword" :error-messages="errors" :errors="errors">
                        <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                      </u-password>
                    </ValidationProvider>
                  </div>
                </div>
              </v-col>

              <v-col cols="12" md="6">
                <div class="d-flex flex-column">
                  <p class="text-h6 font-weight-medium grey--text text--darken-2">Status:</p>

                  <div class="d-flex flex-column">
                    <div class="d-flex align-center mb-4">
                      <div class="font-weight-bold grey--text text--darken-3" style="min-width: 120px">IP Address:</div>
                      <span class="ml-2">{{ wanStatus.v4Address }}</span>
                    </div>

                    <div class="d-flex align-center mb-4">
                      <div class="font-weight-bold grey--text text--darken-3" style="min-width: 120px">Netmask:</div>
                      <span class="ml-2">/ {{ wanStatus.v4PrefixLength }} - {{ wanStatus.v4Netmask }}</span>
                    </div>

                    <div class="d-flex align-center mb-4">
                      <div class="font-weight-bold grey--text text--darken-3" style="min-width: 120px">Gateway:</div>
                      <span class="ml-2">{{ wanStatus.v4Gateway }}</span>
                    </div>

                    <div class="d-flex align-center mb-4">
                      <div class="font-weight-bold grey--text text--darken-3" style="min-width: 120px">
                        Primary DNS:
                      </div>
                      <span class="ml-2">{{ wanStatus.v4Dns1 }}</span>
                    </div>

                    <div class="d-flex align-center mb-4">
                      <div class="font-weight-bold grey--text text--darken-3" style="min-width: 120px">
                        Secondary DNS:
                      </div>
                      <span class="ml-2">{{ wanStatus.v4Dns2 }}</span>
                    </div>

                    <div class="mt-3">
                      <u-btn :small="false" @click="passes(() => onSave('testConnectivity'))">
                        <v-icon class="world-icon mr-2">mdi-earth</v-icon> Test Connectivity
                      </u-btn>
                    </div>
                  </div>
                </div>
              </v-col>
            </v-row>
            <br />
            <div v-if="!nextDisabled" class="d-flex justify-space-between pa-4">
              <u-btn :small="false" style="margin: 8px 0" @click="onClickBack">{{ `Back` }}</u-btn>
              <u-btn :small="false" style="margin: 8px 0" @click="passes(() => onSave('save'))">{{ `Next` }}</u-btn>
            </div>
          </ValidationObserver>
        </div>
        <!-- In Remote mode, allow Local as a backup if Internet fails.  Disabled by default. -->
        <div
          v-if="!remoteTestPassed"
          class="d-flex flex-column justify-center align-center text-center"
          style="height: 100%"
        >
          <span class="mb-4">
            You may continue configuring your Internet connection or run the Setup Wizard locally
          </span>
          <u-btn :small="false" :disabled="loading" @click="resetWizard">
            <v-icon left>mdi-autorenew</v-icon> Run Setup Wizard Locally
          </u-btn>
        </div>

        <v-dialog v-model="dialog" persistent max-width="290px">
          <v-card>
            <v-card-title>Warning!</v-card-title>
            <v-card-text>No internal interfaces found. Do you want to continue the setup?</v-card-text>
            <v-card-actions class="justify-end">
              <v-btn class="green--text text--darken-1" text @click="onConfirm">Yes</v-btn>
              <v-btn class="red--text text--darken-1" text @click="onCancel">No</v-btn>
            </v-card-actions>
          </v-card>
        </v-dialog>
      </v-container>
    </div>
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
            this.rpcForAdmin = Util.setRpcJsonrpc('admin')
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