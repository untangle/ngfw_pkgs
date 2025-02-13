<template>
  <v-card width="1100" height="500" class="mx-auto mt-3" flat>
    <SetupLayout />
    <div class="auto-upgrades">
      <v-container class="text-center">
        <h2 class="font-weight-light single-line">{{ $t('The Arista Server is configured now') }}</h2>
        <p>{{ $t('You are now ready to configure the applications.') }}</p>

        <br />
        <u-btn :small="false" @click="onClickDashboard">
          <v-icon icon="mdi-check">mdi-check</v-icon>
          {{ $t('Go to dashboard') }}</u-btn
        >
      </v-container>
    </div>
  </v-card>
</template>

<script>
  import store from '@/store'
  import SetupLayout from '@/layouts/SetupLayout.vue'
  export default {
    components: {
      SetupLayout,
    },
    data() {
      return {}
    },
    methods: {
      async onReset() {
        try {
          const nextStep = await store.dispatch('setup/resetStatus')
          if (nextStep) {
            this.$router.push(`/setup/${nextStep}`)
          }
        } catch (error) {
          console.error('Error resetting setup:', error)
          alert('Failed to reset setup. Please try again later.')
        }
      },
      async onClickDashboard() {
        try {
          // /admin/index.do
          await Promise.resolve()
          await this.setShowStep('Interface')
          await this.setShowPreviousStep('Interface')
        } catch (error) {
          alert('Failed to navigate:', error)
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
