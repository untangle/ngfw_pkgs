<template>
  <div class="content-wrapper">
    <!-- Intro Section -->
    <div v-if="!showInternetSetup" :class="{ 'intro': !remoteReachable, 'fadein': true }">
      <div v-if="rpc" class="setup-main" :style="{ padding: '20px' }">
        <div v-if="showIntro" class="intro">
          <img :src="require(`@/assets/${logo}`)" height="48" />
          <h1>{{ `Thanks for choosing ${rpc.oemShortName}!` }}</h1>
        </div>

        <div v-if="!rpc.remote">
          <!-- Local Setup Wizard Configuration -->
          <p>
            {{ `A wizard will guide you through the initial setup and configuration of the ${rpc.oemProductName}.` }}
          </p>
          <div class="button-group">
            <button v-if="resuming" @click="resumeWizard">Resume Setup Wizard</button>
            <button class="btn warning-btn" @click="resetWizard">
              {{ !resuming ? 'Run Setup Wizard' : 'Restart' }}
            </button>
          </div>
        </div>

        <div v-else>
          <!-- Remote Configuration -->
          <p v-if="remoteReachable === null">
            <i class="fa fa-spinner fa-spin fa-lg fa-fw"></i> Checking Internet connectivity...
          </p>
          <p v-if="remoteReachable">
            To continue, you must log in using your ETM Dashboard account. If you do not have one, you can create a free
            account.
          </p>
          <div v-if="remoteReachable" class="button-wrapper">
            <div class="button-container">
              <button class="btn primary-btn" @click="login">Log In</button>
              <button class="btn secondary-btn" @click="createAccount">Create Account</button>
            </div>
            <!-- <button class="btn warning-btn" @click="resetWizard">
              {{ !resuming ? 'Run Setup Wizard' : 'Restart' }}
            </button> -->
          </div>
          <p v-if="remoteReachable === false">
            To continue, you must connect to ETM Dashboard, which is currently unreachable from this device. Configure
            Internet connectivity to proceed.
          </p>
          <button v-if="remoteReachable === false" class="btn warning-btn" @click="resetWizard">
            Configure Internet
          </button>
        </div>
      </div>
    </div>

    <!-- Internet Component -->
    <Internet
      v-if="showInternetSetup"
      :setup-rpc="rpc"
      :remote-reachable="remoteReachable"
      @back="showInternetSetup = false"
      @resetWizard="resetWizard"
    />
  </div>
</template>

<script>
  import Util from '@/util/setupUtils'
  import Internet from '@/Setup_wizard/step/Internet.vue'

  export default {
    name: 'SetupMain',
    components: {
      Internet,
    },
    data() {
      return {
        showInternetSetup: false,
        resuming: false,
        remoteReachable: null,
        rpc: null, // Initialize rpc as null to track data loading
      }
    },
    computed: {
      logo() {
        return this.$vuetify.theme.isDark ? 'arista-logo-white.svg' : 'arista-logo-blue.svg'
      },
      showIntro() {
        return true // Add logic if needed
      },
    },
    async mounted() {
      try {
        console.log('Initializing RPC...')
        await this.initializeRpc()
        this.checkRemoteReachability()
        this.checkWizardStatus()
      } catch (error) {
        console.error('Error initializing RPC:', error)
      }
    },
    methods: {
      async initializeRpc() {
        if (window.rpc && window.rpc.setup) {
          console.log('window.rpc', window.rpc)
          const result = await new Promise((resolve, reject) => {
            window.rpc.setup.getSetupWizardStartupInfo((res, err) => {
              if (err) reject(err)
              else resolve(res)
            })
          })
          console.log('Setup Wizard Startup Info:', result)
          this.rpc = { ...window.rpc, ...result } // Merge window.rpc with the result
          console.log('RPC after assigning startup info:', this.rpc)
        } else {
          throw new Error('RPC setup is not available')
        }
      },
      checkRemoteReachability() {
        setTimeout(() => {
          if (this.rpc && this.rpc.setup) {
            this.remoteReachable = this.rpc.setup.getRemoteReachable()
          }
        }, 500)
      },
      checkWizardStatus() {
        if (
          this.rpc &&
          this.rpc.wizardSettings &&
          !this.rpc.wizardSettings.wizardComplete &&
          this.rpc.wizardSettings.completedStep != null
        ) {
          this.resuming = true
        }
      },
      resetWizard() {
        console.log('this.rpc.remote', this.rpc.remote)
        console.log('this.remoteReachable', this.remoteReachable)
        console.log("Util.setRpcJsonrpc('admin')", Util.setRpcJsonrpc('admin'))
        if (this.rpc.remote && !this.remoteReachable) {
          if (Util.setRpcJsonrpc('admin')) {
            this.resetWizardContinue()
          } else {
            Util.authenticate('passwd', isNonDefaultPassword => {
              if (isNonDefaultPassword) {
                const password = prompt('Please enter admin password')
                Util.authenticate(password, () => {
                  this.resetWizardContinue()
                })
              } else {
                this.resetWizardContinue()
              }
            })
          }
        } else {
          this.resetWizardContinue()
        }
      },
      resetWizardContinue() {
        this.resuming = false
        if (this.rpc && this.rpc.wizardSettings) {
          this.rpc.wizardSettings.completedStep = null
          this.rpc.wizardSettings.wizardComplete = false
        }
        this.openSetup()
      },
      resumeWizard() {
        const password = prompt('Please enter admin password')
        Util.authenticate(password, () => {
          this.openSetup()
        })
      },
      openSetup() {
        this.showInternetSetup = true
        // this.$emit('open-setup') // Replace this with your logic to display the setup wizard
      },
      login() {
        window.location = `${this.rpc.remoteUrl}appliances/add/${this.rpc.serverUID}`
      },
      createAccount() {
        window.location = `${this.rpc.remoteUrl}/login/create-account/add-appliance/${this.rpc.serverUID}`
      },
    },
  }
</script>

<style scoped>
  /* Wrapper for the entire content */
  .content-wrapper {
    display: flex;
    flex-direction: column; /* Stack elements vertically */
    justify-content: flex-start; /* Align content to the top */
    align-items: center; /* Center elements horizontally */
    text-align: center; /* Center-align text content */
    padding: 20px; /* Add spacing around the content */
    box-sizing: border-box; /* Include padding and borders in width/height */
    min-height: 100vh; /* Ensure it takes full viewport height */
    background-color: #f9f9f9; /* Optional: Add a light background color */
  }

  /* Paragraph styling for spacing */
  p {
    margin-bottom: 15px; /* Add spacing between paragraphs */
    font-size: 16px; /* Adjust font size */
    color: #333; /* Text color */
  }

  /* Button container for spacing */

  .button-container {
    display: flex; /* Align buttons horizontally */
    flex-direction: row; /* Default is row, so not strictly necessary */
    justify-content: center; /* Center the buttons horizontally */
    gap: 20px; /* Add horizontal spacing between the buttons */
    margin-top: 20px; /* Optional: Add spacing above the container */
  }

  /* General Button Styles */
  .btn {
    padding: 12px 24px;
    border-radius: 5px;
    font-size: 16px;
    font-weight: bold;
    cursor: pointer;
    border: none;
    transition: all 0.3s ease-in-out;
    box-shadow: 0px 4px 6px rgba(0, 0, 0, 0.1);
  }

  /* Primary Button */
  .primary-btn {
    background-color: #007bff;
    color: #fff;
  }

  .primary-btn:hover {
    background-color: #0056b3;
    transform: scale(1.05);
  }

  /* Secondary Button */
  .secondary-btn {
    background-color: #6c757d;
    color: #fff;
  }

  .secondary-btn:hover {
    background-color: #5a6268;
    transform: scale(1.05);
  }

  /* Warning Button */
  .warning-btn {
    background-color: #ffc107;
    color: #000;
    margin-top: 15px; /* Add spacing from other elements */
  }

  .warning-btn:hover {
    background-color: #e0a800;
    transform: scale(1.05);
  }
</style>
