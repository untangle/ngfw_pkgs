<template>
  <div>
    <!-- Conditional Rendering for License Component -->
    <License
      v-if="showLicense"
      :setup-rpc="setupRpc"
      :admin-rpc="adminRpc"
      @next="onLicenseNext"
      @disagree="onLicenseDisagree"
    />

    <!-- Internet Setup Component -->
    <div v-else class="internet-setup">
      <h1>Internet Connection</h1>
      <p>Configure the Internet Connection</p>
      <Loader :show="loading" message="Testing Connectivity..." />

      <!-- Connectivity Message -->
      <div v-if="!isRemoteReachable" class="warning-message">
        <p>No Internet Connection..! Click on 'Test Connectivity' to verify.</p>
      </div>

      <!-- Configuration Section -->
      <div class="configuration-container">
        <div v-if="wan">
          <h3>Configuration Type</h3>
          <div>
            <label>
              <input v-model="wan.v4ConfigType" type="radio" value="AUTO" />
              Auto (DHCP)
            </label>
            <label>
              <input v-model="wan.v4ConfigType" type="radio" value="STATIC" />
              Static
            </label>
            <label>
              <input v-model="wan.v4ConfigType" type="radio" value="PPPOE" />
              PPPoE
            </label>
          </div>
        </div>
      </div>
      <!-- Static Configuration -->
      <div v-if="wan.v4ConfigType === 'STATIC'" class="static-config">
        <label>
          IP Address:
          <input v-model="wan.v4StaticAddress" type="text" />
        </label>
        <label>
          Netmask:
          <select v-model="wan.v4StaticPrefix">
            <option v-for="mask in netmaskList" :key="mask" :value="mask">{{ mask }}</option>
          </select>
        </label>
        <label>
          Gateway:
          <input v-model="wan.v4StaticGateway" type="text" />
        </label>
        <label>
          Primary DNS:
          <input v-model="wan.v4StaticDns1" type="text" />
        </label>
        <label>
          Secondary DNS (optional):
          <input v-model="wan.v4StaticDns2" type="text" />
        </label>
      </div>

      <!-- PPPoE Configuration -->
      <div v-if="wan.v4ConfigType === 'PPPOE'" class="pppoe-config">
        <label>
          Username:
          <input v-model="wan.v4PPPoEUsername" type="text" />
        </label>
        <label>
          Password:
          <input v-model="wan.v4PPPoEPassword" type="password" />
        </label>
      </div>

      <!-- Status Section -->
      <div v-if="wanStatus" class="status-section">
        <h3>Status</h3>
        <p><strong>IP Address:</strong> {{ wanStatus.v4Address }}</p>
        <p><strong>Netmask:</strong> /{{ wanStatus.v4PrefixLength }} - {{ wanStatus.v4Netmask }}</p>
        <p><strong>Gateway:</strong> {{ wanStatus.v4Gateway }}</p>
        <p><strong>Primary DNS:</strong> {{ wanStatus.v4Dns1 }}</p>
        <p><strong>Secondary DNS:</strong> {{ wanStatus.v4Dns2 }}</p>
      </div>

      <!-- Buttons -->
      <div class="button-container">
        <button v-if="wan.v4ConfigType === 'AUTO'" @click="renewDhcp">Renew DHCP</button>
        <button @click="onSave">Test Connectivity</button>
        <button v-if="remoteTestPassed" @click="resetWizard">Run Setup Wizard Locally</button>
      </div>
    </div>
  </div>
</template>

<script>
  import Util from '@/util/setupUtils'
  import Loader from '@/Setup_wizard/Loader.vue'
  import License from '@/Setup_wizard/step/License.vue'
  export default {
    components: {
      Loader,
      License,
    },
    props: {
      setupRpc: {
        type: Object,
        required: true,
      },
      remoteReachable: {
        type: Boolean,
        required: true,
      },
    },
    data() {
      return {
        adminRpc: {},
        wan: {}, // Current WAN configuration
        // remote: null,
        wanStatus: null, // WAN interface status
        loading: false,
        nextDisabled: false,
        remoteTestPassed: false,
        showLicense: false,
        netmaskList: [24, 25, 26, 27, 28, 29, 30], // Example netmask values
      }
    },
    computed: {
      isRemoteReachable() {
        return this.remoteReachable
      },
    },
    async mounted() {
      window.rpc.admin = new window.JSONRpcClient('/admin/JSON-RPC').UvmContext
      this.adminRpc = window.rpc.admin
      this.getSettings()

      await this.getSettings()
      if (this.wan) {
        await this.getInterfaceStatus()
      }
    },
    methods: {
      getSettings() {
        console.log('Fetching network settings...')
        console.log('window.rpc', window.rpc)
        console.log('tthis.adminRpc', this.adminRpc)
        // window.rpc.admin = new window.JSONRpcClient('/admin/JSON-RPC').UvmContext
        console.log('window.rpc.admin', window.rpc.admin)
        const settings = this.adminRpc.networkManager().getNetworkSettings()
        console.log('settings', settings)
        this.wan = settings.interfaces.list.find(intf => intf.isWan)
        console.log('this.wan', this.wan)

        if (this.wan) {
          this.getInterfaceStatus()
        }
      },
      getInterfaceStatus() {
        console.log('Fetching WAN status...')
        const status = this.adminRpc.networkManager().getInterfaceStatus(this.wan.interfaceId)
        this.wanStatus = status
        console.log('this.wanStatus', this.wanStatus)
      },

      renewDhcp() {
        console.log('Renewing DHCP...')
        this.loading = true // Show loader
        try {
          // Save the network settings before renewing DHCP
          console.log('Saving settings...')
          this.adminRpc.networkManager().setNetworkSettings(this.wan, (response, ex) => {
            if (ex) {
              console.error('Unable to set Network Settings.', ex)
              this.showError('Unable to set Network Settings.')
              return
            }
            console.log('Settings saved. Renewing DHCP lease...')

            // Renew the DHCP lease
            this.adminRpc.networkManager().renewDhcpLease(this.wan.interfaceId, (result, error) => {
              this.loading = false // Hide loader
              if (error) {
                console.error('Unable to renew DHCP lease.', error)
                this.showError('Unable to renew DHCP lease.')
                return
              }
              console.log('DHCP lease renewed successfully.')
              alert('DHCP lease renewed successfully.')
              // Refresh the WAN settings after renewing DHCP
              this.getSettings()
            })
          })
        } catch (error) {
          this.loading = false // Hide loader in case of error
          console.error('Error during DHCP renewal:', error)
          this.showError('Error during DHCP renewal. Please try again.')
        }
      },

      async onSave() {
        console.log('Testing connectivity...123456')

        console.log('this.setupRpc.remote', this.setupRpc.remote)
        this.loading = true
        try {
          // this.$loading.show('Testing Connectivity...')
          this.loading = true
          // Set up RPC context for admin
          Util.setRpcJsonrpc('admin')
          // this.remote = window.rpc.setup

          const result = await this.adminRpc.getConnectivityTester().getStatus()
          console.log('result', result)
          this.nextDisabled = true
          if (this.setupRpc.remote) {
            this.remoteTestPassed = true
          }
          // Check the results
          if (result.tcpWorking === false && result.dnsWorking === false) {
            this.showWarning('Warning! Internet tests and DNS tests failed.')
          } else if (result.tcpWorking === false) {
            this.showWarning('Warning! DNS tests succeeded, but Internet tests failed.')
          } else if (result.dnsWorking === false) {
            this.showWarning('Warning! Internet tests succeeded, but DNS tests failed.')
          } else {
            if (this.setupRpc.remote) {
              Util.setRpcJsonrpc('setup')
              Util.setRpcJsonrpc('admin')
              if (this.remoteReachable === false) {
                this.message = 'Unable to reach ETM Dashboard!'.t()
              } else {
                // nextDisabled = false;
                this.nextDisabled = false
              }
            } else {
              // message = null;
              // nextDisabled = false;
              this.nextDisabled = false
            }
            // this.util.setRpcJsonrpc('setup')
            Util.setRpcJsonrpc('setup')
            // this.remoteReachable = await this.adminRpc.getSetup().getRemoteReachable()
            // this.util.setRpcJsonrpc('admin')
            Util.setRpcJsonrpc('admin')
            if (!this.remoteReachable) {
              this.showWarning('Unable to reach ETM Dashboard!')
            } else {
              alert('Connectivity test passed.')
            }
          }
        } catch (error) {
          console.error('Connectivity test failed:', error)
          this.showError('Unable to complete connectivity test, please try again.')
        } finally {
          // Hide loading indicator
          this.loading = false
        }
      },
      showWarning(message) {
        window.alert(message, 'Warning', {
          confirmButtonText: 'OK',
          type: 'warning',
        })
      },
      showError(message) {
        window.alert(message, 'Error', {
          confirmButtonText: 'OK',
          type: 'error',
        })
      },
      resetWizard() {
        console.log('Resetting wizard...123')
        this.showLicense = true
        // this.setupRpc.UvmContext.setRemoteSetup(false)
        // this.$emit('resetWizard')
      },
      onLicenseNext() {
        console.log('License accepted. Returning to Internet setup...')
        this.showLicense = false // Return to Internet setup
      },
      onLicenseDisagree() {
        console.log('License declined. Reloading...')
        window.location.reload() // Reload the page
      },
      // resetWizard() {
      //   console.log('Resetting wizard...')
      //   this.loading = true // Show loader
      //   console.log('this.setupRpc', this.setupRpc)
      //   console.log('this.setupRpc', this.adminRpc)
      //   console.log('this.setupRpc.setRemoteSetup', this.adminRpc.setRemoteSetup())
      //   console.log('this.setupRpc.setRemoteSetup(false)', this.adminRpc.setRemoteSetup(false))
      //   // try {
      //   //   // Clear the wizard steps and reset the setup
      //   //   this.setupRpc.wizardSettings.steps = []

      //   //   // Set remote setup to false
      //   //   this.setupRpc.UvmContext.setRemoteSetup(false)

      //   //   // Reset the wizard settings on the server
      //   //   this.setupRpc.UvmContext.setWizardSettings(this.setupRpc.wizardSettings, (result, ex) => {
      //   //     this.loading = false // Hide loader
      //   //     if (ex) {
      //   //       console.error('Error resetting wizard:', ex)
      //   //       this.showError('Failed to reset the wizard. Please try again.')
      //   //       return
      //   //     }
      //   //     console.log('Wizard reset successfully. Redirecting...')
      //   //     // Navigate to the setup index page
      //   //     window.location.href = '/setup/index.do'
      //   //   })
      //   // } catch (error) {
      //   //   this.loading = false // Hide loader
      //   //   console.error('Error during wizard reset:', error)
      //   //   this.showError('Unexpected error during wizard reset. Please try again.')
      //   // }
      // },
    },
  }
</script>

<style scoped>
  .internet-setup {
    padding: 20px;
    background-color: #f9f9f9;
    border: 1px solid #ddd;
    border-radius: 8px;
  }

  .warning-message {
    color: red;
    margin-bottom: 20px;
    font-size: 16px;
    font-weight: bold;
  }

  .configuration-container {
    margin-bottom: 20px;
  }

  .status-section {
    margin-top: 20px;
  }

  /* Button Styling */
  .button-container button {
    margin: 5px;
    padding: 12px 24px;
    border-radius: 5px;
    font-size: 16px;
    font-weight: bold;
    cursor: pointer;
    border: none;
    transition: all 0.3s ease-in-out;
    box-shadow: 0px 4px 6px rgba(0, 0, 0, 0.1);
  }

  /* Test Connectivity Button */
  .button-container button:nth-child(2) {
    background-color: #007bff;
    color: #fff;
  }

  .button-container button:nth-child(2):hover {
    background-color: #0056b3;
    transform: scale(1.05);
  }

  /* Renew DHCP Button */
  .button-container button:nth-child(1) {
    background-color: #28a745;
    color: #fff;
  }

  .button-container button:nth-child(1):hover {
    background-color: #218838;
    transform: scale(1.05);
  }

  /* Run Setup Wizard Button */
  .button-container button:nth-child(3) {
    background-color: #ffc107;
    color: #000;
  }

  .button-container button:nth-child(3):hover {
    background-color: #e0a800;
    transform: scale(1.05);
  }
</style>
