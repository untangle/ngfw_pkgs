<template>
  <v-card width="900" class="mx-auto ma-2" flat>
    <SetupLayout />

    <div
      class="pa-3 mt-4 mx-auto grey lighten-4 border rounded d-flex flex-column position-relative"
      style="width: 100%; min-height: 500px; border: 1px solid #e0e0e0 !important"
    >
      <h1 class="font-weight-light faint-color text-h4 ma-2">{{ description }}</h1>
      <v-container class="flex-grow-1">
        <v-row no-gutters>
          <v-col cols="auto">
            <v-radio-group v-model="internal.configType" column dense @change="setConfigType">
              <v-radio value="ADDRESSED">
                <template #label>
                  <span class="font-weight-medium text-h6 mt-3">{{ $t('Router') }}</span>
                </template>
              </v-radio>

              <v-row class="align-center" no-gutters>
                <v-col cols="8">
                  <p class="font-weight-light ml-8">
                    This is recommended if the external port is plugged into the internet connection. This enables NAT
                    and DHCP.
                  </p>
                </v-col>
                <v-col cols="4" class="mt-2">
                  <v-img src="/skins/simple-gray/images/admin/wizard/router.png" max-width="200"></v-img>
                </v-col>
              </v-row>

              <v-row class="align-center d-flex" no-gutters>
                <v-col cols="auto"
                  ><span class="font-weight-medium faint-color text-h7 ml-8">Internal Address :</span></v-col
                >
                <v-col cols="4" class="ml-2">
                  <u-text-field
                    v-model="internal.v4StaticAddress"
                    type="text"
                    :disabled="internal.configType !== 'ADDRESSED'"
                  />
                </v-col>
              </v-row>

              <v-row class="align-center d-flex mb-2" no-gutters>
                <v-col cols="auto"><span class="font-weight-medium faint-color ml-8">Internal Netmask :</span></v-col>
                <v-col cols="4" class="ml-1">
                  <v-autocomplete
                    v-model="internal.v4StaticPrefix"
                    :items="v4NetmaskList"
                    :disabled="internal.configType !== 'ADDRESSED'"
                    outlined
                    dense
                    hide-details
                    return-object
                  ></v-autocomplete>
                </v-col>
              </v-row>
              <v-radio-group
                v-model="internal.dhcpType"
                class="d-flex align-items-center ma-0"
                row
                dense
                :disabled="internal.configType !== 'ADDRESSED'"
              >
                <span class="font-weight-bold mr-4 ml-8">DHCP Server :</span>
                <v-row class="d-flex flex-column ml-16">
                  <v-col cols="auto" class="ml-16"
                    ><v-radio value="SERVER" class="mt-0">
                      <template #label>
                        <span class="font-weight-bold mt-2">{{ $t('Enabled') }}</span>
                      </template>
                    </v-radio></v-col
                  >
                  <v-col cols="auto" class="ml-16"
                    ><v-radio value="DISABLED" class="mt-0">
                      <template #label>
                        <span class="font-weight-bold mt-2">{{ $t('Disabled') }}</span>
                      </template>
                    </v-radio></v-col
                  >
                </v-row>
              </v-radio-group>

              <v-radio value="BRIDGED">
                <template #label>
                  <span class="font-weight-medium text-h6 mt-3">{{ $t('Transparent Bridge') }}</span>
                </template>
              </v-radio>

              <v-row class="align-center">
                <v-col cols="8">
                  <p class="font-weight-light ml-8">
                    This is recommended if the external port is plugged into a firewall/router. This bridges Internal
                    and External and disables DHCP.
                  </p>
                </v-col>
                <v-col cols="4">
                  <v-img src="/skins/simple-gray/images/admin/wizard/bridge.png" max-width="200"></v-img>
                </v-col>
              </v-row>
            </v-radio-group>
          </v-col>
        </v-row>
        <div class="d-flex justify-space-between pa-4" style="position: relative">
          <u-btn :small="false" @click="onClickBack">{{ `Back` }}</u-btn>
          <u-btn :small="false" @click="onSave">{{ `Next` }}</u-btn>
        </div>
      </v-container>
    </div>

    <!-- Dialogs -->
    <v-dialog v-model="loading" persistent max-width="500">
      <v-card class="pa-4 text-center">
        <h2 class="text-h6">Saving Internal Network Settings...</h2>
        <p>The Internal Address is no longer accessible.</p>
        <p>
          You will be redirected to the new setup address:
          <a :href="newSetupLocation" target="_blank" class="blue--text">{{ newSetupLocation }}</a>
        </p>
        <p class="text-body-2">
          If the new location is not loaded after 30 seconds, reinitialize your local network address and try again.
        </p>
      </v-card>
    </v-dialog>

    <v-dialog v-model="loadingForChangeAddress" persistent max-width="500">
      <v-card class="pa-4 text-center">
        <h2 class="text-h6">Saving Internal Network Settings...</h2>
        <p>The Internal Address has changed to: {{ internal.v4StaticAddress }}</p>
        <p>
          You will be redirected to:
          <a :href="newSetupLocation" target="_blank" class="blue--text">{{ newSetupLocation }}</a>
        </p>
      </v-card>
    </v-dialog>

    <v-dialog v-model="dialog" persistent max-width="290">
      <v-card>
        <v-card-title class="headline">Warning!</v-card-title>
        <v-card-text>No internal interfaces found. Do you want to continue the setup?</v-card-text>
        <v-card-actions>
          <v-btn color="green" text @click="onConfirm">Yes</v-btn>
          <v-btn color="red" text @click="onCancel">No</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-dialog v-model="warningDiaglog" max-width="400">
      <v-card>
        <v-card-title class="headline"></v-card-title>
        <v-card-text></v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn color="primary" text @click="closeWarningDialog">OK</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-card>
</template>

<script>
  import { mapActions, mapGetters } from 'vuex'
  import Util from '@/util/setupUtil'
  import SetupLayout from '@/layouts/SetupLayout.vue'
  import AlertDialog from '@/components/Reusable/AlertDialog.vue'

  export default {
    name: 'InternalNetwork',
    components: {
      SetupLayout,
    },
    data() {
      return {
        isLoading: false,
        title: 'Internal Network',
        description: 'Configure the Internal Network Interface',
        interfaces: [],
        internal: {
          configType: 'ADDRESSED',
          v4ConfigType: null,
          v4StaticAddress: '192.168.1.1',
          v4StaticPrefix: null,
          dhcpType: null,
        },
        networkSettings: null,
        v4NetmaskList: Util.v4NetmaskList.map(n => ({ value: n[0], text: n[1] })),
        newSetupLocation: null,
        loading: false,
        loadingForChangeAddress: false,
        timeout: 30000,
        dialog: false,
        warningDiaglog: false,
        isProcessing: false,
      }
    },

    created() {
      this.getInterface()
    },
    computed: {
      ...mapGetters('setup', ['wizardSteps', 'currentStep', 'previousStep']), // from Vuex
    },

    methods: {
      ...mapActions('setup', ['setShowStep']),
      ...mapActions('setup', ['setShowPreviousStep']),

      showDialog() {
        this.dialog = true
      },
      onConfirm() {
        this.dialog = false
        this.nextPage()
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
      onCancel() {
        this.dialog = false
      },
      setConfigType(radio) {
        if (radio === 'BRIDGED') {
          this.internal.configType = 'BRIDGED'
        } else {
          this.internal.configType = 'ADDRESSED'
          this.internal.v4ConfigType = 'STATIC'
        }
      },
      async getInterface() {
        try {
          const rpc = Util.setRpcJsonrpc('admin')
          this.networkSettings = await rpc?.networkManager?.getNetworkSettings()
          this.interfaces = this.networkSettings.interfaces.list

          this.internal = this.interfaces.find(intf => !intf.isWan)

          if (!this.internal) {
            this.showDialog()
          } else {
            this.initialConfigType = this.internal.configType
            this.initialv4Address = this.internal.v4StaticAddress
            this.initialv4Prefix = this.internal.v4StaticPrefix
            this.initialDhcpType = this.internal.dhcpType
          }
        } catch (error) {
          this.alertDialog(`Failed to fetch device settings: ${error.message || error}`)
        }
      },
      async onClickBack() {
        try {
          await Promise.resolve()
          const currentStepIndex = this.wizardSteps.indexOf(this.currentStep)
          await this.setShowStep(this.wizardSteps[currentStepIndex - 1])
        } catch (error) {
          this.alertDialog(`Failed to navigate: ${error.message || error}`)
        }
      },
      async onSave() {
        const adminRpc = Util.setRpcJsonrpc('admin')
        this.$store.commit('SET_LOADER', true)
        let shouldNavigate = true // Flag to manage navigation
        try {
          // setting the v4StaticPrefix
          if (this.internal.v4StaticPrefix && this.internal.v4StaticPrefix.value) {
            this.internal.v4StaticPrefix = this.internal.v4StaticPrefix.value
          }
          // no changes made - continue to next step
          if (
            this.initialConfigType === this.internal.configType &&
            this.initialv4Address === this.internal.v4StaticAddress &&
            this.initialv4Prefix === this.internal.v4StaticPrefix &&
            this.initialDhcpType === this.internal.dhcpType
          ) {
            shouldNavigate = true
          }
          // BRIDGED (bridge mode)
          if (this.internal.configType === 'BRIDGED') {
            this.loading = true
            // If using internal address - redirect to external since internal address is vanishing
            if (this.internal.v4StaticAddress === window.location.hostname) {
              // warnAboutDisappearingAddress
              let firstWan = ''
              let firstWanStatus = ''
              // get firstWan settings & status
              firstWan = this.networkSettings.interfaces.list.find(intf => intf.isWan && intf.configType !== 'DISABLED')

              // firstWan must exist
              if (!firstWan || !firstWan.interfaceId) {
                return
              }
              try {
                firstWanStatus = await adminRpc?.networkManager.getInterfaceStatus(firstWan.interfaceId)
              } catch (e) {
                Util.handleException(e)
              }

              // and the first WAN has a address
              if (!firstWanStatus || !firstWanStatus.v4Address) {
                return
              }
              // Use Internal Address instead of External Address
              this.newSetupLocation = window.location.href.replace(
                this.internal.v4StaticAddress,
                firstWanStatus.v4Address,
              )
              await this.simulateRpcCall()
              window.top.location.href = this.newSetupLocation
              shouldNavigate = false
            }
          } else {
            // ADDRESSED (router)
            // set these to null so new values will automatically be calculated based on current address
            this.internal.dhcpRangeStart = null
            this.internal.dhcpRangeEnd = null
            // If using internal address and it is changed in this step redirect to new internal address
            if (
              window.location.hostname === this.initialv4Address &&
              this.initialv4Address !== this.internal.v4StaticAddress
            ) {
              // warnAboutChangingAddress
              this.newSetupLocation = await window.location.href.replace(
                this.initialv4Address,
                this.internal.v4StaticAddress,
              )
              this.loadingForChangeAddress = true
              await this.simulateRpcCall()
              window.top.location.href = this.newSetupLocation
              shouldNavigate = false
            }
          }

          // save settings and continue to next step
          await new Promise((resolve, reject) => {
            adminRpc?.networkManager.setNetworkSettings((response, ex) => {
              if (ex) {
                Util.handleException(ex)
                reject(ex)
              } else {
                resolve(response)
              }
            }, this.networkSettings)
          })
          if (shouldNavigate) {
            this.nextPage()
          }
        } catch (error) {
          this.$store.commit('SET_LOADER', false)
          this.alertDialog(`Error during save operation: ${error.message || error}`)
        } finally {
          this.$store.commit('SET_LOADER', false)
          this.loading = false
          this.loadingForChangeAddress = false
        }
      },
      // This is a simulated async RPC call to mimic a delay (e.g., an API request)
      simulateRpcCall() {
        return new Promise(resolve => {
          setTimeout(() => {
            resolve('Data saved')
          }, this.timeout)
        })
      },
      async nextPage() {
        if (this.isProcessing) return
        this.isProcessing = true

        try {
          const currentStepIndex = this.wizardSteps.indexOf(this.currentStep)

          if (this.wizardSteps[currentStepIndex + 1]) {
            await Util.updateWizardSettings(this.currentStep)
            await this.setShowStep(this.wizardSteps[currentStepIndex + 1])
            await this.setShowPreviousStep(this.wizardSteps[currentStepIndex + 1])
          } else {
            this.$vuntangle.toast.add(this.$t(`No next step available`))
          }
        } catch (error) {
          this.$vuntangle.toast.add(this.$t(`Error while navigating to next step: ${error || error.message}`))
        } finally {
          this.isProcessing = false // Reset flag after processing is complete
        }
      },
    },
  }
</script>
