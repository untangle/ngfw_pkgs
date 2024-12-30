<template>
  <div>
    <!-- Show Main Content if `showInternetSetup` is false -->
    <div v-if="!showInternetSetup" :class="{ 'intro': !remoteReachable, 'fadein': true }">
      <div v-if="rpc.remote">
        <div class="intro">
          <img :src="require(`@/assets/${logo}`)" height="48" />
          <h1>{{ 'Thanks for choosing ' + (rpc?.oemShortName || 'Unknown OEM') }}</h1>
        </div>
        <div>
          <p>
            To continue, you must connect to ETM Dashboard which is currently unreachable from this device. You must
            configure Internet connectivity to ETM Dashboard to continue.
          </p>
          <button class="btn-configure" @click="resetWizard">Configure Internet</button>
        </div>
      </div>
      <div v-else>
        <div v-if="remoteReachable === null">
          <i class="fa fa-spinner fa-spin fa-lg fa-fw"></i> Checking Internet connectivity
        </div>
        <div>
          <p>
            To continue, you must log in using your ETM Dashboard account. If you do not have one, you can create a free
            account.
          </p>
          <button @click="goToLoginPage">Log In</button>
          <button @click="goToCreateAccountPage">Create Account</button>
        </div>
      </div>
    </div>

    <!-- Show Internet Component if `showInternetSetup` is true -->
    <Internet
      v-if="showInternetSetup"
      :setup-rpc="rpc"
      :remote-reachable="remoteReachable"
      @back="showInternetSetup = false"
    />
  </div>
</template>

<script>
  import Internet from '@/Setup_wizard/step/Internet.vue'

  export default {
    name: 'SetupWizard',
    components: {
      Internet,
    },
    data() {
      return {
        resuming: false,
        remoteReachable: null,
        rpc: {}, // Initialize rpc here
        setupWizardData: {},
        showInternetSetup: false, // Toggles Internet component visibility
      }
    },
    computed: {
      logo() {
        return this.$vuetify.theme.isDark ? 'arista-logo-white.svg' : 'arista-logo-blue.svg'
      },
    },
    mounted() {
      console.log('window.rpc before initialization:', window.rpc)

      // Initialize window.rpc if not set
      if (!window.rpc) {
        window.rpc = {}
      }

      // Assign JSONRpcClient to window.rpc.setup
      window.rpc.setup = new window.JSONRpcClient('/setup/JSON-RPC').SetupContext

      // Assign to this.rpc for local usage
      this.rpc = window.rpc
      this.setupWizardData = window.setupWizardData
      console.log('this.rpc', this.rpc)

      // Fetch setup wizard startup info
      window.rpc.setup.getSetupWizardStartupInfo(result => {
        console.log('Setup Wizard Startup Info:', result)
        this.rpc = result
        // this.rpc = {
        //   ...this.rpc,
        //   ...result,
        // }
        this.resuming = result?.wizardSettings?.wizardComplete
        console.log('RPC after assigning startup info:', this.rpc)
        console.log('this.resuming', this.resuming)
      })

      // Fetch remote reachability
      window.rpc.setup.getRemoteReachable(result => {
        this.remoteReachable = result
        console.log('this.remoteReachable', this.remoteReachable)
      })

      // window.rpc.setup.networkManager.getNetworkSettings((settings, ex) => {
      //   console.log('settings, ex', settings, ex)
      //   if (ex) {
      //     this.$message.error(this.$t('Unable to fetch Network Settings.'))
      //     return
      //   }
      //   this.networkSettings = settings
      //   this.wan = settings.interfaces.list.find(intf => intf.isWan && intf.configType !== 'DISABLED')
      //   console.log('this.wan', this.wan)
      //   if (this.wan) {
      //     this.getInterfaceStatus()
      //   }
      // })

      if (!this.rpc) {
        console.warn('RPC object not found in mounted!')
      }
    },
    methods: {
      resetWizard() {
        console.log('Resetting Wizard. Showing Internet component...123')
        this.showInternetSetup = true // Show only Internet component
      },
      goToLoginPage() {
        if (this.rpc && this.rpc.remoteUrl) {
          window.location = `${this.rpc.remoteUrl}appliances/add/${this.rpc.serverUID}`
        }
      },
      goToCreateAccountPage() {
        if (this.rpc && this.rpc.remoteUrl) {
          window.location = `${this.rpc.remoteUrl}/login/create-account/add-appliance/${this.rpc.serverUID}`
        }
      },
    },
  }
</script>

<style scoped>
  /* General button styling */
  button {
    padding: 12px 24px; /* Add padding for all sides */
    font-size: 16px;
    border: none;
    border-radius: 5px;
    cursor: pointer;
    transition: background-color 0.3s ease, transform 0.2s ease;
  }

  /* Log In button styling */
  button:nth-child(1) {
    background-color: #007bff; /* Blue color */
    color: white;
  }

  button:nth-child(1):hover {
    background-color: #0056b3; /* Darker blue */
    transform: translateY(-2px);
  }

  button:nth-child(1):active {
    background-color: #004085; /* Even darker blue */
    transform: translateY(0);
  }

  /* Create Account button styling */
  button:nth-child(2) {
    background-color: #17a2b8; /* Teal color */
    color: white;
  }

  button:nth-child(2):hover {
    background-color: #117a8b; /* Darker teal */
    transform: translateY(-2px);
  }

  button:nth-child(2):active {
    background-color: #0f5f6e; /* Even darker teal */
    transform: translateY(0);
  }

  /* Setup Wizard button styling */
  .btn-configure {
    background-color: #4caf50; /* Green color */
    color: white;
    padding: 12px 24px;
    font-size: 16px;
    border: none;
    border-radius: 5px;
    cursor: pointer;
    transition: background-color 0.3s ease, transform 0.2s ease;
  }

  .btn-configure:hover {
    background-color: #45a049; /* Darker green */
    transform: translateY(-2px);
  }

  .btn-configure:active {
    background-color: #388e3c; /* Even darker green when clicked */
    transform: translateY(0); /* Reset transform on click */
  }

  .btn-configure:focus {
    outline: none; /* Remove focus outline */
  }

  /* Add spacing between buttons */
  button,
  .btn-configure {
    margin: 10px; /* Add margin to all buttons */
  }
</style>
