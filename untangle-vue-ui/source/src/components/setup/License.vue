<template>
  <v-container class="text-center" style="max-width: 600px">
    <h1 class="d-flex font-weight-light text-center faint-color">
      License
      <v-spacer />
    </h1>
    <br />
    <p>{{ $t('setup_review_license') }}</p>

    <p :style="paragraphStyle">
      {{ $t('setup_license_available_at') }} <a :href="remoteEulaSrc" target="_blank">{{ remoteEulaSrc }}</a>
    </p>
    <p>
      <b>{{ $t('setup_legal_links_available_at') }}</b>
    </p>

    <div class="button-container">
      <!-- <u-btn :small="false" text>Disagree</u-btn> -->
      <u-btn :small="false" style="margin: 8px 0" @click="onClickDisagree">Disagree</u-btn>
      <u-btn :small="false" style="margin: 8px 0" @click="onContinue">Agree</u-btn>
    </div>
  </v-container>
</template>

<script>
  import uris from '@/util/uris'

  export default {
    data: () => ({
      paragraphStyle: {
        marginTop: '5px',
        wordWrap: 'break-word',
        textAlign: 'center',
      },
      remoteEulaSrc: null,
      eulaSrc: null,
    }),
    mounted() {
      this.setEulaSrc()
    },
    methods: {
      async onContinue() {
        try {
          await Promise.resolve()
          // Navigate to the setup license page
          this.$router.push('/setup/system')
        } catch (error) {
          console.error('Failed to navigate:', error)
        }
      },
      async onClickDisagree() {
        try {
          await Promise.resolve()
          // Navigate to the setup license page
          this.$router.push('/setup/')
        } catch (error) {
          console.error('Failed to navigate:', error)
        }
      },
      // checks if the box has online access and load remote or local eula
      async setEulaSrc() {
        this.remoteEulaSrc = await uris.translate(uris.list.legal)
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
