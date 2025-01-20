<template>
  <v-container class="text-center" style="max-width: 800px">
    <br />
    <p>{{ $t('setup_review_license') }}</p>

    <p>
      {{ $t('setup_license_available_at') }} <a :href="remoteEulaSrc" target="_blank">{{ remoteEulaSrc }}</a>
    </p>
    <p>
      <b>{{ $t('setup_legal_links_available_at') }}</b>
    </p>

    <div>
      <!-- <u-btn :small="false" text>Disagree</u-btn> -->
      <u-btn :small="false" @click="onContinue">{{ $t('agree') }}</u-btn>
    </div>
  </v-container>
</template>

<script>
  import uris from '@/util/uris'

  export default {
    data: () => ({
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
      // checks if the box has online access and load remote or local eula
      async setEulaSrc() {
        this.remoteEulaSrc = await uris.translate(uris.list.legal)
      },
    },
  }
</script>
