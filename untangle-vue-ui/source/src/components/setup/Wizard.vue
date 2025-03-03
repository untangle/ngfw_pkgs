<template>
  <div>
    <component :is="currentStepComponent" />
  </div>
</template>

<script>
  import { mapGetters, mapActions } from 'vuex'
  import License from '@/components/setup/License.vue'
  import System from '@/components/setup/System.vue'
  import SetupLayout from '@/layouts/SetupLayout.vue'
  import SetupSelect from '@/components/setup/SetupSelect.vue'
  import Network from '@/components/setup/Network.vue'
  import Internet from '@/components/setup/Internet.vue'
  import Interface from '@/components/setup/Interface.vue'
  import AutoUpgrades from '@/components/setup/Autoupgrades.vue'
  import Complete from '@/components/setup/Complete.vue'
  import Wireless from '@/components/setup/Wireless.vue'
  import Util from '@/util/setupUtil'

  export default {
    name: 'Wizard',
    components: {
      License,
      System,
      SetupLayout,
      SetupSelect,
      Internet,
      Interface,
      Wireless,
      AutoUpgrades,
      Complete,
    },

    data() {
      return {
        activeStepDesc: '',
        activeStep: null,
        intfListLength: 0,
        nextDisabled: false,
        interfacesForceContinue: false,
        steps: [],
        activeStepIndex: 0,
        rpc: null,
        rpcForAdmin: null,
        cardIndex: null,
        networkSettings: null,
        setActiveItem: null,
        prevStep: null,
        nextStep: null,
        activeItem: null,
        activeIndex: null,
      }
    },

    async created() {
      console.log('created in wizard:')
      this.rpcForAdmin = Util.setRpcJsonrpc('admin')
      console.log('created in wizard:**')
      await this.initializeRpc()
      await this.onAfterRender()
    },

    mount() {
      this.updateNav()
    },

    computed: {
      ...mapGetters('setup', ['currentStep', 'wizardSteps']),
      // Dynamically choose the component based on currentStep
      currentStepComponent() {
        switch (this.currentStep) {
          case 'Welcome':
            return SetupSelect

          case 'License':
            return License

          case 'ServerSettings':
            return System

          case 'InternalNetwork':
            return Interface

          case 'Internet':
            return Internet

          case 'Interfaces':
            return Network

          case 'Wireless':
            return Wireless

          case 'AutoUpgrades':
            return AutoUpgrades

          case 'Complete':
            return Complete

          default:
            return SetupSelect
        }
      },
    },
    async beforeMount() {
      // If the page is refreshed, force set currentStep to 'Wizard'
      if (
        this.currentStep === 'License' ||
        this.currentStep === 'ServerSettings' ||
        this.currentStep === 'Network' ||
        this.currentStep === 'Internet' ||
        this.currentStep === 'InternalNetwork' ||
        this.currentStep === 'Interfaces' ||
        this.currentStep === 'Wireless' ||
        this.currentStep === 'AutoUpgrades' ||
        this.currentStep === 'Complete'
      ) {
        await this.setShowStep('Welcome')
      }
    },
    methods: {
      ...mapActions('setup', ['setShowStep', 'setShowPreviousStep', 'initializeWizard']),

      async initializeRpc() {
        try {
          const rpcResult = await this.initializeWizard()
          this.rpc = { ...rpcResult }
          const currentStepIndex = this.wizardSteps.indexOf(this.currentStep)

          await this.setShowStep(this.wizardSteps[currentStepIndex])
          await this.setShowPreviousStep(this.wizardSteps[currentStepIndex])
        } catch (error) {
          this.$vuntangle.toast.add(this.$t(`Error initializing wizard: ${error || error.message}`))
        }
      },

      updateNav() {
        console.log('rpcForAdmin updateNav :', this.rpcForAdmin)
        this.prevStep = this.steps[this.activeStepIndex - 1]
        this.nextStep = this.steps[this.activeStepIndex + 1]
        this.activeStepDesc = this.steps[this.activeStepIndex]

        if (this.rpcForAdmin.jsonrpc) {
          if (this.steps && this.steps.length > 0) {
            this.rpc.wizardSettings.steps = this.steps
          }
          this.rpc.wizardSettings.completedStep = this.prevStep || null
          this.rpc.wizardSettings.wizardComplete = !this.nextStep

          if (this.rpcForAdmin.jsonrpc.UvmContext) {
            this.rpcForAdmin.jsonrpc.UvmContext.setWizardSettings(function (result, ex) {
              if (ex) {
                Util.handleException(ex)
              }
            }, this.rpc.wizardSettings)
          }
        }
      },

      /**
       * called after the network settings were fetched,
       * updates the wizard steps depending on available
       * interfaces.
       */
      async onSyncSteps(activeItemIdx) {
        if (this.rpc.remote) {
          // Only for local.
          return
        }
        this.networkSettings = await this.rpcForAdmin?.networkManager?.getNetworkSettings()
        this.interfaces = await this.networkSettings.interfaces.list
        const firstWan = this.interfaces.find(function (intf) {
          return intf.isWan && intf.configType !== 'DISABLED'
        })
        const firstNonWan = this.interfaces.find(function (intf) {
          return !intf.isWan
        })
        const firstWireless = this.interfaces.find(function (intf) {
          return intf.isWirelessInterface
        })

        this.steps = ['License', 'ServerSettings', 'Interfaces']

        if (firstWan) {
          this.steps.push('Internet')
        }
        if (firstNonWan) {
          this.steps.push('InternalNetwork')
        }
        if (firstWireless) {
          this.steps.push('Wireless')
        }

        this.steps.push('AutoUpgrades')
        this.steps.push('Complete')

        await this.$store.dispatch('setup/setStep', this.steps)
        // used when resuming the setup
        if (Number.isInteger(this.activeItemIdx)) {
          this.rpc.wizardSettings.completedStep = this.rpc.wizardSteps[activeItemIdx]
          if (this.rpcForAdmin.jsonrpc.UvmContext) {
            this.rpcForAdmin.jsonrpc.UvmContext.setWizardSettings(function (result, ex) {
              if (ex) {
                Util.handleException(ex)
              }
            }, this.rpc.wizardSettings)
          }
        }
      },

      async onAfterRender() {
        // Populate steps from wizard settings.
        await this.rpc.wizardSettings.steps.forEach(stepName => {
          this.steps.push(stepName)
        })
        if (!this.rpc.wizardSettings.wizardComplete && this.rpc.wizardSettings.completedStep !== null) {
          this.cardIndex = await this.rpc.wizardSettings.steps.indexOf(this.rpc.wizardSettings.completedStep)

          // if resuming from a step after Network Cards settings, need to fetch network settings
          this.cardIndex--
          if (this.cardIndex >= 2) {
            this.$store.commit('SET_LOADER', true)
            this.rpcForAdmin.networkManager.getNetworkSettings(async (result, ex) => {
              if (ex) {
                Util.handleException('Unable to load interfaces.'.t())
                return
              }

              this.networkSettings = result
              this.intfListLength = result.interfaces.list.length
              // update the steps based on interfaces
              await this.onSyncSteps(this.cardIndex)
            })
            this.$store.commit('SET_LOADER', false)
          } else {
            this.rpc.wizardSettings.completedStep = this.wizardSteps.indexOf(this.cardIndex + 1)
            this.updateNav()
          }
        } else {
          // If wizard is complete, just update the navigation
          this.updateNav()
        }
      },
    },
  }
</script>
