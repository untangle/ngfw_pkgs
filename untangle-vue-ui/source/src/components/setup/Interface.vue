<template>
  <div class="internal-network">
    <h1 class="font-weight-light faint-color text-h5">{{ description }}</h1>
    <div>
      <div class="form-container">
        <!-- Router Section -->
        <div class="router-section">
          <div class="radio-group">
            <input id="router" v-model="internal.configType" type="radio" name="configType" value="ROUTER" checked />
            <label for="router"
              ><strong>{{ $t('Router') }}</strong></label
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
                  v-model="internal.v4StaticPrefix"
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
            <input id="bridge" v-model="internal.configType" type="radio" name="configType" value="BRIDGED" />
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
        </div>
        <div class="button-container">
          <u-btn :small="false" style="margin: 8px 0" @click="onClickBack">{{ `Back` }}</u-btn>
          <u-btn :small="false" style="margin: 8px 0" @click="onClickNext">{{ `Next` }}</u-btn>
        </div>
      </div>
      <br />
    </div>
  </div>
</template>

<script>
  import Util from '@/util/setupUtil'

  export default {
    name: 'InternalNetwork',
    data() {
      return {
        title: 'Internal Network',
        description: 'Configure the Internal Network Interface',
        internal: {
          configType: 'ROUTER', // Hardcoded config type as 'ROUTER'
          v4StaticAddress: '192.168.1.1', // Static IP Address
          v4StaticPrefix: '24', // Static Netmask
          dhcpType: 'SERVER', // Static DHCP server option
        },
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
    methods: {
      onSave() {
        // Simply log the internal settings
        console.log('Settings saved:', this.internal)
        alert('Settings saved successfully.')
      },
    },
  }
</script>

<style scoped>
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
