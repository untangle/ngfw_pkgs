<template>
  <v-card width="1150" height="400" class="mx-auto mt-5" flat>
    <SetupLayout />
    <div
      class="pa-5 d-flex flex-column"
      style="border: 1px solid #ccc; background-color: #f9f9f9; overflow: auto; height: 800px; width: 1100px"
    >
      <v-container class="flex-grow-1 d-flex align-center justify-center">
        <v-row>
          <v-col>
            <div v-if="!rpc?.remote" class="text-center">
              <h3>
                <strong>{{ `The ${rpc?.oemProductName} is now configured.` }}</strong>
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
            <div v-else class="text-center">
              <v-img :src="require('@/assets/BrandingLogo.png')" contain max-height="80" class="my-4" />
              {{ currentTime }}
              <h2 class="font-weight-bold">{{ `Thanks for choosing ${rpc?.oemName}!` }}</h2>
              <p class="mt-2">
                To continue, you must log in using your ETM Dashboard account. If you do not have one, you can create a
                free account.
              </p>
              <v-row class="justify-center mt-4">
                <u-btn :small="false" class="mr-10 mt-3" @click="login">{{ $t('Login') }}</u-btn>
                <u-btn :small="false" class="mr-10 mt-3" @click="createAccount">{{ $t('Create Account') }}</u-btn>
              </v-row>
            </div>
          </v-col>
        </v-row>
        <v-dialog v-model="loading" persistent max-width="300">
          <v-card>
            <v-card-title> Please Wait </v-card-title>
            <v-card-text>
              Loading User Interface...
              <v-progress-circular indeterminate color="primary" size="64" width="6"></v-progress-circular>
            </v-card-text>
          </v-card>
        </v-dialog>
      </v-container>
    </div>
  </v-card>
</template>

<script>
  import { mapActions } from 'vuex'
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
      }
      this.onActivate()
    },
    methods: {
      ...mapActions('setup', ['setShowStep']),
      ...mapActions('setup', ['setShowPreviousStep']),

      onActivate() {
        const rpc = Util.setRpcJsonrpc('admin')
        if (!rpc?.remote) {
          // In local mode, mark wizard completed so apps can start being populated.
          rpc.jsonrpc.UvmContext.wizardComplete()
        }
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
      },
    },
  }
</script>
