<template>
  <div>
    <v-card width="900" class="mx-auto mt-4" flat>
      <SetupLayout />
      <v-container class="main-div">
        <div class="step-title">Configure the Server</div>

        <!-- <h2 class="font-weight-light faint-color text-h4">{{ `Configure the Server` }}</h2> -->
        <br />
        <br />
        <ValidationObserver v-slot="{ passes }">
          <div class="parent-container">
            <div class="custom-margin">
              <h2 class="sectionheader">{{ `Admin Account` }}</h2>
              <br />
              <label style="color: rgb(153, 153, 153); margin: 0px; right: auto; left: 0px; width: 300px; top: 29px">
                Choose a password for the <strong>admin</strong><br />
                account
              </label>
              <br />
              <label>Password:</label>
              <ValidationProvider v-slot="{ errors }" vid="newPassword" :rules="{ required: passwordRequired, min: 3 }">
                <u-password v-model="newPasswordSync" :errors="errors" />
              </ValidationProvider>
              <br />
              <label>Confirm Password:</label>
              <ValidationProvider
                v-slot="{ errors }"
                name="confirmPassword"
                :rules="{ required: !!(passwordRequired || newPassword), confirmed: 'newPassword' }"
              >
                <u-password v-model="newPasswordConfirmSync" :errors="errors" />
              </ValidationProvider>
              <br />
              <label style="color: rgb(153, 153, 153); margin: 0px; right: auto; left: 0px; width: 300px; top: 29px"
                >Administrators receive email alerts and report summaries</label
              >
              <br />
              <label>Adding Email:</label>
              <ValidationProvider>
                <u-text-field v-model="adminEmail" />
              </ValidationProvider>
              <br /><br />
              <!-- <u-btn :small="false" style="margin: 8px 0px" class="custom-btn" @click="onClickBack">
                {{ `Back` }}
              </u-btn> -->
            </div>
            <br />
            <div class="custom-margin">
              <label class="sectionheader">{{ `Install Type` }}</label>
              <br />
              <label style="color: rgb(153, 153, 153); margin: 0px; right: auto; left: 0px; width: 300px; top: 29px">
                Install type determines the optimal default settings for this deployment
              </label>
              <br />
              <label>Choose Type:</label>
              <ValidationProvider v-slot="{ errors }" rules="required">
                <v-autocomplete
                  v-model="installTypeSync"
                  :items="typeOptions"
                  outlined
                  dense
                  hide-details
                  return-object
                  placeholder="Select Type"
                >
                  <template v-if="errors.length" #append>
                    <u-errors-tooltip :errors="errors" />
                  </template>
                </v-autocomplete>
              </ValidationProvider>
              <br />
              <label>Timezone:</label>
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
              <!-- <label class="empty-label"> </label> -->
              <div class="button-container">
                <u-btn :small="false" style="margin: 8px 0" @click="onClickBack">Back</u-btn>
                <u-btn :small="false" style="margin: 8px 0" @click="passes(onContinue)">{{ `Next` }}</u-btn>
                <!-- :disabled="invalid" -->
              </div>
              <!-- <u-btn :small="false" style="margin: 8px 180px" class="custom-btn-right" @click="passes(onContinue)">
                {{ `Next` }}
              </u-btn> -->
            </div>
          </div>
        </ValidationObserver>
      </v-container>
    </v-card>
  </div>
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
        // installType: '',
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
      console.log('installType from Vuex:', this.installType) // Should now show the correct initial value

      const rpcResponseForSetup = Util.setRpcJsonrpc('setup')
      console.log('Response', rpcResponseForSetup)

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
      ...mapActions('setup', ['setShowStep']), // Map the setShowStep action from Vuex store
      ...mapActions('setup', ['setShowPreviousStep']),
      async onClickBack() {
        try {
          const currentStepIndex = this.wizardSteps.indexOf(this.currentStep)
          await Promise.resolve()
          await this.setShowStep(this.wizardSteps[currentStepIndex - 1])
        } catch (error) {
          console.error('Failed to navigate:', error)
        }
      },
      async onContinue() {
        try {
          const currentStepIndex = this.wizardSteps.indexOf(this.currentStep)
          window.rpc.setup = new window.JSONRpcClient('/setup/JSON-RPC').SetupContext // To avoid invalid security nonce
          if (this.timezoneID !== this.timezone) {
            const timezoneId = this.timezone.split(' ')[1]
            await window.rpc.setup.setTimeZone(timezoneId)
          }
          await this.saveAdminPassword()
          await this.setShowStep(this.wizardSteps[currentStepIndex + 1])
          await this.setShowPreviousStep(this.wizardSteps[currentStepIndex + 1])
        } catch (error) {
          console.error('Error saving settings:', error)
          alert('Failed to save settings. Please try again.')
        }
      },
      async saveAdminPassword() {
        try {
          // Update admin password
          await window.rpc.setup.setAdminPassword(this.newPassword, this.adminEmail, this.installType.value)
          // Authenticate the updated password
          await new Promise((resolve, reject) => {
            Util.authenticate(this.newPassword, (error, success) => {
              console.log('Authentication error:', error)
              console.log('Authentication success:', success)
              if (error || !success) {
                console.error('Authentication failed after password update:', error)
                reject(new Error('Authentication failed after password update.'))
              } else {
                resolve()
                this.showInterfaces = true
              }
            })
          })
        } catch (error) {
          console.error('Error saving admin password or authenticating:', error)
          throw error
        }
      },
    },
  }
</script>

<style scoped>
  .main-div {
    /* max-width: 1100px; */
    display: flex;
    flex-direction: column;
    justify-content: flex-start; /* Align content to the top */
    /* align-items: center; */
    padding: 20px;
    justify-content: flex-start;
    border: 1px solid #ccc;
    border-radius: 5px;
    background-color: #f9f9f9;
    font-family: Arial, sans-serif;
    min-height: 600px; /* Ensures the minimum height remains constant */
    max-height: 700px; /* Prevents the height from changing too much */
    height: 700px; /* Set a fixed height to keep the div consistent */
    overflow-y: auto;
    position: relative; /* Ensures children stay within boundary */
  }
  .step-title {
    font-family: 'Roboto Condensed', sans-serif;
    font-weight: 100;
    color: #999;
    font-size: 36px;
  }
  .sectionheader {
    font-family: 'Roboto Condensed', sans-serif;
    font-size: 35px;
    color: #555;
  }
  .network-cards-panel {
    display: flex;
    flex-direction: column;
    height: 70%;
    padding: 20px;
    border: 1px solid #ccc;
    border-radius: 5px;
    background-color: #f9f9f9;
    margin: 20px;
    margin-left: 300px;
    margin-right: 300px;
  }
  .parent-container {
    display: flex; /* Enables flexbox layout */
    justify-content: center;
    align-items: center;
    gap: 20px; /* Adds 20px space between the child divs */
  }
  .child-container {
    display: flex; /* Enables flexbox layout */
    gap: 430px; /* Adds 20px space between the child divs */
  }
  .h2.font-weight-light {
    font-weight: bold; /* Or try 'bold' for a stronger weight */
  }
  .button-text {
    margin-left: 65px;
    margin-right: -10px;
    display: inline-block;
  }
  .custom-btn {
    margin-left: auto;
    width: 10px; /* Fixed width for buttons */
    height: 50px; /* Fixed height for buttons */
    font-size: 16px; /* Text size */
    border-radius: 5px; /* Optional: rounded corners */
    text-align: center; /* Center text */
  }
  .custom-btn-right {
    margin-left: auto;
    width: 10px; /* Fixed width for buttons */
    height: 50px; /* Fixed height for buttons */
    font-size: 16px; /* Text size */
    border-radius: 5px; /* Optional: rounded corners */
    text-align: right;
  }
  .empty-label {
    display: block; /* Ensures the label takes up space and is on its own line */
    height: 183px; /* Set a specific height if needed */
    background-color: white; /* Set a background color or any style */
  }
  .custom-margin {
    width: 300px; /* Fixed width for buttons */
    height: 50px; /* Fixed height for buttons */
  }
  .faint-color {
    color: rgba(0, 0, 0, 25); /* Adjust the color and opacity */
  }
  /* .button-container {
    display: flex;
    justify-content: flex-end; 
    width: 100%; 
  } */
  /* Button Container */
  .button-container {
    display: flex;
    justify-content: space-between; /* Places Back & Next at extreme left & right */
    align-items: center;
    width: 100%;
    position: absolute;
    bottom: 20px; /* Keeps it at a fixed position from bottom */
    left: 0;
    padding: 10px 20px; /* Adds padding for spacing */

    background-color: #f9f9f9;
  }
</style>
