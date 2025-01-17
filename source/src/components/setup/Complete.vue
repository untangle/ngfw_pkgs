<template>
  <v-card width="350" class="mx-auto text-center" flat>
    <v-icon size="128" color="green">mdi-check</v-icon>

    <!-- Ensure the text stays on a single line -->
    <h2 class="font-weight-light single-line">{{ $t('The Arista Server is configured now') }}</h2>
    <p>{{ $t('You are now ready to configure the applications.') }}</p>
    <br />
    <u-btn :small="false" to="/">{{ $t('Go to dashboard') }}</u-btn>
  </v-card>
</template>

<script>
  import store from '@/store'

  export default {
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
    },
  }
</script>

<style scoped>
  /* Prevent text wrapping on the h2 element */
  .single-line {
    white-space: nowrap;
    /* overflow: hidden; */
    text-overflow: ellipsis; /* Optional: adds ellipsis if the text overflows */
  }

  .v-card {
    max-width: 400px;
    margin: auto;
  }
</style>
