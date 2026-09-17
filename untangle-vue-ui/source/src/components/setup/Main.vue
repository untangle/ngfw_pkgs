<template>
  <router-view />
</template>

<script>
  import store from '@/store'
  export default {
    computed: {
      steps() {
        return store.getters['setup/steps']
      },
      setupWizard() {
        return store.getters['config/setupWizard']
      },
      currentStep() {
        return this.setupWizard?.step || this.steps[0]
      },
    },
    watch: {
      setupWizard(value) {
        if (value.completed) {
          this.$router.push('/setup/complete')
        } else {
          this.$router.push(`/setup/${this.currentStep}`)
        }
      },
    },
    mounted() {
      // have to fetch interfaces to know if needed to add Lte or WiFi steps
      store.dispatch('config/getInterfaces')
      store.dispatch('setup/getStatus')
    },
  }
</script>
