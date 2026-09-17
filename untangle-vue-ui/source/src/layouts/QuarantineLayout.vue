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
    data() {
      return {
        dynamicHeader: '',
        headerSetByChild: false, // Track if child component has set the header
      }
    },
    computed: {
      /**
       * Computed header - uses dynamic header if set by child, otherwise default
       */
      computedHeader() {
        // Check if child component has explicitly set the header
        if (this.headerSetByChild) {
          return this.dynamicHeader
        }
        // Default fallback - only show if no child component has set the header yet
        return this.$t('quarantine')
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
        // Set toolbar header and mark that it's been set by a child component
        this.dynamicHeader = header
        this.headerSetByChild = true
      },
    },
  }
</script>
