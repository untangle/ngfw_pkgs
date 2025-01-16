<template>
  <v-container class="text-center" style="max-width: 800px">
    <h1 class="font-weight-light">{{ $t('welcome') }},</h1>
    <h2 class="font-weight-light">{{ $t('setup_thanks') }}</h2>

    <v-divider class="mt-6 mb-6" />

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
  import store from '@/store'
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
      // checks if the box has online access and load remote or local eula
      async setEulaSrc() {
        this.remoteEulaSrc = await uris.translate(uris.list.legal)
      },

      async onContinue() {
        store.commit('SET_LOADER', true)
        const nextStep = await store.dispatch('setup/setStatus', 'license')
        store.commit('SET_LOADER', false)
        if (nextStep) {
          this.$router.push(`/setup/${nextStep}`)
        }
      },
    },
  }
</script>
