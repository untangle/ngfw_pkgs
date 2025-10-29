<!-- This component is required for rendering vue pages in ExtJs project using iFrame. It can be removed once all the code is migrated to vue -->
<template>
  <v-app>
    <dynamic-drawer />
    <v-main>
      <router-view class="d-flex flex-column fill-height" />
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
  import DynamicDrawer from './DynamicDrawer.vue'

  export default {
    name: 'DynamicLayout',
    components: { DynamicDrawer },

    computed: {
      languageSettings() {
        return this.$store.getters['settings/languageSettings']
      },
    },

    watch: {
      languageSettings: {
        handler() {
          this.setLanguage()
        },
        deep: true,
      },
    },

    created() {
      this.$store.dispatch('settings/getLanguageSettings')
    },

    methods: {
      setLanguage() {
        if (this.languageSettings && this.languageSettings.language) {
          this.$i18n.setLocale(this.languageSettings.language)
        }
      },
    },
  }
</script>
