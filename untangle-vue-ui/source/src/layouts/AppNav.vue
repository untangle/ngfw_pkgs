<template>
  <v-app-bar dark clipped-left fixed flat app color="aristaBlue" height="50">
    <v-btn icon @click="toggleMiniDrawer">
      <v-icon>
        {{ $store.state.miniDrawer ? 'mdi-menu' : 'mdi-menu-open' }}
      </v-icon>
    </v-btn>

    <router-link to="/" class="text-decoration-none ml-2" style="line-height: 12px">
      <v-img :src="require('@/assets/arista-logo-white.svg')" contain width="100" transition="false" />
      <span class="white--text ml-1 font-weight-bold" style="font-size: 10px">NGFW</span>
    </router-link>

    <v-spacer />

    <v-menu dark bottom left offset-y transition="slide-y-transition" nudge-bottom="8" content-class="ut-app-menu">
      <template #activator="{ on }">
        <v-btn text class="account-menu-activator" v-on="on">
          <v-icon>mdi-account-circle</v-icon>
          <v-icon right>mdi-chevron-down</v-icon>
        </v-btn>
      </template>
      <v-list dense color="#16325B" width="200">
        <v-list-item @click="logout">
          <v-list-item-icon class="mr-4"><v-icon>mdi-exit-to-app</v-icon></v-list-item-icon>
          <v-list-item-title>Logout</v-list-item-title>
        </v-list-item>
        <v-divider class="my-2" />

        <v-menu
          dark
          left
          offset-x
          open-on-hover
          nudge-top="6"
          nudge-right="2"
          :close-on-content-click="false"
          transition="slide-x-reverse-transition"
        >
          <template #activator="{ on }">
            <v-list-item v-on="on">
              <v-list-item-icon class="mr-4"><v-icon dense>mdi-palette</v-icon></v-list-item-icon>
              <v-list-item-title>{{ $t('theme') }}</v-list-item-title>
              <v-list-item-icon><v-icon dense>mdi-chevron-right</v-icon></v-list-item-icon>
            </v-list-item>
          </template>
          <v-card flat class="mr-1" color="transparent">
            <v-list nav dense color="#16325B">
              <v-list-item @click="theme = 'light'">
                <v-list-item-icon class="mr-4">
                  <v-icon v-if="theme === 'light'" dense>mdi-check</v-icon>
                </v-list-item-icon>
                <v-list-item-title>{{ $t('light') }}</v-list-item-title>
                <v-list-item-icon><v-icon dense>mdi-white-balance-sunny</v-icon></v-list-item-icon>
              </v-list-item>
              <v-list-item @click="theme = 'dark'">
                <v-list-item-icon class="mr-4">
                  <v-icon v-if="theme === 'dark'" dense>mdi-check</v-icon>
                </v-list-item-icon>
                <v-list-item-title>{{ $t('dark') }}</v-list-item-title>
                <v-list-item-icon><v-icon dense>mdi-moon-waning-crescent</v-icon></v-list-item-icon>
              </v-list-item>
            </v-list>
          </v-card>
        </v-menu>

        <v-menu
          dark
          left
          offset-x
          open-on-hover
          nudge-top="6"
          nudge-right="2"
          :close-on-content-click="false"
          transition="slide-x-reverse-transition"
        >
          <template #activator="{ on }">
            <v-list-item v-on="on">
              <v-list-item-icon class="mr-4"><v-icon dense>mdi-translate</v-icon></v-list-item-icon>
              <v-list-item-title>{{ $t('language') }}</v-list-item-title>
              <v-list-item-icon><v-icon>mdi-chevron-right</v-icon></v-list-item-icon>
            </v-list-item>
          </template>
          <v-card flat class="mr-1" color="transparent">
            <v-list nav dense color="#16325B">
              <v-list-item
                v-for="locale in $i18n.availableLocalesForUI"
                :key="locale.code"
                @click="$i18n.setLocale(locale.code)"
              >
                <v-list-item-icon class="mr-4">
                  <v-icon v-if="locale.code === $i18n.locale" dense>mdi-check</v-icon>
                </v-list-item-icon>
                <v-list-item-title>{{ locale.language }}</v-list-item-title>
              </v-list-item>
            </v-list>
          </v-card>
        </v-menu>
      </v-list>
    </v-menu>
  </v-app-bar>
</template>
<script>
  import store from '@/store'
  import api from '@/plugins/api'

  export default {
    data: () => ({
      theme: store.getters['config/theme'],
    }),
    computed: {
      languageSettings() {
        return this.$store.getters['config/languageSettings']
      },
      upgradeStatus() {
        return store.getters['config/upgradeStatus']
      },
    },

    watch: {
      // set theme if selection changes
      theme: {
        immediate: true,
        handler(theme) {
          if (theme) store.dispatch('config/setTheme', theme)
        },
      },
      // set selection if theme changes from somewhere else
      '$vuntangle.theme'(theme) {
        this.theme = theme
      },
      languageSettings: {
        handler() {
          this.setLanguage()
        },
        deep: true,
      },
    },

    created() {
      this.$store.dispatch('config/getLanguageSettings')
    },

    methods: {
      // toggles the drawer expended or not state
      toggleMiniDrawer() {
        store.commit('SET_MINI_DRAWER', !store.state.miniDrawer)
      },
      async logout() {
        await api.get('/auth/logout?url=/admin&realm=Administrator')
        window.rpc = undefined
        this.$router.push({ name: 'login' })
      },
      setLanguage() {
        if (this.languageSettings && this.languageSettings.language) {
          this.$i18n.setLocale(this.languageSettings.language)
        }
      },
    },
  }
</script>
<style>
  .ut-app-button.v-btn--active::before,
  .ut-app-button.v-btn--active:hover::before {
    opacity: 0.18;
  }
</style>
