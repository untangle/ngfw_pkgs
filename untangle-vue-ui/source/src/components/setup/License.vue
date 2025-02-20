<template>
  <div>
    <SetupLayout />
    <v-container class="text-center" style="max-width: 600px">
      <h1 class="d-flex font-weight-light text-center faint-color">
        License
        <v-spacer />
      </h1>
      <br />
      <p>{{ $t('setup_review_license') }}</p>
      <p>
        {{ $t('setup_license_available_at') }}
        <a :href="remoteEulaSrc" target="_blank">{{ remoteEulaSrc }}</a>
      </p>
      <p>
        <b>{{ $t('setup_legal_links_available_at') }}</b>
      </p>

      <div class="button-container">
        <u-btn :small="false" style="margin: 8px 0" @click="onClickDisagree">Disagree</u-btn>
        <u-btn :small="false" style="margin: 8px 0" @click="onContinue">Agree</u-btn>
      </div>
    </v-container>
  </div>
</template>

<script>
  import { mapActions } from 'vuex'
  import uris from '@/util/uris'
  import SetupLayout from '@/layouts/SetupLayout.vue'

  export default {
    name: 'License',
    components: {
      SetupLayout,
    },
    data: () => ({
      remoteEulaSrc: null,
    }),
    mounted() {
      this.setEulaSrc()
    },
    methods: {
      ...mapActions('setup', ['setShowStep']), // Map the setShowStep action from Vuex store
      ...mapActions('setup', ['setShowPreviousStep']),

      async setEulaSrc() {
        this.remoteEulaSrc = await uris.translate(uris.list.legal)
      },

      async onContinue() {
        try {
          await Promise.resolve()
          await this.setShowStep('System') // Transition to System step
          await this.setShowPreviousStep('License')
        } catch (error) {
          console.error('Failed to navigate to System step:', error)
        }
      },

      async onClickDisagree() {
        try {
          await this.setShowStep('Wizard') // Navigate back to Wizard step
        } catch (error) {
          console.error('Failed to navigate to Wizard step:', error)
        }
      },
    },
  }
</script>

<style scoped>
  .faint-color {
    color: rgba(0, 0, 0, 0.5); /* Adjust the color and opacity */
  }
  .button-container {
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 50px;
  }
</style>
