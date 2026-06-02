<template>
  <v-container fluid class="d-flex justify-center pt-12">
    <NotificationUserapi :company-name="companyName" />
  </v-container>
</template>

<script>
  import { NotificationUserapi } from 'vuntangle'
  import { mapActions } from 'vuex'

  export default {
    name: 'NotificationUserapiPage',

    components: {
      NotificationUserapi,
    },

    data() {
      return {
        // Company name fetched from store
        companyName: '',
      }
    },

    mounted() {
      this.fetchCompanyName()
    },

    methods: {
      ...mapActions('apps', ['getCompanyName']),

      async fetchCompanyName() {
        this.companyName = (await this.getCompanyName()) || ''
      },
    },
  }
</script>
