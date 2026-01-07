<template>
  <v-container fluid class="d-flex flex-column flex-grow-1 pa-2">
    <div class="d-flex align-center">
      <v-spacer />
      <u-btn @click="onRefreshSettings">{{ $t('refresh') }}</u-btn>
      <u-btn class="ml-2" :disabled="!isDirty" @click="onSaveSettings(settingsCopy)">{{ $t('save') }}</u-btn>
    </div>
    <div class="d-flex flex-column">
      <v-spacer />
      <div class="flex-shrink-1">
        <v-tabs v-model="selectedTab" class="mb-4">
          <v-tab>
            {{ $vuntangle.$t('alerts') }}
          </v-tab>
          <v-tab>
            {{ $vuntangle.$t('triggers') }}
          </v-tab>
          <v-tab>
            {{ $vuntangle.$t('syslog') }}
          </v-tab>
          <v-tab>
            {{ $vuntangle.$t('email_template') }}
          </v-tab>
        </v-tabs>
        <!-- Tab Content -->
        <v-tabs-items v-model="selectedTab">
          <v-tab-item>
            <EventRulesList
              rule-type="alert"
              :settings="eventSettings"
              @settings-change="onSettingsChange"
            ></EventRulesList>
          </v-tab-item>
          <v-tab-item> </v-tab-item>
          <v-tab-item> </v-tab-item>
          <v-tab-item> </v-tab-item>
        </v-tabs-items>
      </div>
    </div>
  </v-container>
</template>
<script>
  import { VTabsItems, VTabItem, VContainer, VSpacer } from 'vuetify/lib'
  import EventRulesList from '../rules/EventRulesList.vue'
  import store from '@/store'

  export default {
    components: {
      VContainer,
      VSpacer,
      VTabsItems,
      VTabItem,
      EventRulesList,
    },

    data() {
      return {
        selectedTab: 0,
        isDirty: false,
        settingsCopy: null,
      }
    },

    computed: {
      // the event settings from the store
      eventSettings: ({ $store }) => $store.getters['config/eventSettings'],
    },

    created() {
      this.fetchSettings(false)
    },

    methods: {
      /**
       * Handler when using grid 'Refresh' action
       */
      onRefreshSettings() {
        this.fetchSettings(true)
      },

      /**
       * Fetches the settings and updates the store.
       * If refetch is true, it forces a re-fetch of the settings.
       * @param {boolean} refetch - Whether to force a re-fetch of the settings.
       */
      async fetchSettings(refetch) {
        this.$store.commit('SET_LOADER', true)
        await store.dispatch('config/getEventSettings', refetch).finally(() => this.$store.commit('SET_LOADER', false))
      },

      onSettingsChange(updatedSettings, isDirty) {
        this.isDirty = isDirty
        this.settingsCopy = updatedSettings
      },

      async onSaveSettings(newSettings) {
        this.$store.commit('SET_LOADER', true)
        await store
          .dispatch('config/setEventSettings', newSettings)
          .finally(() => this.$store.commit('SET_LOADER', false))
      },

      /**
       * Optional hook triggered on browser refresh. refetches the settings.
       */
      onBrowserRefresh() {
        this.fetchSettings(true)
      },
    },
  }
</script>
