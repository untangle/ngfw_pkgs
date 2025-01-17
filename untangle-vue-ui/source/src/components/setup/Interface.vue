<template>
  <div class="internal-network">
    <h1>{{ title }}</h1>
    <p>{{ description }}</p>

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
        <img src="/skins/simple-gray/images/admin/wizard/router.png" alt="Router" class="config-image" />

        <div class="form-field">
          <label>{{ $t('Internal Address') }}</label>
          <input v-model="internal.v4StaticAddress" type="text" disabled />
        </div>

        <div class="form-field">
          <label>{{ $t('Internal Netmask') }}</label>
          <select v-model="internal.v4StaticPrefix" disabled>
            <option v-for="[prefix, label] in v4NetmaskList" :key="prefix" :value="prefix">
              {{ label }}
            </option>
          </select>
        </div>

        <div class="form-field">
          <label>{{ $t('DHCP Server') }}</label>
          <div class="radio-group">
            <label>
              {{ $t('Enabled') }}
              <input v-model="internal.dhcpType" type="radio" name="dhcpType" value="SERVER" disabled />
            </label>
            <label>
              {{ $t('Disabled') }}
              <input v-model="internal.dhcpType" type="radio" name="dhcpType" value="DISABLED" disabled />
            </label>
          </div>
        </div>
      </div>

      <!-- Transparent Bridge Section -->
      <div class="bridge-section">
        <div class="radio-group">
          <input id="bridge" v-model="internal.configType" type="radio" name="configType" value="BRIDGED" />
          <label for="bridge"
            ><strong>{{ $t('Transparent Bridge') }}</strong></label
          >
        </div>
        <p class="info-text">
          {{
            $t(
              'This is recommended if the external port is plugged into a firewall/router. This bridges Internal and External and disables DHCP.',
            )
          }}
        </p>
        <img src="/skins/simple-gray/images/admin/wizard/bridge.png" alt="Bridge" class="config-image" />
      </div>

      <!-- Save Button -->
      <!-- <button class="save-button" @click="onSave">{{ $t('Save') }}</button> -->
    </div>
  </div>
</template>

<script>
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
        v4NetmaskList: {
          '8': '255.0.0.0',
          '16': '255.255.0.0',
          '24': '255.255.255.0',
          '32': '255.255.255.255',
        }, // Static Netmask list
      }
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
    padding: 20px;
    border: 1px solid #ccc;
    border-radius: 5px;
    background-color: #f9f9f9;
    font-family: Arial, sans-serif;
    margin: 20px;
  }
  .router-section,
  .bridge-section {
    margin-bottom: 20px;
    text-align: left;
  }
  .radio-group {
    margin-bottom: 10px;
  }
  .info-text {
    margin: 10px 0;
    font-size: 14px;
    color: #555;
  }
  .form-field {
    margin: 10px 0;
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .form-field label {
    font-weight: bold;
    flex: 0 0 150px;
  }
  .form-field input,
  .form-field select {
    flex: 1;
    padding: 5px;
    border: 1px solid #ccc;
    border-radius: 3px;
  }
  .config-image {
    margin-top: 10px;
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
</style>
