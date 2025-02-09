<template>
  <v-card width="1100" height="auto" class="mx-auto mt-4" flat>
    <SetupLayout />
    <div class="internal-network">
      <h1 class="font-weight-light faint-color text-h5">{{ description }}</h1>
      <div>
        <div class="form-container">
          <!-- Router Section -->
          <v-radio-group>
            <div class="radio-group">
              <!-- <v-radio label="Radio One" value="one"></v-radio> -->
              <input
                v-model="internal.configType"
                type="radio"
                name="configType"
                value="ADDRESSED"
                enabled
                @change="setConfigType"
              />
              <label
                ><strong>{{ 'Router' }}</strong></label
              >
              <p class="info-text">
                {{
                  $t(
                    'This is recommended if the external port is plugged into the internet connection. This enables NAT and DHCP.',
                  )
                }}
              </p>

              <div class="form-field">
                <div class="form-field">
                  <label>{{ 'Internal Address:' }}</label>
                  <input
                    v-model="internal.v4StaticAddress"
                    type="text"
                    :disabled="internal.configType !== 'ADDRESSED'"
                  />
                </div>
                <div class="form-field-netmask">
                  <label>{{ 'Internal Netmask:' }}</label>
                  <v-autocomplete
                    v-model="internal.v4StaticPrefix"
                    :items="v4NetmaskList"
                    :disabled="internal.configType !== 'ADDRESSED'"
                    outlined
                    dense
                    hide-details
                    return-object
                    class="form-field-autocomplete"
                  >
                  </v-autocomplete>
                </div>
                <br />
                <label class="form-field-label">{{ 'DHCP Server:' }}</label>
                <div class="radio-group-child">
                  <input
                    v-model="internal.dhcpType"
                    type="radio"
                    name="dhcpType"
                    value="SERVER"
                    :disabled="internal.configType !== 'ADDRESSED'"
                  />
                  {{ 'Enabled' }}
                  <br />
                  <input
                    v-model="internal.dhcpType"
                    type="radio"
                    name="dhcpType"
                    value="DISABLED"
                    :disabled="internal.configType !== 'ADDRESSED'"
                  />
                  {{ 'Disabled' }}
                </div>
              </div>
            </div>
            <br />
            <div class="radio-group">
              <!-- <v-radio label="Transparent Bridge" value="two"></v-radio> -->
              <input
                v-model="internal.configType"
                type="radio"
                name="configType"
                value="BRIDGED"
                enabled
                @change="setConfigType"
              />
              <label
                ><strong>{{ 'Transparent Bridge' }}</strong></label
              >
            </div>
            <p class="info-text">
              {{
                $t(
                  'This is recommended if the external port is plugged into a firewall/router. This bridges Internal and External and disables DHCP.',
                )
              }}
            </p>
            <br />
            <u-btn class="button-container button-back" :small="true" @click="onClickBack">{{ `Back` }}</u-btn>
          </v-radio-group>
          <!-- </div> -->

          <!-- Transparent Bridge Section -->
          <div class="image-section">
            <br />
            <img src="/skins/simple-gray/images/admin/wizard/router.png" alt="Router" class="config-image" />
            <br />
            <br />
            <br />
            <br />
            <img src="/skins/simple-gray/images/admin/wizard/bridge.png" alt="Bridge" class="config-image" />
            <div class="button-container-next">
              <u-btn class="button-container button-next" :small="true" @click="onSave">
                {{ `Next` }}
              </u-btn>
            </div>
          </div>
        </div>
        <br />
      </div>
    </div>
    <div v-if="warnAboutDisappeareAddress" class="popup wait-message">
      <div class="popup-content">
        <h2>Please Wait</h2>
        <p>Saving Internal Network Settings</p>
        <p>The Internal Address is no longer accessible.</p>
        <p>
          You will be redirected to the new setup address:
          <a :href="newSetupLocation">{{ newSetupLocation }}</a>
        </p>
        <p>
          If the new location is not loaded after 30 seconds, please reinitialize your local device network address and
          try again.
        </p>
        <button @click="closePopup">Close</button>
      </div>
    </div>

    <div v-if="warnAboutChangAddress" class="popup wait-message">
      <div class="popup-content">
        <h2>Please Wait</h2>
        <p>Saving Internal Network Settings</p>
        <p>The Internal Address is changed to: {{ internal.v4StaticAddress }}</p>
        <p>
          The changes are applied, and you will be redirected to the new setup address:
          <a :href="newSetupLocation">{{ newSetupLocation }}</a>
        </p>
        <p>
          If the new location is not loaded after 30 seconds, please reinitialize your local device network address and
          try again.
        </p>
        <button @click="closePopup">Close</button>
      </div>
    </div>
  </v-card>
</template>

<script>
  import { mapActions } from 'vuex'
  import Util from '@/util/setupUtil'
  import SetupLayout from '@/layouts/SetupLayout.vue'

  export default {
    name: 'InternalNetwork',
    components: {
      SetupLayout,
    },
    props: {
      rpc: {
        type: Object,
        required: true,
      },
    },
    data() {
      return {
        loadingText: '',
        redirectMessage: '',
        retryMessage: '',
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
        warnAboutDisappeareAddress: false,
        warnAboutChangAddress: false,
        newSetupLocation: null,
      }
    },
    computed: {
      netmaskListSync: {
        get() {
          return this.v4NetmaskList // Access installType from Vuex
        },
        set(value) {
          this.$store.dispatch('setup/setInstallType', value) // Dispatch action to update installType in Vuex
        },
      },
    },
    created() {
      console.log('v4NetmaskList :', this.v4NetmaskList)
      console.log('Created called :')
      this.getInterface()
      console.log('After getInterface called :', this.internal)
    },
    methods: {
      ...mapActions('setup', ['setShowStep']), // Map the setShowStep action from Vuex store
      ...mapActions('setup', ['setShowPreviousStep']),

      setConfigType(radio) {
        if (radio.target.defaultValue === 'BRIDGED') {
          this.internal.configType = 'BRIDGED'
        } else {
          this.internal.configType = 'ADDRESSED'
          this.internal.v4ConfigType = 'STATIC'
        }
      },
      closePopup() {
        this.showWarnAboutDisappearingAddressMessage = false
        this.showWarnAboutChangingAddressMessage = false
      },
      async getInterface() {
        try {
          // TODO: check if rpc call is required
          const rpc = Util.setRpcJsonrpc('admin')
          this.networkSettings = await rpc?.networkManager?.getNetworkSettings()
          this.interfaces = this.networkSettings.interfaces.list

          this.internal = this.interfaces.find(intf => !intf.isWan)

          console.log('internal in getInterface():', this.internal)
          if (!this.internal) {
            const userConfirmed = window.confirm('No internal interfaces found. Do you want to continue the setup?')
            if (userConfirmed) {
              // TODO
              // this.$refs.nextBtn.click(); // next button
            } else {
              // if no is pressed
              console.log(' No is pressed ')
            }
          } else {
            this.initialConfigType = this.internal.configType
            this.initialv4Address = this.internal.v4StaticAddress
            this.initialv4Prefix = this.internal.v4StaticPrefix
            this.initialDhcpType = this.internal.dhcpType
          }
          // this.internal = this.internal
        } catch (error) {
          console.log('Failed to fetch device settings:', error)
        }
      },

      hideLoading() {
        this.isLoading = false
      },
      async warnAboutDisappearingAddress() {
        const rpc = Util.setRpcJsonrpc('admin')
        let firstWan = ''
        let firstWanStatus = ''
        // get firstWan settings & status
        firstWan = this.networkSettings.interfaces.list.find(intf => intf.isWan && intf.configType !== 'DISABLED')
        // firstWan must exist
        if (!firstWan || !firstWan.interfaceId) {
          return
        }

        try {
          firstWanStatus = await window.rpc.networkManager.getInterfaceStatus(firstWan.interfaceId)
        } catch (e) {
          Util.handleException(e)
        }

        // and the first WAN has a address
        if (!firstWanStatus || !firstWanStatus.v4Address) {
          return
        }

        // TODO Use Internal Address instead of External Address
        this.newSetupLocation = window.location.href.replace(this.internal.v4StaticAddress, firstWanStatus.v4Address)
        console.log('newSetupLocation **:', this.newSetupLocation)
        // TODO
        rpc.keepAlive = function () {} // prevent keep alive

        this.showWarnAboutDisappearingAddressMessage()
        setTimeout(() => {
          this.warnAboutDisappeareAddress = false
          window.location.href = this.newSetupLocation
        }, 30000)
      },
      showWarnAboutDisappearingAddressMessage() {
        this.warnAboutDisappeareAddress = true
        this.warnAboutChangAddress = false
      },
      showWarnAboutChangingAddressMessage() {
        this.warnAboutDisappeareAddress = false
        this.warnAboutChangAddress = true
      },
      warnAboutChangingAddress() {
        const rpc = Util.setRpcJsonrpc('admin')
        this.newSetupLocation = window.location.href.replace(this.initialv4Address, this.internal.v4StaticAddress)
        console.log('newSetupLocation :', this.newSetupLocation)
        // TODO
        rpc.keepAlive = function () {} // prevent keep alive
        // TODO

        this.showWarnAboutChangingAddressMessage()
        setTimeout(() => {
          this.warnAboutChangAddress = false
          window.location.href = this.newSetupLocation
        }, 30000)
      },
      async onClickBack() {
        try {
          await Promise.resolve()
          await this.setShowStep('System')
          await this.setShowPreviousStep('System')
          // Navigate to the setup wizard page
          // this.$router.push('/setup/system/')
        } catch (error) {
          console.error('Failed to navigate:', error)
        }
      },
      async onSave() {
        console.log('in Save :', this.internal)
        // TODO
        // if (!me.getView().isValid()) { return; }

        // no changes made - continue to next step
        if (this.internal.v4StaticPrefix && this.internal.v4StaticPrefix.value) {
          this.internal.v4StaticPrefix = this.internal.v4StaticPrefix.value
        }
        if (
          this.initialConfigType === this.internal.configType &&
          this.initialv4Address === this.internal.v4StaticAddress &&
          this.initialv4Prefix === this.internal.v4StaticPrefix &&
          this.initialDhcpType === this.internal.dhcpType
        ) {
          console.log('networkSettings saved in return with no changes:', this.internal)
          await Promise.resolve()
          await this.setShowStep('Network')
          await this.setShowPreviousStep('Network')
          return
        }
        // BRIDGED (bridge mode)
        if (this.internal.configType === 'BRIDGED') {
          // If using internal address - redirect to external since internal address is vanishing
          if (window.location.hostname === this.internal.v4StaticAddress) {
            this.warnAboutDisappearingAddress()
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
            this.warnAboutChangingAddress()
          }
        }

        await window.rpc.networkManager.setNetworkSettings(this.networkSettings)

        // Simply log the internal settings
        console.log('networkSettings saved:', this.networkSettings)
        console.log('Settings saved:', this.internal)
        alert('Settings saved successfully.')

        await Promise.resolve()
        await this.setShowStep('Autoupgrades')
        await this.setShowPreviousStep('Internet')
      },
    },
  }
</script>

<style scoped>
  .loading-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: rgba(0, 0, 0, 0.5);
    display: flex;
    justify-content: center;
    align-items: center;
    z-index: 1000;
  }

  .loading-message {
    background-color: white;
    padding: 20px;
    border-radius: 8px;
    text-align: center;
    max-width: 500px;
    word-wrap: break-word;
  }
  .internal-network {
    display: flex;
    flex-direction: column;
    padding: 20px;
    justify-content: flex-start; /* Align content to the top */
    margin: 20px 120px 10px 120px; /* Reduced bottom margin to 10px */
    border: 1px solid #ccc;
    background-color: #f9f9f9;
    font-family: Arial, sans-serif;
    height: auto; /* Ensure the height fits within the viewport, considering margins */
    overflow: hidden; /* Hide any overflow */
  }

  .router-section,
  .bridge-section {
    margin-bottom: 20px;
    text-align: left;
  }

  .radio-group {
    margin-bottom: 8px 8spx 8px 8px;
  }
  .radio-group-child {
    display: block;
    margin: -30px 10px 0px 0px;
  }
  .radio-group-child label {
    display: block;
    margin-bottom: 10px;
  }
  .radio-group-child input[type='radio'] {
    margin-left: 50px;
    margin-right: -80px;
    margin-bottom: 10px;
  }
  .info-text {
    margin: 10px 10px 0px 12px;
    font-size: 12px;
    color: #555;
  }
  .form-field-netmask {
    font-size: 14px;
    width: 88%;
    margin: 20px 50px 0px 30px;
    /* display: block; */
    /* align-items: center; */
    padding: 0px 0px 0px 0px;
  }

  .form-field-autocomplete {
    font-size: 14px;
    width: 51%;
    margin: -30px 50px 0px 133px;
    padding: 0px 5px 10px 0px;
    display: block;
    align-items: center;
    gap: 10px;
  }
  .form-field-autocomplete input {
    height: 94px !important;
    line-height: 24px;
    padding: 0px 4px;
  }
  .form-field {
    font-size: 14px;
    width: 88%;
    margin: 20px 50px 0px 30px;
    display: block;
    align-items: center;
    gap: 10px;
  }

  .form-field label {
    padding: 2px 8px 2px 10px;
    font-weight: bold;
    flex: 0 0 150px;
    font-size: 14px;
  }

  .form-field input,
  form-field select {
    width: 50%;
    flex-direction: column;
    flex: 1;
    padding: 2px 2px 2px 10px;
    border: 1px solid #817e7e;
    border-radius: 3px;
    font-size: 14px;
  }
  .form-field-label {
    font-size: 14px;
    width: 90%;
    margin: -13px 30px 0px 30px;
    display: block;
    align-items: center;
    gap: 10px;
  }
  .config-image {
    margin-top: 30px;
    max-width: 200px;
    height: auto;
  }

  .save-button {
    display: block;
    margin: 20px auto;
    padding: 10px 20px;
    background-color: #007bff;
    color: #fff;
    border: none;
    border-radius: 5px;
    cursor: pointer;
    font-size: 16px;
  }

  .save-button:hover {
    background-color: #0056b3;
  }
  .form-container {
    display: flex;
    width: 1400%;
    max-width: 900px;
    padding: 20px;
    gap: 40px;
    overflow: hidden;
  }
  .image-section {
    width: 300px;
    height: 183px;
    padding: 30px 90px 350px 0px;
    margin-right: -12px;
  }

  .button-container {
    padding: 0px 0px 22px 0px;
    font-size: 14px;
    display: block;
    margin-left: 10px;
    margin-right: 0;
    width: 100px;
    justify-content: center;
  }
  .button-container-next {
    display: flex;
    justify-content: flex-end;
    margin-right: -10px;
  }
  .button-next {
    margin: 26px;
  }

  .button-back {
    margin: 15.9px;
  }

  .wait-message {
    background-color: #f0f0f0;
    border: 1px solid #ccc;
    padding: 20px;
    text-align: center;
    margin: 20px;
    border-radius: 5px;
  }

  .wait-message h2 {
    font-size: 1.5em;
    margin-bottom: 10px;
  }

  .wait-message a {
    color: blue;
    text-decoration: underline;
  }
  .popup {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background-color: rgba(0, 0, 0, 0.5);
    display: flex;
    justify-content: center;
    align-items: center;
    z-index: 1000;
  }
  .popup-content {
    background-color: white;
    padding: 20px;
    border-radius: 10px;
    max-width: 400px;
    text-align: center;
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
  }
  .popup button {
    margin-top: 20px;
    padding: 10px 20px;
    background-color: #007bff;
    color: white;
    border: none;
    border-radius: 5px;
    cursor: pointer;
  }
  .popup button:hover {
    background-color: #0056b3;
  }
</style>
