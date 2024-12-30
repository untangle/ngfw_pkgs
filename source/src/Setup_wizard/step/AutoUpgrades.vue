<template>
  <Complete v-if="showComplete" :setup-rpc="setupRpc" :admin-rpc="adminRpc" />

  <div v-else class="auto-upgrades">
    <h1>{{ title }}</h1>
    <p>{{ description }}</p>

    <div class="checkbox-container">
      <label>
        <input v-model="systemSettings.autoUpgrade" type="checkbox" checked />
        <strong>{{ $t('Automatically Install Upgrades') }}</strong>
      </label>
      <p class="info-text">
        {{
          $t(
            'Automatically install new versions of the software when available. This is the recommended choice for most sites.',
          )
        }}
      </p>
    </div>

    <div v-if="!isCCHidden" class="checkbox-container">
      <label>
        <input v-model="systemSettings.cloudEnabled" type="checkbox" checked />
        <strong>{{ $t('Connect to ETM Dashboard') }}</strong>
      </label>
      <p class="info-text">
        {{
          $t(
            'Remain securely connected to the ETM Dashboard for cloud management, hot fixes, and support access. This is the recommended choice for most sites.',
          )
        }}
      </p>
    </div>

    <button @click="onSave">{{ $t('Finish') }}<span class="arrow">→</span></button>
  </div>
</template>

<script>
  import { mapState } from 'vuex'
  import Complete from './Complete.vue'

  export default {
    name: 'AutoUpgrades',
    components: {
      Complete,
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
        title: this.$t('Auto Upgrades'),
        description: this.isCCHidden
          ? this.$t('Automatic Upgrades')
          : this.$t('Automatic Upgrades and ETM Dashboard Access'),
        systemSettings: {
          autoUpgrade: true,
          cloudEnabled: true,
        },
        initialValues: {},
        isCCHidden: false,
        showComplete: false,
        rpc: {},
      }
    },
    computed: {
      ...mapState(['rpc']),
    },
    mounted() {
      this.getSettings()
    },
    methods: {
      async getSettings() {
        try {
          this.$store.commit('setLoading', true)
          this.rpc = await new window.JSONRpcClient('/admin/JSON-RPC').UvmContext
          console.log('this.rpc', this.rpc)

          const result = await this.rpc.systemManager().getSettings()

          this.systemSettings = result
          this.initialValues = {
            autoUpgrade: result.autoUpgrade,
            cloudEnabled: result.cloudEnabled,
          }

          if (this.rpc.isCCHidden) {
            this.isCCHidden = true
            this.systemSettings.cloudEnabled = false
            this.description = this.$t('Automatic Upgrades')
          }
        } catch (error) {
          console.error('Error fetching settings:', error)
          this.$store.dispatch('handleException', error)
        } finally {
          this.$store.commit('setLoading', false)
        }
      },
      onSave() {
        // Check for changes
        this.showComplete = true
        // if (
        //   this.initialValues.autoUpgrade === this.systemSettings.autoUpgrade &&
        //   this.initialValues.cloudEnabled === this.systemSettings.cloudEnabled
        // ) {
        //   this.$emit('nextStep')
        //   return
        // }

        // // Enable support if cloudEnabled is true
        // if (this.systemSettings.cloudEnabled) {
        //   this.systemSettings.supportEnabled = true
        // }

        // try {
        //   this.$store.commit('setLoading', true)
        //   await this.rpc.systemManager.setSettings(this.systemSettings)
        //   alert(this.$t('Settings saved successfully.'))
        //   this.$emit('nextStep')
        // } catch (error) {
        //   console.error('Error saving settings:', error)
        //   this.$store.dispatch('handleException', error)
        // } finally {
        //   this.$store.commit('setLoading', false)
        // }
      },
    },
  }
</script>

<style scoped>
  .auto-upgrades {
    padding: 20px;
    font-family: Arial, sans-serif;
    border: 1px solid #ccc;
    border-radius: 5px;
  }

  .checkbox-container {
    margin-bottom: 20px;
    display: flex;
    align-items: flex-start;
  }

  .checkbox-container label {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .info-text {
    margin-left: 20px;
    font-size: 14px;
    color: #555;
    text-align: left;
  }

  button {
    padding: 10px 20px;
    background-color: #007bff;
    color: #fff;
    border: none;
    border-radius: 5px;
    cursor: pointer;
  }

  button:hover {
    background-color: #0056b3;
  }
  .internet-button .arrow {
    margin-left: 8px;
    font-size: 18px;
  }
</style>
