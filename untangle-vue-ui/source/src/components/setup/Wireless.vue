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

              <label>{{ `Network Name (SSID)` }}</label>
              <ValidationProvider v-slot="{ errors }" rules="required|max:30">
                <u-text-field
                  id="ssid"
                  v-model="wirelessSettings.ssid"
                  :error-messages="errors"
                  outlined
                  dense
                  hide-details
                  class="input-box"
                  @keydown="validateSsid"
                >
                  <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                </u-text-field>
              </ValidationProvider>
              <label>{{ `Encryption` }}</label>
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

              <label>{{ `Password` }}</label>
              <ValidationProvider v-slot="{ errors }" :rules="{ required: passwordRequired, min: 8, max: 63 }">
                <div @keydown="restrictPasswordInput">
                  <u-password
                    v-model="wirelessSettings.password"
                    :errors="errors"
                    :disabled="wirelessSettings.encryption === 'NONE'"
                    outlined
                    dense
                    hide-details
                    @input="validatePasswordField"
                  />
                </div>
              </ValidationProvider>
            </div>
          </div>
          <div class="button-container">
            <u-btn :small="false" style="margin: 8px 0" @click="onClickBack">Back</u-btn>
            <u-btn :small="false" style="margin: 8px 0" @click="passes(onSave)">{{ `Next` }}</u-btn>
          </div>
          <v-dialog v-model="dialog" persistent max-width="290">
            <v-card>
              <v-card-title class="headline">Warning!</v-card-title>
              <v-card-text> No wireless interfaces found. Do you want to continue the setup? </v-card-text>
              <v-card-actions>
                <v-btn color="green" text @click="onConfirm">Yes</v-btn>
                <v-btn color="red" text @click="onCancel">No</v-btn>
              </v-card-actions>
            </v-card>
          </v-dialog>
          <v-dialog v-model="loading" persistent max-width="300">
            <v-card>
              <v-card-title class="headline"> Please Wait </v-card-title>
              <v-card-text>
                Loading User Interface...
                <v-progress-circular indeterminate color="primary" size="64" width="6"></v-progress-circular>
              </v-card-text>
            </v-card>
          </v-dialog>
          <v-dialog v-model="saving" persistent max-width="300">
            <v-card>
              <v-card-title class="headline"> Please Wait </v-card-title>
              <v-card-text>
                Saving Settings...
                <v-progress-circular indeterminate color="primary" size="64" width="6"></v-progress-circular>
              </v-card-text>
            </v-card>
          </v-dialog>
        </ValidationObserver>
        <v-dialog v-model="showDialog" max-width="400">
          <v-card>
            <v-card-title class="headline"></v-card-title>
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
    </div>
  </v-card>
</template>

<script>
  import { mapActions } from 'vuex'
  import isEqual from 'lodash/isEqual'
  // import { max } from 'lodash'
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
      passwordRequired() {
        return this.wirelessSettings.encryption !== 'NONE'
      },
      requiredField() {
        return this.wirelessSettings.ssid !== null
      },
    },
    created() {
      this.getSettings()
    },
    methods: {
      ...mapActions('setup', ['setShowStep']),
      ...mapActions('setup', ['setShowPreviousStep']),

      validatePasswordField() {
        if (this.wirelessSettings.password === '12345678') {
          this.showWarning('You must choose a new and different wireless password.')
        }
      },
      validateSsid(event) {
        const allowedChars = /^[a-zA-Z0-9\-_=]$/
        // Allow backspace, delete, arrow keys, tab
        if (['Backspace', 'Delete', 'ArrowLeft', 'ArrowRight', 'Tab'].includes(event.key)) {
          return
        }
        if (!allowedChars.test(event.key)) {
          event.preventDefault() // Prevents the character from being entered
        }
      },
      restrictPasswordInput(event) {
        const allowedChars = /^[a-zA-Z0-9\-_=~@#%_,!/?.()[\]^$+*.|]+$/
        if (['Backspace', 'Delete', 'ArrowLeft', 'ArrowRight', 'Tab'].includes(event.key)) {
          return
        }
        if (!allowedChars.test(event.key)) {
          event.preventDefault() // Prevents the character from being entered
        }
      },
      showDialogBox() {
        this.dialog = true
      },
      async onConfirm() {
        this.dialog = false
        await Promise.resolve()
        await this.setShowStep('System')
        await this.setShowPreviousStep('System')
      },
      onCancel() {
        this.dialog = false
      },
      async getSettings() {
        this.rpc = Util.setRpcJsonrpc('admin')
        try {
          this.networkSettings = await this.rpc?.networkManager?.getNetworkSettings()
          const interfaces = await this.networkSettings.interfaces.list

          const wireless = await interfaces.find(intf => intf.isWirelessInterface)

          if (!wireless) {
            this.showDialogBox()
          }
          this.loading = true
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
          this.loading = false
        } catch (error) {
          this.showWarning(`Error fetching wireless settings: ${error.message || error}`)
        } finally {
          this.loading = false
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
      async onClickBack() {
        try {
          await Promise.resolve()
          await this.setShowStep('wizard')
          await this.setShowPreviousStep('wizard')
        } catch (error) {
          this.showWarning(`Failed to navigate: ${error.message || error}`)
        }
      },
      async onSave() {
        this.saving = true
        if (isEqual(this.initialSettings, this.wirelessSettings)) {
          this.saving = false
          await Promise.resolve()
          await this.setShowStep('System')
          await this.setShowPreviousStep('System')
          return
        }
        if (!this.rpc || !this.rpc.networkManager) {
          this.showWarning('RPC session expired. Re-initializing...')
          this.rpc = Util.setRpcJsonrpc('admin')
        }
        try {
          await this.rpc.networkManager.setWirelessSettings(
            this.wirelessSettings.ssid,
            this.wirelessSettings.encryption,
            this.wirelessSettings.password,
          )
          this.saving = false
          await Promise.resolve()
          await this.setShowStep('System')
          await this.setShowPreviousStep('System')
        } catch (error) {
          this.saving = false
          this.showWarning(`Error saving wireless settings: ${error.message || error}`)
        }
      },
      showWarning(message) {
        this.dialogMessage = message
        this.showDialog = true
      },
      closeDialog() {
        this.showDialog = false
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
