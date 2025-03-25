<template>
  <v-container>
    <v-card width="900" height="500" class="mx-auto mt-3 pa-3" flat>
      <SetupLayout />
      <div
        class="pa-6 mt-4 mx-auto grey lighten-4 border rounded d-flex flex-column"
        style="border: 1px solid #e0e0e0 !important"
      >
        <h1 class="font-weight-light faint-color text-h4">{{ title }}</h1>
        <v-container class="flex-grow-1">
          <v-row class="flex-column align-center">
            <v-col class="text-left pa-1 ma-1">
              <v-card-text class="pa-0 ma-0 text-body-2 font-weight-bold">Network Name (SSID)</v-card-text>
            </v-col>
            <v-col cols="12" class="pa-0 ma-0">
              <ValidationProvider v-slot="{ errors }" rules="required|max:30">
                <u-text-field
                  id="ssid"
                  v-model="wirelessSettings.ssid"
                  :error-messages="errors"
                  outlined
                  dense
                  hide-details
                  class="input-box mx-auto"
                  @paste="validatePaste"
                  @keydown="validateSsid"
                >
                  <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
                </u-text-field>
              </ValidationProvider>
            </v-col>
          </v-row>

          <v-row class="flex-column align-center">
            <v-col class="text-left pa-1 ma-1">
              <v-card-text class="pa-0 ma-0 text-body-2 font-weight-bold">Encryption</v-card-text>
            </v-col>
            <v-col cols="12" class="pa-0 ma-0">
              <v-autocomplete
                v-model="wirelessSettings.encryption"
                :errors="errors"
                :items="encryptionOptions"
                item-value="value"
                item-title="text"
                outlined
                dense
                hide-details
                class="mx-auto"
              ></v-autocomplete>
            </v-col>
          </v-row>

          <v-row class="flex-column align-center">
            <v-col class="text-left pa-1 ma-1">
              <v-card-text class="pa-0 ma-0 text-body-2 font-weight-bold">Password</v-card-text>
            </v-col>
            <v-col cols="12" class="pa-0 ma-0">
              <ValidationProvider v-slot="{ errors }" rules="required|min:8|max:63|valide_password">
                <div @keydown="restrictPasswordInput" @paste="restrictPasswordPaste">
                  <u-password
                    v-model="wirelessSettings.password"
                    :errors="errors"
                    :disabled="wirelessSettings.encryption === 'NONE'"
                    outlined
                    dense
                    hide-details
                    class="mx-auto"
                  />
                </div>
              </ValidationProvider>
            </v-col>
          </v-row>

          <!-- Buttons -->
          <!-- <v-row class="justify-space-between mt-16 px-4">
            <v-col cols="auto align-self-end">
              <u-btn :small="false" @click="onClickBack">Back</u-btn>
            </v-col>
            <v-col cols="auto align-self-end">
              <u-btn :small="false" @click="passes(onSave)">Next</u-btn>
            </v-col>
          </v-row> -->
        </v-container>
        <div class="d-flex justify-space-between pa-7" style="position: relative">
          <u-btn :small="false" @click="onClickBack">{{ `Back` }}</u-btn>
          <u-btn :small="false" @click="onSave">{{ `Next` }}</u-btn>
        </div>
      </div>
    </v-card>
  </v-container>
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
