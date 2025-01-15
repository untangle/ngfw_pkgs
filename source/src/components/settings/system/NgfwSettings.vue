<template>
  <v-container>
    <ValidationObserver>
      <!-- `hostName`, `domain` and `timeZone` settings -->
      <u-section :title="$vuntangle.$t('settings')">
        <v-row>
          <v-col cols="12" lg="3">
            <ValidationProvider v-slot="{ errors }" rules="required">
              <u-text-field v-model="settings.hostName" :label="$t('host_name')" :error-messages="errors">
                <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
              </u-text-field>
            </ValidationProvider>
          </v-col>
          <v-col cols="12" lg="3">
            <ValidationProvider v-slot="{ errors }" rules="required">
              <u-text-field v-model="settings.domainName" :label="$t('domain_name')" :error-messages="errors">
                <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
              </u-text-field>
            </ValidationProvider>
          </v-col>
        </v-row>
      </u-section>

      <!-- `httpPort` and `httpsPort` settings -->
      <u-section :title="$vuntangle.$t('web_admin_ports')">
        <v-row>
          <v-col cols="12" lg="3">
            <ValidationProvider v-slot="{ errors }" rules="required|port">
              <u-text-field v-model="settings.httpPort" type="number" :label="$t('http_port')" :error-messages="errors">
                <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
              </u-text-field>
            </ValidationProvider>
          </v-col>
          <v-col cols="12" lg="3">
            <ValidationProvider v-slot="{ errors }" rules="required|port">
              <u-text-field
                v-model="settings.httpsPort"
                type="number"
                :label="$t('https_port')"
                :error-messages="errors"
              >
                <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
              </u-text-field>
            </ValidationProvider>
          </v-col>
        </v-row>
      </u-section>
    </ValidationObserver>
    <u-btn class="mt-4" @click="onSaveSettings">{{ $t('save') }}</u-btn>
  </v-container>
</template>
<script>
  export default {
    data() {
      return {
        settings: undefined,
      }
    },

    computed: {
      networkSettings: ({ $store }) => $store.getters['settings/networkSettings'],
    },

    watch: {
      networkSettings: {
        handler(settings) {
          if (settings) this.settings = settings
        },
        immediate: true,
      },
    },

    methods: {
      async onSaveSettings() {
        await this.$store.dispatch('settings/saveNetworkSettings', this.settings)
      },
    },
  }
</script>
