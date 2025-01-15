<template>
  <v-card width="350" class="mx-auto text-center" flat>
    <v-icon size="128" color="green">mdi-check</v-icon>

    <h2 class="font-weight-light">{{ $t('setup_is_complete') }}</h2>
    <br />
    <u-btn :small="false" to="/">{{ $t('open_dashboard') }}</u-btn>
  </v-card>
</template>
<script>
  import store from '@/store'

  export default {
    data: () => ({}),
    methods: {
      async onReset() {
        const nextStep = await store.dispatch('setup/resetStatus')
        if (nextStep) {
          this.$router.push(`/setup/${nextStep}`)
        }
      },
    },
  }
</script>
