<template>
  <v-card width="1100" height="500" class="mx-auto mt-3" flat>
    <SetupLayout />
    <div class="auto-upgrades">
      <v-container class="text-center">
        <div class="auto-setup">
          <div v-if="!rpc?.remote" class="centered-content">
            <h3>
              <strong>{{ `The ${rpc?.oemName} is now configured.` }}</strong>
            </h3>
            <br />
            <p>
              {{ `You are now ready to configure the applications.` }}
            </p>
            <u-btn :small="false" class="custom-btn" @click="onClickDashboard">
              <v-icon left>mdi-check</v-icon>{{ 'Go to Dashboard' }}
            </u-btn>
          </div>
          <!-- Can get to remote server -->
          <div v-else class="remote-setup">
            <v-img :src="require('@/assets/BrandingLogo.png')" contain transition="false" class="branding-logo" />
            {{ currentTime }}
            <br />
            <h1>{{ `${localesEn?.Thanks_for_choosing} ${rpc?.oemName}!` }}</h1>
            <p>
              To continue, you must log in using your ETM Dashboard account. If you do not have one, you can create a
              free account.
            </p>
            <div class="button-container">
              <u-btn :small="false" class="custom-btn" @click="login">Login</u-btn>
              <u-btn :small="false" class="custom-btn" @click="createAccount">Create Account</u-btn>
            </div>
          </div>
        </div>
        <v-dialog v-model="loading" persistent max-width="300">
          <v-card>
            <v-card-title class="headline"> Please Wait </v-card-title>
            <v-card-text>
              Loading User Interface...
              <v-progress-circular indeterminate color="primary" size="64" width="6"></v-progress-circular>
            </v-card-text>
          </v-card>
        </v-dialog>
        <v-dialog v-model="warningDiaglog" max-width="400">
          <v-card>
            <v-card-title class="headline"></v-card-title>
            <v-card-text>
              {{ dialogMessage }}
            </v-card-text>
            <v-card-actions>
              <v-spacer></v-spacer>
              <v-btn color="primary" text @click="closeWarningDialog">OK</v-btn>
            </v-card-actions>
          </v-card>
        </v-dialog>
      </v-container>
    </div>
  </v-card>
</template>

<script>
  import Util from '@/util/setupUtil'
  import SetupLayout from '@/layouts/SetupLayout.vue'
  export default {
    components: {
      SetupLayout,
    },
    data() {
      return {
        currentTime: new Date().getTime(),
        redirectToDashboard: false,
        rpc: null,
        loading: false,
        warningDiaglog: false,
      }
    },
    computed: {
      logo() {
        return this.$vuetify.theme.isDark ? 'BrandingLogo.png' : 'BrandingLogo.png'
      },
    },
    created() {
      const rpcResponseForSetup = Util.setRpcJsonrpc('setup')

      if (rpcResponseForSetup) {
        this.rpc = rpcResponseForSetup
      } else {
        this.showWarningDialog('RPC setup failed')
      }
      this.onActivate()
    },
    methods: {
      onActivate() {
        const rpc = Util.setRpcJsonrpc('admin')
        if (!rpc?.remote) {
          // In local mode, mark wizard completed so apps can start being populated.
          rpc.jsonrpc.UvmContext.wizardComplete()
        }
      },
      showWarningDialog(message) {
        this.dialogMessage = message
        this.warningDiaglog = true
      },
      closeWarningDialog() {
        this.warningDiaglog = false
      },
      login() {
        window.top.location.href = `${this.rpc.remoteUrl}appliances/add/${this.rpc.serverUID}`
      },
      createAccount() {
        window.top.location.href = `${this.rpc.remoteUrl}login/create-account/add-appliance/${this.rpc.serverUID}`
      },
      onClickDashboard() {
        const rpc = Util.setRpcJsonrpc('admin')
        this.loading = true
        setTimeout(() => {
          this.loading = false
        }, 3000)

        rpc.jsonrpc.UvmContext.wizardComplete((result, ex) => {
          if (ex) {
            Util.handleException(ex)
          }
          window.top.location.href = '/admin/index.do'
        })
        // TODO
        // view.down('[itemId=complete]').add(items)
      },
    },
  }
</script>

<style scoped>
  .button-container {
    display: flex;
    justify-content: center;
    gap: 20px;
  }
  .faint-color {
    color: rgba(0, 0, 0, 0.5);
  }
  .auto-upgrades {
    display: flex;
    flex-direction: column;
    padding: 140px;
    justify-content: flex-start;
    margin: 20px 120px 10px 120px;
    border: 1px solid #ccc;
    background-color: #f9f9f9;
    font-family: Arial, sans-serif;
    height: 120%;
    overflow: hidden;
  }
</style>
