<template>
  <v-card width="1100" height="500" class="mx-auto mt-3" flat>
    <SetupLayout />
    <div class="wireless">
      <v-container>
        <div v-if="wirelessSettings">
          <p class="section-paragraph">Configure Wireless Settings</p>

          <div class="container">
            <!-- Section Header -->
            <h1 class="section-header">Settings</h1>

            <!-- SSID (Network Name) -->
            <label>{{ `Network Name (SSID)` }}</label>
            <u-text-field
              id="ssid"
              v-model="wirelessSettings.ssid"
              maxlength="30"
              pattern="[a-zA-Z0-9\\-_=]*"
              required
              outlined
              dense
              hide-details
              class="input-box"
            />
            <label>{{ `Encryption` }}</label>
            <v-autocomplete
              v-model="wirelessSettings.encryption"
              :items="encryptionOptions"
              item-value="value"
              item-title="text"
              outlined
              dense
              hide-details
            ></v-autocomplete>

            <label>{{ `Password` }}</label>
            <ValidationProvider
              v-slot="{ errors }"
              vid="newPassword"
              :rules="{ required: passwordRequired, min: 8, max: 63 }"
            >
              <u-password
                v-model="wirelessSettings.password"
                :errors="errors"
                :disabled="wirelessSettings.encryption === 'WPA'"
                outlined
                dense
                hide-details
                @NONE="validatePassword"
              />
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
      </v-container>
    </div>
  </v-card>
</template>

<script>
  import { ref } from 'vue'
  import Util from '@/util/setupUtil'
  import SetupLayout from '@/layouts/SetupLayout.vue'
  const passwordError = ref('')
  console.log('passwordError:', passwordError)

  export default {
    components: {
      SetupLayout,
    },
    data() {
      return {
        title: 'Wireless Settings',
        description: 'Configure Wireless Settings',
        interfaces: [],
        wireless: {},
        dialog: false,
        loading: false,
        rpc: null,
        wirelessSettings: {
          ssid: 'ssid',
          encryption: 'NONE',
          password: 'password',
        },
        encryptionOptions: [
          { value: 'NONE', text: 'None' },
          { value: 'WPA1', text: 'WPA' },
          { value: 'WPA12', text: 'WPA /WPA2' },
          { value: 'WPA2', text: 'WPA2' },
        ],
        initialSettings: {},
      }
    },
    computed: {
      passwordRequired() {
        return this.$store.state.setup?.status?.step ? this.$store.state.setup?.status.step === 'system' : true
      },
    },
    created() {
      this.rpc = Util.setRpcJsonrpc('admin')
      this.getSsid()
      this.getEncryption()
      this.getPassword()
      this.getSettings()
    },
    methods: {
      showDialog() {
        this.dialog = true
      },
      onConfirm() {
        this.dialog = false
        // TODO
        // me.getView().up('setupwizard').down('#nextBtn').click()
      },
      onCancel() {
        this.dialog = false
      },
      async getSettings() {
        try {
          this.networkSettings = await this.rpc?.networkManager?.getNetworkSettings()
          this.interfaces = this.networkSettings.interfaces.list

          this.wireless = this.interfaces.find(intf => intf.isWirelessInterface)

          console.log(this.networkSettings)

          if (!this.wireless) {
            this.showDialog()
          }
          this.loading = true
          setTimeout(() => {
            this.loading = false
          }, 3000)
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
        } catch (error) {
          console.error('Error fetching wireless settings:', error)
        } finally {
          this.loading = false // Stop loading indicator
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
      onClickBack() {
        // previous page
      },
      onSave() {
        this.loading = true
        if (this.initialSettings === this.wirelessSettings) {
          // continue to next step
          return
        }
        this.initialSettings.ssid = this.wirelessSettings.ssid
        this.initialSettings.encryption = this.wirelessSettings.encryption
        this.initialSettings.password = this.wirelessSettings.password

        this.rpc.networkManager.setWirelessSettings(this.initialSettings)
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
    justify-content: space-between; /* Places Back & Next at extreme left & right */
    align-items: center;
    width: 74%;
    position: absolute;
    bottom: 20px; /* Keeps it at a fixed position from bottom */
    left: 0;
    padding: 10px 20px; /* Adds padding for spacing */
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
    /* font-family: Arial, sans-serif; */
    height: 120%;
    overflow: hidden;
    padding: 30px 10px 10px 20px;
    /* font-size: 90px; */
  }
  .container {
    /* display: flex; */
    /* justify-content: left; */
    padding-top: 0px;
  }

  .section-header {
    font-size: 24px;
    /* font-weight: bold; */
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
    color: #333; /* Optional: Adjust text color */
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
    /* height: 50px; */
  }
</style>
