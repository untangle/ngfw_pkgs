<template>
  <v-container fluid class="d-flex justify-center pt-12">
    <NotificationUserapi :company-name="companyName" />
  </v-container>
</template>

<script>
  import { NotificationUserapi } from 'vuntangle'

  export default {
    name: 'NotificationUserapiPage',

    components: {
      NotificationUserapi,
    },

    data() {
      return {
        companyName: '',
      }
    },

    async mounted() {
      this.companyName = (await this.$store.dispatch('apps/getCompanyName')) || ''
    },
  }
</script>
