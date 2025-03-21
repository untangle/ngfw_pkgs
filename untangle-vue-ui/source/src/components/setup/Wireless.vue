<template>
  <v-card width="1100" height="500" class="mx-auto mt-3" flat>
    <SetupLayout />
    <div class="wireless">
      <v-container>
        <ValidationObserver v-slot="{ passes }">
          <div v-if="wirelessSettings">
            <p class="section-paragraph">Configure Wireless Settings</p>

            <div class="container">
              <h1 class="section-header">Settings</h1>

              <v-card-text>{{ `Network Name (SSID)` }}</v-card-text>
              <ValidationProvider v-slot="{ errors }" rules="required|max:30">
                <u-text-field
                  id="ssid"
                  v-model="wirelessSettings.ssid"
                  :error-messages="errors"
                  outlined
                  dense
                  hide-details
                  class="input-box"
                  @paste="validatePaste"
                  @keydown="validateSsid"
                >
                  <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                </u-text-field>
              </ValidationProvider>
              <v-card-text>{{ `Encryption` }}</v-card-text>
              <v-autocomplete
                v-model="wirelessSettings.encryption"
                :errors="errors"
                :items="encryptionOptions"
                item-value="value"
                item-title="text"
                outlined
                dense
                hide-details
              ></v-autocomplete>

              <v-card-text>{{ `Password` }}</v-card-text>
              <ValidationProvider v-slot="{ errors }" rules="required|min:8|max:63|valide_password">
                <div @keydown="restrictPasswordInput" @paste="restrictPasswordPaste">
                  <u-password
                    v-model="wirelessSettings.password"
                    :errors="errors"
                    :disabled="wirelessSettings.encryption === 'NONE'"
                    outlined
                    dense
                    hide-details
                  />
                </div>
              </ValidationProvider>
            </div>
          </div>
          <div class="button-container">
            <u-btn :small="false" style="margin: 8px 0" @click="onClickBack">Back</u-btn>
            <u-btn :small="false" style="margin: 8px 0" @click="passes(onSave)">{{ `Next` }}</u-btn>
          </div>
        </ValidationObserver>
      </v-container>
    </div>
  </v-card>
</template>

<script>
  import { mapActions, mapGetters } from 'vuex'
  import isEqual from 'lodash/isEqual'
  import { extend } from 'vee-validate'
  import Util from '@/util/setupUtil'
  import SetupLayout from '@/layouts/SetupLayout.vue'

  export default {
    components: {
      SetupLayout,
    },
    data() {
      return {
        title: 'Wireless Settings',
        description: 'Configure Wireless Settings',
        dialog: false,
        loading: false,
        rpc: null,
        wirelessSettings: {
          ssid: null,
          encryption: null,
          password: null,
        },
        encryptionOptions: [
          { value: 'NONE', text: 'None' },
          { value: 'WPA1', text: 'WPA' },
          { value: 'WPA12', text: 'WPA /WPA2' },
          { value: 'WPA2', text: 'WPA2' },
        ],
        initialSettings: null,
        networkSettings: null,
        showDialog: false,
        saving: false,
      }
    },

    computed: {
      ...mapGetters('setup', ['wizardSteps', 'currentStep', 'previousStep']), // from Vuex
      requiredField() {
        return this.wirelessSettings.ssid !== null
      },
    },
    created() {
      this.$store.commit('SET_LOADER', true)
      extend('valide_password', this.validatePasswordField)
      this.getSettings()
    },
    methods: {
      ...mapActions('setup', ['setShowStep']),
      ...mapActions('setup', ['setShowPreviousStep']),

      validatePasswordField(value) {
        if (value === '12345678') {
          return this.$t('You must choose a new and different wireless password.', this.wirelessSettings.password)
        }
        return true
      },
      validateSsid(event) {
        const allowedChars = /^[a-zA-Z0-9\-_=]$/
        if (event.key.length > 1) {
          return
        }
        if (!allowedChars.test(event.key)) {
          event.preventDefault()
        }
      },
      validatePaste(event) {
        const pastedText = (event.clipboardData || window.clipboardData).getData('text')
        const allowedChars = /^[a-zA-Z0-9\-_=]+$/

        if (!allowedChars.test(pastedText)) {
          event.preventDefault()
        }
      },
      restrictPasswordInput(event) {
        const allowedChars = /^[a-zA-Z0-9\-_=~@#%_,!/?.()[\]^$+*.|]+$/
        if (!allowedChars.test(event.key)) {
          event.preventDefault()
        }
      },
      restrictPasswordPaste(event) {
        const pastedText = (event.clipboardData || window.clipboardData).getData('text')
        const allowedChars = /^[a-zA-Z0-9\-_=~@#%_,!/?.()[\]^$+*.|]+$/
        if (!allowedChars.test(pastedText)) {
          event.preventDefault()
        }
      },
      async getSettings() {
        this.rpc = Util.setRpcJsonrpc('admin')
        try {
          this.networkSettings = await this.rpc?.networkManager?.getNetworkSettings()
          const interfaces = await this.networkSettings.interfaces.list

          const wireless = await interfaces.find(intf => intf.isWirelessInterface)

          if (!wireless) {
            this.$vuntangle.confirm.show({
              title: `<i class="mdi mdi-alert" style="font-style: normal;"> ${this.$t('warning')}</i>`,
              message: this.$t(`Loading User Interface...`),
              confirmLabel: this.$t('yes'),
              cancelLabel: this.$t('no'),
              action: async resolve => {
                resolve()
                await Promise.resolve()
                this.nextPage()
              },
            })
          }
          this.$store.commit('SET_LOADER', true)

          // Run all requests in parallel
          const [ssid, encryption, password] = await Promise.all([
            this.getSsid(),
            this.getEncryption(),
            this.getPassword(),
          ])
          // Update wireless settings
          this.wirelessSettings = {
            ssid: ssid || '',
            encryption: encryption || 'NONE',
            password: !password || password === '12345678' ? '' : password,
          }

          this.initialSettings = { ...this.wirelessSettings }
        } catch (error) {
          this.$vuntangle.toast.add(this.$t(`Error fetching wireless settings : ${error || error.message}`))
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },
      getSsid() {
        return new Promise((resolve, reject) => {
          this.rpc.networkManager.getWirelessSsid((result, error) => {
            if (error) {
              reject(error)
            } else {
              resolve(result)
            }
          })
        })
      },
      getEncryption() {
        return new Promise((resolve, reject) => {
          this.rpc.networkManager.getWirelessEncryption((result, error) => {
            if (error) {
              reject(error)
            } else {
              resolve(result)
            }
          })
        })
      },
      getPassword() {
        return new Promise((resolve, reject) => {
          this.rpc.networkManager.getWirelessPassword((result, error) => {
            if (error) {
              reject(error)
            } else {
              resolve(result)
            }
          })
        })
      },

      async nextPage() {
        const currentStepIndex = this.wizardSteps.indexOf(this.currentStep)
        await this.setShowStep(this.wizardSteps[currentStepIndex + 1])
        await this.setShowPreviousStep(this.wizardSteps[currentStepIndex + 1])
      },
      async onClickBack() {
        try {
          const currentStepIndex = this.wizardSteps.indexOf(this.currentStep)
          await Promise.resolve()
          await this.setShowStep(this.wizardSteps[currentStepIndex - 1])
          await this.setShowPreviousStep(this.wizardSteps[currentStepIndex - 1])
        } catch (error) {
          this.$vuntangle.toast.add(this.$t(`Failed to navigate : ${error || error.message}`))
        }
      },
      async onSave() {
        if (isEqual(this.initialSettings, this.wirelessSettings)) {
          this.saving = false
          await Promise.resolve()
          this.nextPage()
        }
        this.$store.commit('SET_LOADER', true)
        if (!this.rpc || !this.rpc.networkManager) {
          this.$vuntangle.toast.add(this.$t(`RPC session expired. Re-initializing...`))
          this.rpc = Util.setRpcJsonrpc('admin')
        }
        try {
          await this.rpc.networkManager.setWirelessSettings(
            this.wirelessSettings.ssid,
            this.wirelessSettings.encryption,
            this.wirelessSettings.password,
          )
          this.$store.commit('SET_LOADER', false)
          await Promise.resolve()
          this.nextPage()
        } catch (error) {
          this.$store.commit('SET_LOADER', false)
          this.$vuntangle.toast.add(this.$t(`Error saving wireless settings : ${error || error.message}`))
        }
      },
    },
  }
</script>

<style scoped>
  .step-title {
    color: #2c2b2b;
    font-size: 25px;
  }
  .button-container {
    display: flex;
    justify-content: space-between;
    align-items: center;
    width: 74%;
    position: absolute;
    bottom: 20px;
    left: 0;
    padding: 10px 20px;
    gap: 20px;
    background-color: #f9f9f9;
    margin-left: 150px;
    margin-bottom: -90px;
  }
  .faint-color {
    color: rgba(0, 0, 0, 0.5);
  }
  .wireless {
    margin: 20px 120px 10px 120px;
    border: 1px solid #ccc;
    background-color: #f9f9f9;
    height: 120%;
    overflow: hidden;
    padding: 30px 10px 10px 20px;
  }
  .container {
    padding-top: 0px;
  }

  .section-header {
    font-size: 24px;
    margin-bottom: 15px;
  }
  .section-paragraph {
    font-size: 30px;
    margin-bottom: 15px;
  }

  .label {
    font-family: 'Arial', sans-serif;
    font-size: 20px;
    font-weight: bold;
    color: #333;
  }

  input,
  select {
    width: 100%;
    padding: 8px;
    margin-top: 5px;
    border: black;
    border-radius: 2px;
    border-color: black;
  }
  .input {
    font-family: 'Arial', sans-serif;
    font-size: 25px;
  }
  .custom-margin {
    width: 400px;
    margin-left: 100px;
  }
</style>
