<template>
  <v-card width="1150" height="400" class="mx-auto mt-5" flat>
    <SetupLayout />
    <div
      class="pa-5 d-flex flex-column"
      style="border: 1px solid #ccc; background-color: #f9f9f9; overflow: auto; height: 800px; width: 1100px"
    >
      <h1 class="font-weight-light faint-color text-h4">{{ title }}</h1>
      <v-container class="flex-grow-1">
        <v-row>
          <v-col cols="auto">
            <v-checkbox id="autoUpgrade" v-model="systemSettings.autoUpgrade" hide-details>
              <template #label>
                <span class="font-weight-bold mt-2">{{ $t('Automatically Install Upgrades') }}</span>
              </template>
            </v-checkbox>
            <v-row>
              <v-col cols="auto">
                <p class="ml-8 mt-1">
                  {{ $t('Automatically install new versions of the software when available.') }}
                </p>
                <p class="ml-8 mt-1">{{ $t('This is the recommended choice for most sites.') }}</p>
              </v-col>
            </v-row>
          </v-col>
        </v-row>

        <v-row>
          <v-col cols="auto">
            <v-checkbox id="cloudEnabled" v-model="systemSettings.cloudEnabled" hide-details
              ><template #label>
                <span class="font-weight-bold mt-2">{{ $t('Connect to ETM Dashboard') }}</span>
              </template>
            </v-checkbox>
            <v-row>
              <v-col cols="auto">
                <p class="ml-8">
                  {{
                    $t(
                      'Remain securely connected to the ETM Dashboard for cloud management, hot fixes, and support access.',
                    )
                  }}
                </p>
                <p class="ml-8">{{ $t('This is the recommended choice for most sites.') }}</p>
              </v-col>
            </v-row>
          </v-col>
        </v-row>
      </v-container>
      <div class="d-flex justify-space-between pa-7" style="position: relative">
        <u-btn :small="false" @click="onClickBack">{{ `Back` }}</u-btn>
        <u-btn :small="false" @click="onSave">{{ `Next` }}</u-btn>
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
          this.$vuntangle.toast.add(this.$t(`Error while navigating to next step : ${error || error.message}`))
        } finally {
          this.isProcessing = false
        }
      },
    },
  }
</script>
