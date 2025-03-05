<template>
  <v-card width="1100" height="500" class="mx-auto mt-3" flat>
    <SetupLayout />
    <div class="auto-upgrades">
      <h1 class="font-weight-light faint-color text-h4">{{ title }}</h1>
      <v-container class="text-center">
        <v-row>
          <v-col cols="auto">
            <v-checkbox
              id="autoUpgrade"
              v-model="systemSettings.autoUpgrade"
              :label="$t('Automatically Install Upgrades')"
              hide-details
              class="bold-label"
            />
            <v-row>
              <v-col cols="12">
                <p class="paragraph">{{ $t('Automatically install new versions of the software when available.') }}</p>
                <p class="paragraph">{{ $t('This is the recommended choice for most sites.') }}</p>
              </v-col>
            </v-row>
          </v-col>
        </v-row>

        <v-row>
          <v-col cols="auto">
            <v-checkbox
              id="cloudEnabled"
              v-model="systemSettings.cloudEnabled"
              :label="$t('Connect to ETM Dashboard')"
              hide-details
              class="bold-label"
            />
            <v-row>
              <v-col cols="12">
                <p class="paragraph">
                  {{
                    $t(
                      'Remain securely connected to the ETM Dashboard for cloud management, hot fixes, and support access.',
                    )
                  }}
                </p>
                <p class="paragraph">{{ $t('This is the recommended choice for most sites.') }}</p>
              </v-col>
            </v-row>
          </v-col>
        </v-row>
      </v-container>
      <div>
        <u-btn class="button-back" :small="true" @click="onClickBack">{{ `Back` }}</u-btn>
        <u-btn class="button-next" :small="true" @click="onSave">
          {{ `Next` }}
        </u-btn>
      </div>
    </div>
  </v-card>
</template>

<script>
  import { mapActions, mapGetters } from 'vuex'
  import Util from '@/util/setupUtil'
  import SetupLayout from '@/layouts/SetupLayout.vue'
  import AlertDialog from '@/components/Reusable/AlertDialog.vue'
  export default {
    name: 'AutoUpgrades',
    components: {
      SetupLayout,
    },
    props: {
      rpc: {
        type: Object,
        required: true,
      },
    },
    data() {
      return {
        systemSettings: null,
        initialValues: {
          autoUpgrade: null,
          cloudEnabled: null,
          supportEnabled: null,
        },
        isCCHidden: false,
        description: '',
        title: '',
        isProcessing: false,
      }
    },
    created() {
      this.getSettings()
      this.getTitle()
    },
    computed: {
      ...mapGetters('setup', ['wizardSteps', 'currentStep', 'previousStep']), // from Vuex
    },
    methods: {
      ...mapActions('setup', ['setShowStep']),
      ...mapActions('setup', ['setShowPreviousStep']),

      alertDialog(message) {
        this.$vuntangle.dialog.show({
          title: this.$t('Warning'),
          component: AlertDialog,
          componentProps: {
            alert: { message }, // Pass the plain message in an object
          },
          width: 600,
          height: 500,
          buttons: [
            {
              name: this.$t('close'),
              handler() {
                this.onClose()
              },
            },
          ],
        })
      },
      getTitle() {
        const rpc = Util.setRpcJsonrpc('admin')
        if (rpc.isCCHidden) {
          this.title = 'Automatic Upgrades'
        } else {
          this.title = 'Automatic Upgrades and ETM Dashboard Access'
        }
      },
      getSettings() {
        try {
          const rpc = Util.setRpcJsonrpc('admin')
          const result = rpc.systemManager.getSettings()
          this.initialValues.autoUpgrade = result.autoUpgrade
          this.initialValues.cloudEnabled = result.cloudEnabled
          if (rpc.isCCHidden) {
            this.isCCHidden = true
            this.initialValues.cloudEnabled = false
            this.description = 'Automatic Upgrades'
          }
          this.systemSettings = result
        } catch (error) {
          this.alertDialog(`Failed to load settings: ${error.message || error}`)
        }
      },
      async onClickBack() {
        try {
          await Promise.resolve()
          const currentStepIndex = await this.wizardSteps.indexOf(this.currentStep)
          await this.setShowStep(this.wizardSteps[currentStepIndex - 1])
          await this.setShowPreviousStep(this.wizardSteps[currentStepIndex - 1])
        } catch (error) {
          this.alertDialog(`Failed to navigate: ${error.message || error}`)
        }
      },
      async onSave() {
        const rpc = Util.setRpcJsonrpc('admin')
        // if no changes skip to next step
        if (
          this.initialValues.autoUpgrade === this.systemSettings.autoUpgrade &&
          this.initialValues.cloudEnabled === this.systemSettings.cloudEnabled
        ) {
          this.nextPage()
        }
        // if cloud enabled, enable support also
        if (this.systemSettings.cloudEnabled) {
          this.systemSettings.supportEnabled = true
        }

        await rpc.systemManager.setSettings(this.systemSettings)
        this.nextPage()
      },
      async nextPage() {
        if (this.isProcessing) return
        this.isProcessing = true

        try {
          const currentStepIndex = this.wizardSteps.indexOf(this.currentStep)

          if (this.wizardSteps[currentStepIndex + 1]) {
            await Util.updateWizardSettings(this.currentStep)
            await this.setShowStep(this.wizardSteps[currentStepIndex + 1])
            await this.setShowPreviousStep(this.wizardSteps[currentStepIndex + 1])
          }
        } catch (error) {
          console.error('Error while navigating to next step:', error)
        } finally {
          this.isProcessing = false
        }
      },
    },
  }
</script>

<style scoped>
  .faint-color {
    color: rgba(0, 0, 0, 0.5);
  }
  .auto-upgrades {
    display: flex;
    flex-direction: column;
    padding: 20px;
    justify-content: flex-start;
    margin: 20px 120px 10px 120px;
    border: 1px solid #ccc;
    background-color: #f9f9f9;
    font-family: Arial, sans-serif;
    height: 120%;
    overflow: hidden;
  }
  .text-center {
    margin-top: 8px;
    text-align: left;
  }
  .v-checkbox {
    margin-bottom: 20px;
  }
  h2 {
    font-size: 24px;
    font-weight: 600;
    margin-bottom: 20px;
  }
  p {
    font-size: 16px;
    color: #24282b;
    margin: 5px 0;
    text-align: left;
  }
  .button-back {
    margin-top: 220px;
    margin-left: 0px;
    margin-bottom: -180px;
  }
  .button-next {
    margin-top: 220px;
    margin-left: 578px;
    margin-bottom: -180px;
  }
  .bold-label {
    font-weight: bold;
    padding-top: -10px;
    margin-top: 10px;
    text-align: center;
    width: 100%;
    display: block;
  }
  .paragraph {
    margin-left: 33px;
  }
  .parent-div {
    margin-top: 10px;
  }
</style>
