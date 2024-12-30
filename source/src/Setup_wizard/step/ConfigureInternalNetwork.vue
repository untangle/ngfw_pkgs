<template>
  <AutoUpgrades v-if="showAutoUpgrades" :setup-rpc="setupRpc" :admin-rpc="adminRpc" />
  <div v-else class="internal-network">
    <h1>{{ title }}</h1>
    <p>{{ description }}</p>

    <div v-if="internal" class="form-container">
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
            @change="setConfigType('ROUTER')"
          />
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
          <input v-model="internal.v4StaticAddress" type="text" :disabled="internal.configType !== 'ROUTER'" />
        </div>

        <div class="form-field">
          <label>{{ $t('Internal Netmask') }}</label>
          <select v-model="internal.v4StaticPrefix" :disabled="internal.configType !== 'ROUTER'">
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
              <input
                v-model="internal.dhcpType"
                type="radio"
                name="dhcpType"
                value="SERVER"
                :disabled="internal.configType !== 'ROUTER'"
              />
            </label>
            <label>
              {{ $t('Disabled') }}
              <input
                v-model="internal.dhcpType"
                type="radio"
                name="dhcpType"
                value="DISABLED"
                :disabled="internal.configType !== 'ROUTER'"
              />
            </label>
          </div>
        </div>
      </div>

      <!-- Transparent Bridge Section -->
      <div class="bridge-section">
        <div class="radio-group">
          <input
            id="bridge"
            v-model="internal.configType"
            type="radio"
            name="configType"
            value="BRIDGED"
            @change="setConfigType('BRIDGED')"
          />
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
      <button class="save-button" @click="onSave">{{ $t('Save') }}</button>
    </div>
  </div>
</template>

<script>
  import AutoUpgrades from '@/Setup_wizard/step/AutoUpgrades.vue'
  import Util from '@/util/setupUtils' // Adjust the import path based on your project structure

  export default {
    name: 'InternalNetwork',
    components: {
      AutoUpgrades,
    },
    props: {
      adminRpc: {
        type: Object,
        required: true,
      },
      setupRpc: {
        type: Object,
        required: true,
      },
    },
    data() {
      return {
        title: 'Internal Network',
        description: 'Configure the Internal Network Interface',
        internal: null,
        showAutoUpgrades: false,
        v4NetmaskList: Util.v4NetmaskList, // Use the imported netmask list
        initialConfig: {},
      }
    },
    mounted() {
      this.getInterface()
    },
    methods: {
      async getInterface() {
        try {
          const result = await this.adminRpc.networkManager().getNetworkSettings()
          console.log('Network Settings Response:', result)

          if (!result?.interfaces?.list || result.interfaces.list.length === 0) {
            alert('No network interfaces found. Please check your network configuration.')
            this.internal = null
            return
          }

          this.internal = result.interfaces.list.find(intf => !intf.isWan)

          if (!this.internal) {
            if (confirm('No internal interfaces found. Do you want to continue the setup?')) {
              this.$emit('nextStep')
            }
          } else {
            this.internal.configType = 'ROUTER' // Default to Router
            this.initialConfig = { ...this.internal }
          }

          console.log('Internal Interface:', this.internal)
        } catch (error) {
          console.error('Error fetching network settings:', error)
          alert('Failed to fetch network settings. Please try again later.')
        }
      },

      setConfigType(type) {
        if (type === 'BRIDGED') {
          this.internal.configType = 'BRIDGED'
        } else {
          this.internal.configType = 'ROUTER'
          this.internal.v4configType = 'STATIC'
        }
      },
      onSave() {
        if (!this.internal || !this.internal.configType) {
          alert('Invalid configuration. Please check your inputs.')
          return
        }
        console.log('this.adminRpc.networkManager()', this.adminRpc.networkManager())
        this.showAutoUpgrades = true
        // try {
        //   await this.adminRpc.networkManager().setNetworkSettings(this.internal)
        //   alert('Settings saved successfully.')
        //   this.$emit('nextStep')
        // } catch (error) {
        //   console.error('Error saving settings:', error)
        //   alert('Failed to save settings. Please try again later.')
        // }
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
