<template>
  <v-container class="text-center custom-margin" style="max-width: 800px">
    <v-img :src="require(`@/assets/${logo}`)" contain style="padding-bottom: 10%" />

    <h1>{{ `Thanks for choosing Arista!` }}</h1>

    <p>{{ `A wizard will guide you through the initial setup and configuration of the Arista Server.` }}</p>

    <div class="button-container">
      <u-btn :small="false" style="margin: 20px 0" @click="onContinue">{{ `Run Setup Wizard` }}</u-btn>
      <!-- <u-btn :small="false" style="margin: 20px 0" @click="onContinue">{{ `Resume Setup Wizard` }}</u-btn>
      <u-btn :small="false" style="margin: 20px 0" @click="onContinue">{{ `Restart` }}</u-btn> -->
    </div>
  </v-container>
</template>

<style scoped>
  .custom-margin {
    margin-top: 10px;
  }
  .button-container {
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 20px;
  }
</style>

<script>
  export default {
    computed: {
      logo() {
        return this.$vuetify.theme.isDark ? 'BrandingLogo.png' : 'BrandingLogo.png'
      },
    },
    methods: {
      async onContinue() {
        try {
          await Promise.resolve()
          // Navigate to the setup license page
          this.$router.push('/setup/license')
        } catch (error) {
          console.error('Failed to navigate:', error)
        }
      },
    },
  }
</script>
