<template>
  <v-card width="1100" height="auto" class="mx-auto mt-4" flat>
    <SetupLayout />
    <v-container class="main-div">
      <h1
        style="
          text-align: left;
          color: gray;
          font-weight: normal;
          font-family: 'Roboto', 'Open Sans', 'Lato', Arial, sans-serif;
          /* margin-bottom: 10px; */
        "
      >
        Configure the Internet Connection
      </h1>
      <p class="no-internet">No Internet Connection! Click on 'Test Connectivity' to verify.</p>

      <div v-if="wan">
        <ValidationObserver v-slot="{ passes, invalid }">
          <!-- Configuration Type Radio Buttons in Single Line -->
          <v-form>
            <div class="config-type">
              <label class="config-label">Configuration Type</label>
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
                      v-model="wan.v4StaticPrefix"
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
                <p class="config-label">Status:</p>
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
                <div class="button-test-connectivity">
                  <u-btn :small="false" class="renew-button" @click="testConnectivity">
                    <v-icon class="world-icon">mdi-earth</v-icon> Test Connectivity
                  </u-btn>
                </div>
              </div>
            </div>
            <!-- <div class="button-test-connectivity">
              <u-btn :small="false" class="renew-button" @click="testConnectivity">
                <v-icon class="world-icon">mdi-earth</v-icon> Test Connectivity
              </u-btn>
            </div> -->
            <div class="button-container">
              <u-btn :small="false" style="margin: 8px 0" @click="onClickBack">Back</u-btn>
              <u-btn :small="false" style="margin: 8px 0" :disabled="invalid" @click="passes(onSave)">Next</u-btn>
            </div>
          </v-form>
        </ValidationObserver>
      </div>

      <!-- Warning Dialog -->
      <v-dialog v-model="showDialog" max-width="400">
        <v-card>
          <v-card-title class="headline">Internet Status</v-card-title>
          <v-card-text>
            {{ dialogMessage }}
          </v-card-text>
          <v-card-actions>
            <v-spacer></v-spacer>
            <v-btn color="primary" text @click="closeDialog">OK</v-btn>
          </v-card-actions>
        </v-card>
      </v-dialog>
    </v-container>
  </v-card>
</template>

<script>
  import { mapActions } from 'vuex'
  import SetupLayout from '@/layouts/SetupLayout.vue'
  import Util from '@/util/setupUtil'
  export default {
    name: 'Internet',
    components: {
      SetupLayout,
    },
    data() {
      return {
        isRemoteReachable: null,
        wan: {},
        wanStatus: {},
        networkSettings: null,
        v4NetmaskList: Util.v4NetmaskList.map(n => ({ value: n[0], text: n[1] })),
        loading: false,
        showDialog: false,
        dialogMessage: '',
      }
    },
    computed: {
      passwordRequired() {
        return this.$store.state.setup?.status?.step ? this.$store.state.setup?.status.step === 'system' : true
      },
    },
    mounted() {
      // console.log('v4NetmaskList', this.v4NetmaskList)
      // console.log('getV4NetmaskList', Util.getV4NetmaskList)
      this.checkRemoteReachability()
      this.getSettings()
      // console.log('this.wan', this.wan)
    },
    methods: {
      ...mapActions('setup', ['setShowStep']),
      ...mapActions('setup', ['setShowPreviousStep']),
      async onClickBack() {
        try {
          await this.setShowStep('Network')
          await this.setShowPreviousStep('Network')
        } catch (error) {
          console.error('Failed to navigate:', error)
        }
      },

      async onSave(cb) {
        console.log('Saving network settings...')
        console.log('on Save function running')
        if (!this.wan) {
          cb()
          return
        }
        // Modify WAN settings based on configuration type
        if (this.wan.v4ConfigType === 'AUTO' || this.wan.v4ConfigType === 'PPPOE') {
          Object.assign(this.wan, {
            v4StaticAddress: null,
            v4StaticPrefix: null,
            v4StaticGateway: null,
            v4StaticDns1: null,
            v4StaticDns2: null,
          })
        }
        if (this.wan.v4ConfigType === 'STATIC') {
          this.wan.v4NatEgressTraffic = true
          this.wan.v4StaticPrefix = this.wan.v4StaticPrefix.value
        }
        if (this.wan.v4ConfigType === 'PPPOE') {
          this.wan.v4NatEgressTraffic = true
          this.wan.v4PPPoEUsePeerDns = true
        }

        this.loading = true // Start loading state

        try {
          this.loading = true // Indicate loading state

          const rpcResponseForSetup = await Util.setRpcJsonrpc('admin')

          console.log('Settings saved. Testing connectivity...')
          this.showWarning('Settings saved. Testing connectivity...')

          await this.testConnectivity()
          // Now run setNetworkSettings after testConnectivity completes
          await rpcResponseForSetup.networkManager.setNetworkSettings(() => {
            this.setShowStep('Interface')
            this.setShowPreviousStep('Interface')
          }, this.networkSettings)
        } catch (error) {
          console.error('Error saving settings:', error)
          this.showWarning('Unable to save network settings. Please try again.')
        } finally {
          this.loading = false // Ensure loading state is turned off after execution
        }
      },
      checkRemoteReachability() {
        // Simulate checking remote reachability
        this.isRemoteReachable = true // Example value
      },
      async testConnectivity() {
        console.log('Testing connectivity...')
        this.showWarning('Testing connectivity...')
        this.loading = true
        try {
          const rpcResponseForSetup = await Util.setRpcJsonrpc('admin')
          console.log('rpcResponseForSetup', rpcResponseForSetup)
          const result = await rpcResponseForSetup.connectivityTester.getStatus()
          console.log('result', result)
          if (result.tcpWorking === false && result.dnsWorking === false) {
            this.showWarning('Warning! Internet tests and DNS tests failed.')
          } else if (result.tcpWorking === false) {
            this.showWarning('Warning! DNS tests succeeded, but Internet tests failed.')
          } else if (result.dnsWorking === false) {
            this.showWarning('Warning! Internet tests succeeded, but DNS tests failed.')
          } else {
            this.showWarning('Success..')
          }
        } catch (error) {
          console.error('Connectivity test failed:', error)
          this.showWarning('Unable to complete connectivity test, please try again.')
        } finally {
          this.loading = false
        }
      },
      showWarning(message) {
        this.dialogMessage = message
        this.showDialog = true
      },
      closeDialog() {
        this.showDialog = false
      },

      async getSettings() {
        console.log('Fetching network settings...')
        try {
          const rpcResponseForSetup = await Util.setRpcJsonrpc('admin')
          this.networkSettings = await rpcResponseForSetup.networkManager.getNetworkSettings()
          console.log('Network settings:', this.networkSettings)

          const firstWan = this.networkSettings.interfaces.list.find(intf => {
            return intf.isWan && intf.configType !== 'DISABLED'
          })

          this.wan = firstWan
          console.log('this.wan', this.wan)

          if (!firstWan) {
            return
          }
          this.getInterfaceStatus()
        } catch (error) {
          console.error('Unable to fetch Network Settings:', error)
          this.showWarning('Unable to fetch Network Settings.')
        }
      },
      async getInterfaceStatus() {
        console.log('Fetching interface status...')
        try {
          const rpcResponseForSetup = await Util.setRpcJsonrpc('admin')
          const status = await rpcResponseForSetup.networkManager.getInterfaceStatus(this.wan.interfaceId)
          console.log('WAN status:', status)
          this.wanStatus = status
        } catch (error) {
          console.error('Unable to get WAN status:', error)
          this.showWarning('Unable to get WAN status.')
        }
      },
      async renewDhcp() {
        console.log('Renewing DHCP...')

        // Set loading statethis
        this.loading = true
        try {
          // Initialize RPC session for 'admin'

          const rpcResponseForSetup = await Util.setRpcJsonrpc('admin')
          console.log('rpcResponseForSetup:', rpcResponseForSetup)
          await rpcResponseForSetup.networkManager.setNetworkSettings((response, ex) => {
            if (ex) {
              this.showWarning('Unable to set Network Settings.')
              return
            }
            // then force the DHCP lease renew just in case
            this.showWarning('Renewing DHCP Lease...')
            rpcResponseForSetup.networkManager.renewDhcpLease(() => {
              this.showWarning('DHCP lease renewed successfully.')
              this.getSettings()
            }, this.wan.interfaceId)
          }, this.networkSettings)
        } catch (error) {
          console.log('error', error)
          console.error('Error during DHCP renewal:', error)
        } finally {
          this.loading = false
        }
      },
    },
  }
</script>

<style scoped>
  /* Main layout adjustments */
  .main-div {
    max-width: 1100px;
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

  .column-view {
    display: grid;
    grid-template-columns: 1fr 1fr; /* Split into two equal columns */
    align-items: start;
  }

  .status-item-details,
  .status-item {
    display: flex;
    justify-content: space-between;
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
    /* display: flex;
    flex-direction: column;
    gap: 12px;
    width: 320px;
    height: 400px;
    margin: 0 auto;
    overflow-y: auto; 
    overflow-x: hidden;  */
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding-right: 20px;
  }

  /* Status grid styling */
  .status-grid {
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding-right: 20px;
  }

  /* Configuration Radio Button Group */
  .radio-group {
    display: flex;
    justify-content: center;
    gap: 15px;
    /* align-items: center; */
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
    /* align-items: center;
    justify-content: center; */
    color: white;
    font-size: 14px;
    cursor: pointer;
    transition: background-color 0.3s ease-in-out, transform 0.2s ease-in-out;
  }

  /* Button Styling */
  .button-margin {
    display: flex;
    justify-content: center; /* Center the button horizontally */
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
    justify-content: space-between; /* Place items at the ends of the container */
    align-items: center;
    /* margin-top: 50px; */
    /* gap: 1000px; */
  }

  .no-internet {
    /* color: red; */
    /* font-weight: bold; */
    /* text-align: center; */
    margin-bottom: 15px;
    font-size: smaller;
  }
</style>
