<template>
  <v-card width="650" class="mx-auto mt-4" flat>
    <h2 class="font-weight-light faint-color text-h4">{{ `Configure the Server` }}</h2>
    <br />
    <br />
    <ValidationObserver v-slot="{ passes }">
      <div class="d-flex">
        <div class="custom-margin">
          <h2 class="font-weight-light">{{ `Admin Account` }}</h2>
          <br />
          <label class="font-weight-light faint-color">Choose a password for the admin account</label>
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
          <div class="button-container">
            <u-btn :small="false" style="margin: 8px 0" @click="onClickLicense">{{ `License` }}</u-btn>
          </div>
        </div>
        <br />
        <div>
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
          <!-- <h2 class="font-weight-light">{{ `Timezone` }}</h2> -->
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
          <br />
          <br />
          <div class="button-container-right">
            <u-btn :small="false" style="margin: 8px 0" @click="passes(onContinue)">{{ `Network Cards` }}</u-btn>
          </div>
        </div>
      </div>

      <br />
    </ValidationObserver>
  </v-card>
</template>
<style scoped>
  .button-container {
    display: flex;
    justify-content: flex-start;
    align-items: center;
    gap: 1300px;
  }
  .button-container-right {
    display: flex;
    justify-content: flex-end;
    align-items: center;
    gap: 1300px;
  }
  .custom-margin {
    margin-right: 80px;
  }
  .faint-color {
    color: rgba(0, 0, 0, 0.5); /* Adjust the color and opacity */
  }
</style>
<script>
  import Util from '@/util/setupUtil'
  import store from '@/store'
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
      newPassword: null,
      newPasswordConfirm: null,
      tz: { ...store.getters['settings/timeZoneObject'] },
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
    created() {
      // Set up the RPC client and fetch relevant data
      const rpcResponseForSetup = Util.setRpcJsonrpc('setup') // setup/JSONRPC
      console.log('Responce', rpcResponseForSetup)

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
        // try {
        //   await Promise.resolve()
        //   // Navigate to the setup license page
        //   this.$router.push('/setup/network')
        // } catch (error) {
        //   console.error('Failed to navigate:', error)
        // }
      },
    },
  }
</script>
