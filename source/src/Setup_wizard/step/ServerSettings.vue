<template>
  <Interfaces v-if="showInterfaces" :setup-rpc="setupRpc" :admin-rpc="adminRpc" />
  <div v-else class="server-settings">
    <h1>Server Settings</h1>

    <p class="subtitle">Configure the Server</p>

    <div class="form-container">
      <!-- Admin Account Section -->
      <div class="admin-account">
        <h3>Admin Account</h3>
        <p class="info">Choose a password for the <strong>admin</strong> account</p>

        <div class="form-group">
          <label>Password</label>
          <input v-model="form.password" type="password" placeholder="Enter Password" class="form-input" />
          <p v-if="form.password.length < 3 && form.password !== ''" class="error">
            The password must be at least 3 characters long.
          </p>
        </div>

        <div class="form-group">
          <label>Confirm Password</label>
          <input v-model="form.confirmPassword" type="password" placeholder="Confirm Password" class="form-input" />
          <p v-if="form.confirmPassword !== form.password && form.confirmPassword !== ''" class="error">
            Passwords do not match.
          </p>
        </div>

        <div class="form-group">
          <label>Admin Email</label>
          <input v-model="form.adminEmail" type="email" placeholder="Enter Admin Email" class="form-input" />
        </div>
        <p class="info">Administrators receive email alerts and report summaries.</p>
      </div>

      <!-- Install Type Section -->
      <div class="install-type">
        <h3>Install Type</h3>
        <p class="info">Install type determines the optimal default settings for this deployment.</p>
        <div class="form-group">
          <label>Choose Type</label>
          <select v-model="form.installType" class="form-select">
            <option value="">Select type</option>
            <option v-for="(label, value) in installTypes" :key="value" :value="value">
              {{ label }}
            </option>
          </select>
        </div>

        <h3>Timezone</h3>
        <div class="form-group">
          <label>Choose Timezone</label>
          <select v-model="form.timezone" class="form-select">
            <option value="">Select a Timezone</option>
            <option v-for="timezone in timezones" :key="timezone[0]" :value="timezone[0]">
              {{ timezone[1] }}
            </option>
          </select>
        </div>
      </div>
    </div>

    <button class="save-button" @click="onSave">Save</button>
  </div>
</template>

<script>
  import Util from '@/util/setupUtils'
  import Interfaces from '@/Setup_wizard/step/Interfaces.vue'

  export default {
    components: {
      Interfaces,
    },
    props: {
      setupRpc: {
        type: Object,
        required: true,
      },
      adminRpc: {
        type: Object,
        required: true,
      },
    },
    data() {
      return {
        form: {
          password: '',
          confirmPassword: '',
          adminEmail: '',
          installType: '',
          timezone: '',
        },
        timezones: [], // Correctly using this for timezones data
        installTypes: {
          school: 'School',
          college: 'Higher Education',
          government: 'State & Local Government',
          fedgovernment: 'Federal Government',
          nonprofit: 'Nonprofit',
          retail: 'Hospitality & Retail',
          healthcare: 'Healthcare',
          financial: 'Banking & Financial',
          home: 'Home',
          student: 'Student',
          other: 'Other',
        },
        showInterfaces: false,
      }
    },
    mounted() {
      if (this.setupRpc) {
        this.form.adminEmail = this.setupRpc.adminEmail || ''
        this.form.timezone = this.setupRpc.timezoneID || ''

        // Assign timezone data from the response
        this.timezones = [
          ['Etc/GMT+12', '(~UTC-12:00) Etc/GMT+12'],
          ['Etc/GMT+11', '(~UTC-11:00) Etc/GMT+11'],
          ['America/Boise', '(~UTC-07:00) America/Boise'],
          // Add additional timezones as needed
        ]

        console.log('Populated Timezones:', this.timezones)
        console.log('Preselected Timezone:', this.form.timezone)
      }
    },
    methods: {
      validateForm() {
        const { password, confirmPassword } = this.form
        if (password.length < 3 || password !== confirmPassword) return false
        return true
      },

      async onSave() {
        if (!this.validateForm()) {
          alert('All fields are required and passwords must match.')
          return
        }

        try {
          console.log('Saving settings...')

          // window.rpc = {}
          window.rpc.setup = new window.JSONRpcClient('/setup/JSON-RPC').SetupContext // to avoid invalid security nonce
          // console.log(window.rpc.setup)
          if (this.setupRpc.timezoneID !== this.form.timezone) {
            await window.rpc.setup.setTimeZone(this.form.timezone)
            console.log('Timezone updated successfully.')
          }
          await this.saveAdminPassword()
          alert('Settings saved successfully.')
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
          await window.rpc.setup.setAdminPassword(this.form.password, this.form.adminEmail, this.form.installType)
          console.log('Admin password updated successfully.')

          // Authenticate the updated password
          await new Promise((resolve, reject) => {
            Util.authenticate(this.form.password, (error, success) => {
              console.log('Authentication error:', error)
              console.log('Authentication success:', success)
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

<style scoped>
  .server-settings {
    padding: 20px;
    background-color: #f9f9f9;
    border-radius: 8px;
    max-width: 800px;
    margin: 0 auto;
    font-family: Arial, sans-serif;
    border: 2px solid #ccc; /* Add border */
    border-radius: 8px; /* Optional: rounded corners */
    margin: 20px; /* Optional: spacing around the div */
  }

  .subtitle {
    color: #666;
    margin-bottom: 20px;
    font-size: 1rem;
  }

  .form-container {
    display: flex;
    gap: 20px;
    margin: 20px 0;
  }

  .admin-account,
  .install-type {
    flex: 1;
  }

  h3 {
    font-size: 1.2rem;
    color: #333;
    margin-bottom: 10px;
  }

  .form-group {
    margin-bottom: 15px;
  }

  label {
    display: block;
    font-weight: bold;
    margin-bottom: 5px;
    color: #444;
  }

  .form-input,
  .form-select {
    width: 100%;
    padding: 8px;
    font-size: 1rem;
    border: 1px solid #ccc;
    border-radius: 4px;
  }

  .form-input:focus,
  .form-select:focus {
    border-color: #007bff;
    outline: none;
  }

  .error {
    color: beige;
    font-size: 0.875rem;
    margin-top: 5px;
  }

  .info {
    color: #5bc0de;
    font-size: 0.875rem;
    margin-top: 5px;
  }

  .save-button {
    background-color: #007bff;
    color: white;
    border: none;
    padding: 10px 20px;
    font-size: 1rem;
    border-radius: 4px;
    cursor: pointer;
  }

  .save-button:hover {
    background-color: #0056b3;
  }
</style>
