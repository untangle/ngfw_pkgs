<template>
  <v-container>
    <v-card width="900" class="mx-auto mt-4" flat>
      <SetupLayout />
      <div
        class="pa-6 mt-4 mx-auto grey lighten-4 border rounded d-flex flex-column"
        style="border: 1px solid #e0e0e0 !important"
      >
        <h1 class="font-weight-light faint-color text-h4 mb-6">{{ `Configure the Server` }}</h1>

        <ValidationObserver v-slot="{ passes }">
          <v-row>
            <v-col cols="12" md="6">
              <p class="font-weight-light text-h5 text">Admin Account</p>
              <p class="text-h7 mt-1">
                Choose a password for the <strong class="font-weight-bold">admin</strong> account
              </p>
              <v-row>
                <v-col cols="12" class="mt-6">
                  <span>Password:</span>
                  <ValidationProvider
                    v-slot="{ errors }"
                    vid="newPassword"
                    :rules="{ required: passwordRequired, min: 3 }"
                  >
                    <u-password v-model="newPasswordSync" :errors="errors" />
                  </ValidationProvider>
                </v-col>

                <v-col cols="12">
                  <span>Confirm Password:</span>
                  <ValidationProvider
                    v-slot="{ errors }"
                    name="confirmPassword"
                    :rules="{ required: !!(passwordRequired || newPassword), confirmed: 'newPassword' }"
                  >
                    <u-password v-model="newPasswordConfirmSync" :errors="errors" />
                  </ValidationProvider>
                </v-col>

                <v-col class="mt-0 pt-0" cols="12">
                  <p class="text-h7 mt-1">Administrators receive email alerts and report summaries</p>
                  <span>Admin Email:</span>
                  <ValidationProvider v-slot="{ errors }" rules="required">
                    <u-text-field v-model="adminEmail" :error-messages="errors">
                      <template v-if="errors.length" #append>
                        <u-errors-tooltip :errors="errors" />
                      </template>
                    </u-text-field>
                  </ValidationProvider>
                </v-col>
              </v-row>
            </v-col>

            <v-col cols="12" md="6">
              <p class="font-weight-light text-h5 text">Install Type</p>
              <p class="text-h7 mt-1">Install type determines the optimal default settings for this deployment</p>
              <!-- <p class="text-h6 font-weight-medium grey--text mt-0 mb-0">
                Install type determines the optimal default settings for this deployment
              </p> -->

              <v-row>
                <v-col cols="12">
                  <span>Choose Type:</span>
                  <ValidationProvider v-slot="{ errors }" rules="required">
                    <v-autocomplete
                      v-model="installTypeSync"
                      :items="typeOptions"
                      outlined
                      dense
                      hide-details
                      return-object
                      placeholder="Select Type"
                      :error-messages="errors"
                    >
                      <template v-if="errors.length" #append>
                        <u-errors-tooltip :errors="errors" />
                      </template>
                    </v-autocomplete>
                  </ValidationProvider>
                </v-col>

                <v-col cols="12">
                  <span>Timezone:</span>
                  <ValidationProvider v-slot="{ errors }" rules="required">
                    <v-autocomplete
                      v-model="timezone"
                      :items="timezones"
                      outlined
                      dense
                      hide-details
                      return-object
                      :error-messages="errors"
                    >
                    </v-autocomplete>
                  </ValidationProvider>
                </v-col>
              </v-row>
            </v-col>
          </v-row>

          <!-- Buttons (Back & Next) -->
          <v-row class="justify-space-between mt-16 px-4">
            <v-col cols="auto align-self-end">
              <u-btn :small="false" @click="onClickBack">{{ `Back` }}</u-btn>
            </v-col>
            <v-col cols="auto align-self-end">
              <u-btn :small="false" @click="passes(onContinue)">{{ `Next` }}</u-btn>
            </v-col>
          </v-row>
        </ValidationObserver>
      </div>
    </v-card>
  </v-container>
</template>

<script>
  import { mapActions, mapGetters } from 'vuex'
  import Util from '@/util/setupUtil'
  import SetupLayout from '@/layouts/SetupLayout.vue'

  export default {
    components: {
      SetupLayout,
    },
    data() {
      return {
        adminEmail: '',
        timezoneID: '',
        timezone: '',
        timezones: '',
        loading: false,
        typeOptions: [
          { value: 'school', text: 'School' },
          { value: 'college', text: 'Higher Education' },
          { value: 'government', text: 'State & Local Government' },
          { value: 'fedgovernment', text: 'Federal Government' },
          { value: 'nonprofit', text: 'Nonprofit' },
          { value: 'retail', text: 'Hospitality & Retail' },
          { value: 'healthcare', text: 'Healthcare' },
          { value: 'financial', text: 'Banking & Financial' },
          { value: 'home', text: 'Home' },
          { value: 'student', text: 'Student' },
          { value: 'other', text: 'Other' },
        ],
      }
    },
    computed: {
      ...mapGetters('setup', [
        'newPassword',
        'newPasswordConfirm',
        'installType',
        'wizardSteps',
        'currentStep',
        'previousStep',
      ]), // from Vuex

      passwordRequired() {
        return this.$store.state.setup?.status?.step ? this.$store.state.setup?.status.step === 'system' : true
      },
      newPasswordSync: {
        get() {
          return this.newPassword // Vuex getter
        },
        set(value) {
          this.$store.dispatch('setup/setNewPassword', value) // Vuex action to update password
        },
      },
      newPasswordConfirmSync: {
        get() {
          return this.newPasswordConfirm // Vuex getter
        },
        set(value) {
          this.$store.dispatch('setup/setNewPasswordConfirm', value) // Vuex action to update confirm password
        },
      },
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
      const rpcResponseForSetup = Util.setRpcJsonrpc('setup')
      this.adminEmail = rpcResponseForSetup?.adminEmail
      this.timezoneID = rpcResponseForSetup?.timezoneID
      this.timezones = []

      const jsonStr = rpcResponseForSetup.timezones.replace(/'/g, '"')
      const timezonesArray = JSON.parse(jsonStr)
      if (timezonesArray) {
        for (let i = 0; i < timezonesArray.length; i++) {
          const timezone = `(${timezonesArray[i][1]}) ${timezonesArray[i][0]}`
          this.timezones.push(timezone)
          if (this.timezoneID === timezonesArray[i][0]) {
            this.timezone = timezone
          }
        }
      }
    },
    methods: {
      ...mapActions('setup', ['setShowStep']),
      ...mapActions('setup', ['setShowPreviousStep']),
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
      async onContinue() {
        try {
          const currentStepIndex = this.wizardSteps.indexOf(this.currentStep)
          // Ung.app.loading('loading')
          window.rpc.setup = new window.JSONRpcClient('/setup/JSON-RPC').SetupContext // To avoid invalid security nonce
          if (this.timezoneID !== this.timezone) {
            const timezoneId = this.timezone.split(' ')[1]
            await window.rpc.setup.setTimeZone(timezoneId)
            await this.saveAdminPassword()
          } else {
            await this.saveAdminPassword()
          }
          await Util.updateWizardSettings(this.currentStep)
          await this.setShowStep(this.wizardSteps[currentStepIndex + 1])
          await this.setShowPreviousStep(this.wizardSteps[currentStepIndex + 1])
        } catch (error) {
          this.$vuntangle.toast.add(this.$t(`Error saving settings: ${error || error.message}`))
          alert('Failed to save settings. Please try again.')
        }
      },
      async saveAdminPassword() {
        try {
          // Update admin password
          await window.rpc.setup.setAdminPassword(this.newPassword, this.adminEmail, this.installType.value)
          // Authenticate the updated password
          await new Promise((resolve, reject) => {
            this.$store.commit('SET_LOADER', true)
            Util.authenticate(this.newPassword, (error, success) => {
              if (error || !success) {
                this.$vuntangle.toast.add(
                  this.$t(`Authentication failed after password update: ${error || error.message}`),
                )
                reject(new Error('Authentication failed after password update.'))
              } else {
                resolve()
                this.showInterfaces = true
              }
            })
          })
        } catch (error) {
          this.$store.commit('SET_LOADER', false) // Stop loader
          this.$vuntangle.toast.add(this.$t(`Error saving admin password or authenticating: ${error || error.message}`))
          throw error
        } finally {
          this.$store.commit('SET_LOADER', false)
        }
      },
    },
  }
</script>
