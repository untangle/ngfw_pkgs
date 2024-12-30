<template>
  <div class="complete">
    <div class="local-setup">
      <p>
        {{ setupRpc.oemProductName ? `The ${setupRpc.oemProductName} is now configured.` : 'Loading...' }}
      </p>
      <p>{{ $t('You are now ready to configure the applications.') }}</p>
      <button class="go-to-dashboard" @click="goToDashboard">
        <i class="fa fa-check"></i>
        {{ $t('Go to Dashboard') }}
      </button>
    </div>
  </div>
</template>

<script>
  export default {
    name: 'Complete',
    props: {
      adminRpc: {
        type: Object,
        required: true,
      },
      setupRpc: {
        type: Object,
        required: true,
      },
    },
    logo() {
      return this.$vuetify.theme.isDark ? 'arista-logo-white.svg' : 'arista-logo-blue.svg'
    },
    rpc: {},
    // setupRpc: {},
    mounted() {
      // this.rpc = new window.JSONRpcClient('/admin/JSON-RPC').UvmContext
      // this.setupRpc = new window.JSONRpcClient('/setup/JSON-RPC').SetupContext

      // this.setupRpc.getSetupWizardStartupInfo(function (result) {
      //   console.log('result', result)
      //   this.setupRpc = { ...window.rpc, ...result }
      //   // window.setupWizardData = result
      // })
      //

      console.log('this.rpc', this.rpc)
      console.log('this.adminRpc', this.adminRpc)
      console.log('this.setupRpc', this.setupRpc)
      console.log('this.setupRpc.oemProductName', this.setupRpc.oemProductName)

      if (!this.adminRpc.remote) {
        this.adminRpc.wizardComplete()
      }
      console.log('this.adminRpc', this.adminRpc)
    },
    methods: {
      goToDashboard() {
        this.$store.commit('setLoading', true)
        this.rpc.wizardComplete((result, ex) => {
          // this.$store.commit('setLoading', false)
          if (ex) {
            // this.$store.dispatch('handleException', ex)
            return
          }
          window.location.href = '/admin/index.do'
        })
      },
      login() {
        window.location = `${this.setupRpc.remoteUrl}appliances/add/${this.adminRpc.serverUID}`
      },
      createAccount() {
        window.location = `${this.setupRpc.remoteUrl}/login/create-account/add-appliance/${this.adminRpc.serverUID}`
      },
    },
  }
</script>

<style scoped>
  .complete {
    text-align: center;
    font-family: Arial, sans-serif;
    margin: 20px;
    border: 2px solid #007bff; /* Adds a blue border */
    border-radius: 10px; /* Optional: Rounds the corners */
    padding: 20px; /* Adds space inside the border */
    box-shadow: 0px 4px 6px rgba(0, 0, 0, 0.1); /* Optional: Adds a subtle shadow */
  }

  .local-setup h1,
  .remote-setup h1 {
    margin: 0;
    font-size: 1.5rem;
  }

  .local-setup p,
  .remote-setup p {
    margin: 20px 0;
    font-size: 1rem;
  }

  .go-to-dashboard {
    background-color: #007bff;
    color: white;
    border: none;
    padding: 10px 20px;
    font-size: 1rem;
    cursor: pointer;
    border-radius: 5px;
  }

  .go-to-dashboard:hover {
    background-color: #0056b3;
  }

  .remote-setup .buttons button {
    width: 332px;
    margin: 10px auto;
    background-color: #007bff;
    color: white;
    border: none;
    padding: 10px;
    font-size: 1rem;
    cursor: pointer;
    border-radius: 5px;
  }

  .remote-setup .buttons button:hover {
    background-color: #0056b3;
  }
</style>
