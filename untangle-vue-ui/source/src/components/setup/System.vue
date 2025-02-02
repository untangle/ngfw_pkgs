<template>
  <div>
    <SetupLayout />
    <v-card width="650" class="mx-auto mt-4" flat>
      <h2 class="font-weight-light faint-color text-h4">{{ `Configure the Server` }}</h2>
      <br />
      <br />
      <ValidationObserver v-slot="{ passes }">
        <div class="parent-container">
          <div class="custom-margin">
            <h2 class="font-weight-light">{{ `Admin Account` }}</h2>
            <br />
            <label class="font-weight-light faint-color">
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
            <label class="font-weight-light faint-color"
              >Administrators receive email alerts and report summaries</label
            >
            <br />
            <label>Adding Email:</label>
            <ValidationProvider>
              <u-text-field v-model="adminEmail" />
            </ValidationProvider>
            <br /><br />
            <u-btn :small="false" style="margin: 8px 0px" class="custom-btn" @click="onClickBack">
              {{ `Back` }}
            </u-btn>
          </div>
          <br />
          <div class="custom-margin">
            <h2 class="font-weight-light">{{ `Install Type` }}</h2>
            <br />
            <label class="font-weight-light faint-color">
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
            <label class="empty-label"> </label>
            <br />
            <br /><br /><br /><br /><br /><br />
            <u-btn :small="false" style="margin: 8px 180px" class="custom-btn-right" @click="passes(onContinue)">
              {{ `Next` }}
            </u-btn>
          </div>
        </div>
      </ValidationObserver>
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
      ...mapGetters('setup', ['newPassword', 'newPasswordConfirm', 'installType']), // Map installType from Vuex

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
          await Promise.resolve()
          await this.setShowStep('License')
        } catch (error) {
          console.error('Failed to navigate:', error)
        }
      },
      async onContinue() {
        const rpcResponseForSetup = Util.setRpcJsonrpc('setup')
        const rpcResponseForAdmin = Util.setRpcJsonrpc('admin')
        console.log(rpcResponseForSetup)
        console.log('Response rpcResponseForAdmin', rpcResponseForAdmin)

        try {
          window.rpc.setup = new window.JSONRpcClient('/setup/JSON-RPC').SetupContext // To avoid invalid security nonce
          if (this.timezoneID !== this.timezone) {
            const timezoneId = this.timezone.split(' ')[1]
            await window.rpc.setup.setTimeZone(timezoneId)
            console.log('Timezone updated successfully.', timezoneId)
          }
        } catch (error) {
          console.error('Error saving settings:', error)
          alert('Failed to save settings. Please try again.')
        }
      },
    },
  }
</script>

<style scoped>
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
    gap: 20px; /* Adds 20px space between the child divs */
  }
  .child-container {
    display: flex; /* Enables flexbox layout */
    gap: 430px; /* Adds 20px space between the child divs */
  }
  . h2.font-weight-light {
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
    height: 13px; /* Set a specific height if needed */
    background-color: white; /* Set a background color or any style */
  }
  .custom-margin {
    width: 300px; /* Fixed width for buttons */
    height: 50px; /* Fixed height for buttons */
  }
  .faint-color {
    color: rgba(0, 0, 0, 25); /* Adjust the color and opacity */
  }
  .button-container {
    display: flex;
    justify-content: flex-end; /* Aligns the button to the right */
    width: 100%; /* Ensures the container spans the full width */
  }
</style>
