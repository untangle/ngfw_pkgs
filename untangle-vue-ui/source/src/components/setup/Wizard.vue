<template>
  <div>
    <!-- <SetupLayout /> -->
    <component :is="currentStepComponent" />
  </div>
</template>

<script>
  import { mapGetters, mapActions } from 'vuex'
  import License from '@/components/setup/License.vue' // Import License component
  import System from '@/components/setup/System.vue' // Import System component
  import SetupLayout from '@/layouts/SetupLayout.vue' // Import Layout component
  import SetupSelect from '@/components/setup/SetupSelect.vue' // Import System component
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
        steps: [],
        activeStepIndex: 0,
        activeStepDesc: '',
        intfListLength: 0, // used for next button disable/enable
        nextDisabled: false,
        interfacesForceContinue: false,
        rpc: null,
        cardIndex: null,
        // wizard: {
        //   steps: null,
        // },
        networkSettings: null,
        setActiveItem: null,

        prevStep: null,
        nextStep: null,
        activeItem: null,
        activeIndex: null,
      }
    },

    async created() {
      await this.initializeRpc()
      await this.onAfterRender()
      await this.onSyncSteps()
    },

    mount() {
      this.updateNav()
    },

    computed: {
      ...mapGetters('setup', ['currentStep', 'wizardSteps']), // Get currentStep from Vuex
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
        await this.setShowStep('Welcome') // Reset step to 'Wizard'
      }
    },
    methods: {
      ...mapActions('setup', ['setShowStep', 'setShowPreviousStep', 'initializeWizard']), // Map Vuex action to change step

      async initializeRpc() {
        try {
          const rpcResult = await this.initializeWizard() // Await the resolved object
          this.rpc = { ...rpcResult }
          // Change the step to 'System' and render the System component
          await this.setShowStep('System')
          await this.setShowPreviousStep('System')
        } catch (error) {
          console.error('Error initializing wizard:', error)
        }
      },

      updateNav() {
        this.prevStep = this.steps[this.activeStepIndex - 1]
        this.nextStep = this.steps[this.activeStepIndex + 1]
        this.activeStepDesc = this.steps[this.activeStepIndex]

        if (this.rpc.jsonrpc) {
          if (this.steps && this.steps.length > 0) {
            this.rpc.wizardSettings.steps = this.steps
          }
          this.rpc.wizardSettings.completedStep = this.prevStep || null
          this.rpc.wizardSettings.wizardComplete = !this.nextStep

          if (this.rpc.jsonrpc.UvmContext) {
            this.rpc.jsonrpc.UvmContext.setWizardSettings(function (result, ex) {
              if (ex) {
                Util.handleException(ex)
              }
            }, this.rpc.wizardSettings)
          }
        }
      },

      async onSyncSteps() {
        if (this.rpc.remote) {
          // Only for local.
          return
        }
        const rpcForAdmin = Util.setRpcJsonrpc('admin')
        this.networkSettings = await rpcForAdmin?.networkManager?.getNetworkSettings()
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

        this.tempSteps = ['License', 'ServerSettings', 'Interfaces']

        if (firstWan) {
          this.tempSteps.push('Internet')
        }
        if (firstNonWan) {
          this.tempSteps.push('InternalNetwork')
        }
        if (firstWireless) {
          this.tempSteps.push('Wireless')
        }

        this.tempSteps.push('AutoUpgrades')
        this.tempSteps.push('Complete')

        this.steps = this.tempSteps
        await this.$store.dispatch('setup/setStep', this.steps)
      },

      async onAfterRender() {
        // Iterate over the steps array and push each step into this.steps
        await this.rpc.wizardSettings.steps.forEach(stepName => {
          this.steps.push(stepName)
        })
        if (!this.rpc.wizardSettings.wizardComplete && this.rpc.wizardSettings.completedStep !== null) {
          // Get the card index based on completedStep
          this.cardIndex = await this.rpc.wizardSettings.steps.indexOf(this.rpc.wizardSettings.completedStep)

          // Decrease cardIndex if needed for next steps
          this.cardIndex--
          if (this.cardIndex >= 2) {
            // Ung.app.loading('Loading interfaces...'.t())
            this.rpc.networkManager.getNetworkSettings(async (result, ex) => {
              if (ex) {
                Util.handleException('Unable to load interfaces.'.t())
                return
              }

              this.networkSettings = result
              this.intfListLength = result.interfaces.list.length

              await this.onSyncSteps(this.cardIndex)
            })
          } else {
            this.setActiveItem(this.cardIndex + 1)
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
