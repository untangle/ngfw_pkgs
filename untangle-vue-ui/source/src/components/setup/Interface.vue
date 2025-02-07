<template>
  <v-card width="1100" class="mx-auto mt-4" flat>
    <SetupLayout />
    <div class="internal-network">
      <h1 class="font-weight-light faint-color text-h5">{{ description }}</h1>
      <div>
        <div class="form-container">
          <!-- Router Section -->
          <div class="router-section">
            <div class="radio-group">
              <input
                id="router"
                v-model="internal.configType"
                type="radio"
                name="configType"
                value="ROUTER"
                checked
                @change="setConfigType(internal)"
              />
              <label for="router"
                ><strong>{{ 'Router' }}</strong></label
              >
            </div>
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
                <input v-model="internal.v4StaticAddress" type="text" disabled />
              </div>
              <div class="form-field">
                <label>{{ 'Internal Netmask:' }}</label>
                <ValidationProvider v-slot="{ errors }" rules="required">
                  <v-autocomplete
                    v-model="internal.v4StaticNetmask"
                    :items="v4NetmaskList"
                    outlined
                    dense
                    hide-details
                    return-object
                  >
                    <template v-if="errors.length" #append>
                      <u-errors-tooltip :errors="errors" />
                    </template>
                  </v-autocomplete>
                </ValidationProvider>
                <!-- <input v-model="internal.v4StaticAddress" type="text" disabled /> -->
                <!-- <select v-model="internal.v4StaticPrefix" disabled>
                <option v-for="[prefix, label] in v4NetmaskList" :key="prefix" :value="label">
                  {{ label }}
                </option>
              </select> -->
                <br />
                <label>{{ 'DHCP Server:' }}</label>
                <div class="radio-group-child">
                  <input v-model="internal.dhcpType" type="radio" name="dhcpType" value="SERVER" enabled />
                  {{ 'Enabled' }}
                  <br />
                  <input v-model="internal.dhcpType" type="radio" name="dhcpType" value="DISABLED" enabled />
                  {{ 'Disabled' }}
                </div>
              </div>
              <!-- <div class="radio-group">
              <label>{{ 'DHCP Server:' }}</label>
              <input v-model="internal.dhcpType" type="radio" name="dhcpType" value="SERVER" enabled />
              {{ 'Enabled' }}
              <br />
              <input v-model="internal.dhcpType" type="radio" name="dhcpType" value="DISABLED" enabled />
              {{ 'Disabled' }}
            </div> -->
            </div>
            <br />
            <div class="radio-group">
              <input
                id="bridge"
                v-model="internal.configType"
                type="radio"
                name="configType"
                value="BRIDGED"
                @change="setConfigType(internal)"
              />
              <label for="bridge"
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
            <u-btn class="button-container" :small="false" style="margin: 8px 0" @click="onClickBack">{{
              `Back`
            }}</u-btn>
          </div>

          <!-- Transparent Bridge Section -->
          <div class="image-section">
            <br />
            <img src="/skins/simple-gray/images/admin/wizard/router.png" alt="Router" class="config-image" />
            <br />
            <br />
            <br />
            <br />
            <img src="/skins/simple-gray/images/admin/wizard/bridge.png" alt="Bridge" class="config-image" />
            <u-btn class="button-container" :small="false" style="margin: 8px 0" @click="onClickNext">{{
              `Next`
            }}</u-btn>
          </div>
        </div>
        <br />
      </div>
    </div>
    <div v-if="isLoading" class="loading-overlay">
      <div class="loading-message">
        <p>{{ loadingText }}</p>
        <p v-html="redirectMessage"></p>
        <p>{{ retryMessage }}</p>
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
        internal: [],
        // internal: {
        //   configType: 'ROUTER', // Hardcoded config type as 'ROUTER'
        //   v4configType: null,
        //   v4StaticAddress: '192.168.1.1', // Static IP Address
        //   v4StaticPrefix: '24', // Static Netmask
        //   dhcpType: null, // Static DHCP server option
        // },
        v4NetmaskList: Util.v4NetmaskList,
      }
    },
    computed: {
      installTypeSync: {
        get() {
          return this.installType // Access installType from Vuex
        },
        set(value) {
          this.$store.dispatch('setup/setInstallType', value) // Dispatch action to update installType in Vuex
        },
      },
    },
    created() {
      this.getInterface()
    },
    methods: {
      ...mapActions('setup', ['setShowStep']), // Map the setShowStep action from Vuex store
      ...mapActions('setup', ['setShowPreviousStep']),

      setConfigType(radio) {
        console.log('** Radio in setConfigType :', radio)
        if (radio.checked) {
          if (radio.inputValue === 'BRIDGED') {
            this.internal.configType = 'BRIDGED'
          } else {
            this.internal.configType = 'ADDRESSED'
            this.internal.v4configType = 'STATIC'
          }
        }
      },
      getInterface() {
        this.interfaces = this.networkSettings.interfaces.list

        console.log('getInterface() :', this.interfaces)
        const internal = this.interfaces.find(intf => !intf.isWan)

        console.log('internal in getInterface():', this.internal)
        if (!internal) {
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
        this.internal = internal
      },
      showSavingMessage(newSetupLocation) {
        this.isLoading = true
        this.loadingText = this.$t('Saving Internal Network Settings')
        this.redirectMessage =
          this.$t('The Internal Address is no longer accessible.') +
          '<br/>' +
          this.$t('You will be redirected to the new setup address: ') +
          `<a href="${newSetupLocation}">${newSetupLocation}</a><br/><br/>`
        this.retryMessage = this.$t(
          'If the new location is not loaded after 30 seconds please reinitialize your local device network address and try again.',
        )
      },
      hideLoading() {
        this.isLoading = false
      },
      async warnAboutDisappearingAddress() {
        const rpc = Util.setRpcJsonrpc('admin')
        let firstWan = ''
        let firstWanStatus = ''
        let newSetupLocation = ''
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
        newSetupLocation = window.location.href.replace(this.internal.v4StaticAddress, firstWanStatus.v4Address)
        // TODO
        rpc.keepAlive = function () {} // prevent keep alive
        // TODO written showSavingMessage method for this
        // Ext.MessageBox.wait('Saving Internal Network Settings'.t() + '<br/><br/>' +
        //                         'The Internal Address is no longer accessible.'.t() + '<br/>' +
        //                         Ext.String.format('You will be redirected to the new setup address: {0}'.t(), '<a href="' + newSetupLocation + '">' + newSetupLocation + '</a>') + '<br/><br/>' +
        //                         'If the new location is not loaded after 30 seconds please reinitialize your local device network address and try again.'.t(), 'Please Wait'.t());

        this.showSavingMessage(newSetupLocation)
        // setTimeout(() => {
        //   window.location.href = newSetupLocation
        // }, 30000)
      },
      warnAboutChangingAddress() {
        const rpc = Util.setRpcJsonrpc('admin')
        const newSetupLocation = window.location.href.replace(this.initialv4Address, this.internal.v4StaticAddress)
        // TODO
        rpc.keepAlive = function () {} // prevent keep alive
        // TODO
        // Ext.MessageBox.wait('Saving Internal Network Settings'.t() + '<br/><br/>' +
        //                         Ext.String.format('The Internal Address is changed to: {0}'.t(), vm.get('internal.v4StaticAddress')) + '<br/>' +
        //                         Ext.String.format('The changes are applied and you will be redirected to the new setup address: {0}'.t(), '<a href="' + newSetupLocation + '">' + newSetupLocation + '</a>') + '<br/><br/>' +
        //                         'If the new location is not loaded after 30 seconds please reinitialize your local device network address and try again.'.t(), 'Please Wait'.t());
        setTimeout(() => {
          window.location.href = newSetupLocation
        }, 30000)
      },
      async onSave(cb) {
        // TODO
        // if (!me.getView().isValid()) { return; }

        // no changes made - continue to next step
        if (
          this.initialConfigType === this.internal.configType &&
          this.initialv4Address === this.internal.v4StaticAddress &&
          this.initialv4Prefix === this.internal.v4StaticPrefix &&
          this.initialDhcpType === this.internal.dhcpType
        ) {
          cb()
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

        // TODO save settings and continue to next step
        // Ung.app.loading('Saving Internal Network Settings'.t());

        await window.rpc.networkManager.setNetworkSettings(function (result, ex) {
          // TODO
          // Ung.app.loading(false)
          if (ex) {
            Util.handleException(ex)
            return
          }
          cb()
        }, this.networkSettings)

        // Simply log the internal settings
        console.log('Settings saved:', this.internal)
        alert('Settings saved successfully.')
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
    height: calc(100vh - 40px); /* Ensure the height fits within the viewport, considering margins */
    overflow: hidden; /* Hide any overflow */
  }

  .form-container {
    display: flex;
    width: 100%; /* Ensure the form container takes full width */
    max-width: 900px; /* Set a max-width for the content */
    padding: 20px;
    gap: 90px;
    overflow: hidden; /* Prevent any internal scrolling */
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
    margin: -18px 8px 8px 92px;
  }

  .info-text {
    margin: 10px -120px 0px 12px;
    font-size: 12px;
    color: #555;
  }

  .form-field {
    font-size: 14px;
    width: 100%;
    margin: 10px 50px 0px 40px;
    display: block;
    align-items: center;
    gap: 10px;
  }

  .form-field label {
    font-weight: bold;
    flex: 0 0 150px;
    font-size: 14px;
  }

  .form-field input,
  select {
    flex-direction: column;
    flex: 1;
    padding: 1px;
    border: 1px solid #ccc;
    border-radius: 1px;
    font-size: 14px;
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
  .image-section {
    width: 180px;
    height: 183px;
  }
  .button-container {
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 1300px;
  }
</style>
