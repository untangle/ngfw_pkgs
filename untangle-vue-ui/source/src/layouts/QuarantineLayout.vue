<!-- Minimal layout for quarantine pages - no navigation, just content -->
<template>
  <v-app>
    <!-- Top Navigation Bar -->
    <v-app-bar app dark color="#16325B" elevation="0" height="64">
      <v-container fluid class="d-flex align-center pa-0 px-4">
        <!-- Logo (readonly, not a link) -->
        <div class="ml-2" style="line-height: 12px">
          <v-img :src="require('@/assets/arista-logo-white.svg')" contain width="100" transition="false" />
          <span class="white--text ml-1 font-weight-bold" style="font-size: 10px">NGFW</span>
        </div>

        <!-- Header - uses computed header -->
        <v-toolbar-title class="ml-6" style="color: #ccc; font-size: 16px">
          {{ computedHeader }}
        </v-toolbar-title>
      </v-container>
    </v-app-bar>

    <!-- Main Content -->
    <v-main>
      <router-view />
    </v-main>

    <!-- Overlays and dialogs -->
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
    name: 'QuarantineLayout',
    components: {
      VToolbarTitle,
    },
    provide() {
      return {
        setQuarantineTitle: this.setTitle,
        setQuarantineHeader: this.setHeader,
      }
    },
    props: {
      /**
       * Page title to set in document.title (browser tab)
       */
      title: {
        type: String,
        default: '',
      },
      /**
       * Header text to display in the toolbar
       */
      header: {
        type: String,
        default: '',
      },
    },
    data() {
      return {
        dynamicHeader: '',
      }
    },
    computed: {
      /**
       * Computed header - uses dynamic header if set, otherwise prop, otherwise default
       */
      computedHeader() {
        // First check dynamic header (set by child components)
        if (this.dynamicHeader) {
          return this.dynamicHeader
        }
        // Then check prop (passed from App.vue)
        if (this.header) {
          return this.header
        }
        // Default fallback
        return this.$t('quarantine')
      },
    },
    watch: {
      title: {
        immediate: true,
        handler(newTitle) {
          if (newTitle) {
            document.title = newTitle
          }
        },
      },
    },
    methods: {
      setTitle(title) {
        // Set document.title (browser tab title)
        if (title) {
          document.title = title
        }
      },
      setHeader(header) {
        // Set toolbar header
        this.dynamicHeader = header
      },
    },
  }
</script>
