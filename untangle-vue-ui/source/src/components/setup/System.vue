<template>
  <v-card width="650" class="mx-auto mt-4" flat>
    <h2 class="font-weight-light faint-color text-h4">{{ `Configure the Server` }}</h2>
    <br />
    <br />
    <ValidationObserver v-slot="{ passes }">
      <div class="parent-container">
        <div class="custom-margin">
          <h2 class="font-weight-light">{{ `Admin Account` }}</h2>
          <br />
          <label class="font-weight-light faint-color"
            >Choose a password for the <strong>admin</strong><br />
            account</label
          >
          <br />
          <label>Password:</label>
          <ValidationProvider v-slot="{ errors }" vid="newPassword" :rules="{ required: passwordRequired, min: 3 }">
            <u-password v-model="newPassword" :errors="errors" />
          </ValidationProvider>
          <br />
          <label>Confirm Password:</label>
          <ValidationProvider
            v-slot="{ errors }"
            name="confirmPassword"
            :rules="{ required: !!(passwordRequired || newPassword), confirmed: 'newPassword' }"
          >
            <u-password v-model="newPasswordConfirm" :errors="errors" />
          </ValidationProvider>
          <br />
          <label>Adding Email:</label>
          <ValidationProvider>
            <u-text-field v-model="adminEmail" />
          </ValidationProvider>
          <label class="font-weight-light faint-color">Administrators receive email alerts and report summaries</label>
          <u-btn :small="false" style="margin: 8px 0x" class="custom-btn" @click="onClickLicense">
            <span class="arrow-icon-left">←</span>
            <span class="button-text">{{ `License` }}</span>
          </u-btn>
        </div>
        <br />
        <div class="custom-margin">
          <h2 class="font-weight-light">{{ `Install Type` }}</h2>
          <br />
          <label class="font-weight-light faint-color"
            >Install type determines the optimal default settings for this deployment.</label
          >
          <br />
          <label>Choose Type:</label>
          <ValidationProvider v-slot="{ errors }" rules="required">
            <v-autocomplete
              v-model="installType"
              :items="typeOptions"
              outlined
              dense
              hide-details
              return-object
              :error-messages="errors"
              placeholder="Select Type"
            >
              <template v-if="errors.length" #append>
                <u-errors-tooltip :errors="errors" />
              </template>
            </v-autocomplete>
          </ValidationProvider>
          <br />
          <label>Timezone</label>
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
          <br />
          <br />
          <br />
          <br />
          <u-btn :small="false" style="margin: 8px 0" class="custom-btn" @click="passes(onContinue)">
            {{ `Network Cards` }}<span class="arrow-icon-right">→</span>
          </u-btn>
        </div>
      </div>
    </ValidationObserver>
  </v-card>
</template>
<style scoped>
  .parent-container {
    display: flex; /* Enables flexbox layout */
    gap: 20px; /* Adds 20px space between the child divs */
  }
  h2.font-weight-light {
    font-weight: bold; /* Or try 'bold' for a stronger weight */
  }
  .arrow-icon-left,
  .arrow-icon-right {
    font-weight: bold;
    font-size: 50px;
    display: inline-block;
    vertical-align: middle;
    margin-bottom: 17px;
  }

  .arrow-icon-left {
    margin-left: -100px;
    margin-right: -20px;
  }
  .button-text {
    margin-left: 65px;
    margin-right: -10px;
    display: inline-block;
  }

  .arrow-icon-right {
    margin-left: 10px;
    margin-right: -30px;
  }
  .custom-btn {
    margin: 5px 0; /* Margin for spacing between buttons */
    width: 300px; /* Fixed width for buttons */
    height: 50px; /* Fixed height for buttons */
    font-size: 16px; /* Text size */
    border-radius: 5px; /* Optional: rounded corners */
    text-align: center; /* Center text */
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
</style>
<script>
  import Util from '@/util/setupUtil'
  export default {
    props: {
      rpc: {
        type: Object,
        required: true,
      },
    },
    data: () => ({
      adminEmail: '',
      timezoneID: '',
      timezone: '',
      timezones: '',
      newPassword: localStorage.getItem('newPassword') || null,
      newPasswordConfirm: localStorage.getItem('newPassword') || null,
      loading: false,
      installType: '',
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
    }),
    computed: {
      passwordRequired() {
        return this.$store.state.setup?.status?.step ? this.$store.state.setup?.status.step === 'system' : true
      },
    },
    watch: {
      newPassword(newVal) {
        // Store the password in localStorage whenever it changes
        if (newVal) {
          localStorage.setItem('newPassword', newVal)
        } else {
          localStorage.removeItem('newPassword') // Remove if the value is empty
        }
      },
      installType(newValue) {
        // Save the installType to localStorage whenever it changes
        if (newValue) {
          localStorage.setItem('installType', JSON.stringify(newValue))
        }
      },
    },
    created() {
      // Set up the RPC client and fetch relevant data
      const rpcResponseForSetup = Util.setRpcJsonrpc('setup') // setup/JSONRPC
      console.log('Responce', rpcResponseForSetup)

      const savedInstallType = localStorage.getItem('installType')
      if (savedInstallType) {
        this.installType = JSON.parse(savedInstallType)
      }

      this.adminEmail = rpcResponseForSetup?.adminEmail
      this.timezoneID = rpcResponseForSetup?.timezoneID
      this.timezones = []
      const jsonStr = rpcResponseForSetup.timezones.replace(/'/g, '"')
      const timezonesArray = JSON.parse(jsonStr)
      if (timezonesArray) {
        for (let i = 0; i < timezonesArray.length; i++) {
          const timezone = '(' + timezonesArray[i][1] + ') ' + timezonesArray[i][0]
          // const displayName = rpcResponseForSetup.timezones[i][1]
          this.timezones.push(timezone)
          if (this.timezoneID === timezonesArray[i][0]) {
            this.timezone = timezone
          }
        }
      }
    },
    methods: {
      async onClickLicense() {
        try {
          await Promise.resolve()
          // Navigate to the setup wizard page
          this.$router.push('/setup/license/')
        } catch (error) {
          console.error('Failed to navigate:', error)
        }
      },
      async onContinue() {
        const rpcResponseForSetup = Util.setRpcJsonrpc('setup')
        const rpcResponseForAdmin = Util.setRpcJsonrpc('admin')
        console.log(rpcResponseForSetup)
        console.log('Responce rpcResponseForAdmin', rpcResponseForAdmin)

        try {
          window.rpc.setup = new window.JSONRpcClient('/setup/JSON-RPC').SetupContext // to avoid invalid security nonce
          // console.log(window.rpc.setup)
          if (this.timezoneID !== this.timezone) {
            console.log('timeZone', this.timezone)
            const timezoneId = this.timezone.split(' ')[1]
            await window.rpc.setup.setTimeZone(timezoneId)
            console.log('Timezone updated successfully.', timezoneId)
          }
          await this.saveAdminPassword()
          // alert('Settings saved successfully.')
        } catch (error) {
          console.error('Error saving settings:', error)
          alert('Failed to save settings. Please try again.')
        }
      },

      async saveAdminPassword() {
        try {
          console.log('Attempting to update admin password...')
          console.log('RPC Context:', window.rpc.setup)

          // Update admin password
          await window.rpc.setup.setAdminPassword(this.newPassword, this.adminEmail, this.installType.value)
          console.log('Admin password updated successfully.', this.newPassword)
          console.log('Confirm password', this.newPasswordConfirm)
          console.log('Install Type', this.installType.value)

          // Authenticate the updated password
          await new Promise((resolve, reject) => {
            Util.authenticate(this.newPassword, (error, success) => {
              console.log('Authentication error:', error)
              console.log('Authentication success:', success)
              this.$router.push('/setup/network')
              if (error || !success) {
                console.error('Authentication failed after password update:', error)
                reject(new Error('Authentication failed after password update.'))
              } else {
                console.log('Authentication successful after password update.')
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
