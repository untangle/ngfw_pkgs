<template>
  <v-app class="ngfw d-flex flex-grow-1 fill-height">
    <component :is="component" v-if="component" />

    <u-framework-dialog />
    <u-framework-confirm />
    <u-framework-toast />
  </v-app>
</template>
<script>
  import { VApp } from 'vuetify/lib'
  import { NgfwAbout, NgfwDns } from '@/ngfw'

  export default {
    components: { NgfwAbout, NgfwDns, VApp },
    props: {
      component: { type: String, default: undefined },
    },
  }
</script>
<style lang="scss">
  .ngfw .v-application--wrap {
    min-height: 100%;
  }
</style>
