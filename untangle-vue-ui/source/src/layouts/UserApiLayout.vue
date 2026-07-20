<!-- Minimal layout for the User Notification Login Script standalone page -->
<template>
  <v-app>
    <!-- Top Navigation Bar -->
    <v-app-bar app dark color="#16325B" elevation="0" height="64">
      <v-container fluid class="d-flex align-center pa-0 px-4">
        <!-- Logo -->
        <div class="ml-2" style="line-height: 12px">
          <v-img :src="require('@/assets/arista-logo-white.svg')" contain width="100" transition="false" />
          <span class="white--text ml-1 font-weight-bold" style="font-size: 10px">NGFW</span>
        </div>

        <!-- Header -->
        <v-toolbar-title class="ml-6" style="color: #ccc; font-size: 16px">
          {{ computedHeader }}
        </v-toolbar-title>
      </v-container>
    </v-app-bar>

    <!-- Main Content -->
    <v-main>
      <router-view />
    </v-main>

    <v-overlay v-model="$store.state.pageLoad">
      <v-progress-circular indeterminate size="32" color="aristaBlue" />
    </v-overlay>

    <u-framework-dialog />
    <u-framework-confirm />
    <u-framework-toast />
  </v-app>
</template>

<script>
  import { VToolbarTitle } from 'vuetify/lib'

  export default {
    name: 'UserApiLayout',
    components: {
      VToolbarTitle,
    },
    provide() {
      return {
        setUserApiTitle: this.setTitle,
        setUserApiHeader: this.setHeader,
      }
    },
    data() {
      return {
        dynamicHeader: '',
        headerSetByChild: false,
      }
    },
    computed: {
      computedHeader() {
        if (this.headerSetByChild) {
          return this.dynamicHeader
        }
        return this.$t('user_notification_login_script')
      },
    },
    methods: {
      setTitle(title) {
        if (title) {
          document.title = title
        }
      },
      setHeader(header) {
        this.dynamicHeader = header
        this.headerSetByChild = true
      },
    },
  }
</script>
