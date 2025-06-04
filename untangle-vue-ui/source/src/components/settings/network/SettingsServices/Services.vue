<template>
  <v-container fluid class="shared-cmp d-flex flex-column flex-grow-1 pa-2">
    <!-- Header -->
    <div class="d-flex align-center mb-2">
      <h1 class="headline">{{ $vuntangle.$t('Services') }}</h1>
      <v-spacer />
      <u-btn color="primary" class="mr-2" @click="onSave">
        {{ $vuntangle.$t('Save') }}
      </u-btn>
    </div>

    <!-- Local Services Label -->
    <!-- <v-toolbar flat dense class="pl-0"> -->
    <v-toolbar-title class="text-subtitle-1 font-weight-bold">
      {{ $t('Local Services') }}
    </v-toolbar-title>
    <!-- </v-toolbar> -->

    <!-- HTTPS Description -->
    <div class="body-2 text--secondary mb-1 mt-2">
      {{
        $t(
          'The specified HTTPS port will be forwarded from all interfaces to the local HTTPS server to provide administration and other services.',
        )
      }}
    </div>
    <!-- HTTPS Field -->
    <v-row class="mt-0 mb-1">
      <v-col cols="12" sm="4" md="3">
        <v-text-field
          v-model.number="form.httpsPort"
          :label="$t('HTTPS port')"
          type="number"
          :rules="portRules"
          dense
          outlined
          :suffix="'PORT'"
          required
        />
      </v-col>
    </v-row>

    <!-- HTTP Description -->
    <div class="body-2 text--secondary mb-1 mt-1">
      {{
        $t(
          'The specified HTTP port will be forwarded on non-WAN interfaces to the local HTTP server to provide administration, blockpages, and other services.',
        )
      }}
    </div>

    <!-- HTTP Field -->
    <v-row class="mt-0">
      <v-col cols="12" sm="4" md="3">
        <v-text-field
          v-model.number="form.httpPort"
          :label="$t('HTTP port')"
          type="number"
          :rules="portRules"
          dense
          outlined
          :suffix="'PORT'"
          required
        />
      </v-col>
    </v-row>
  </v-container>
</template>

<script>
  export default {
    name: 'ServicesForm',
    props: {
      value: Object,
    },
    data() {
      return {
        valid: true,
        form: {
          httpsPort: this.value?.httpsPort || 443,
          httpPort: this.value?.httpPort || 80,
        },
        portRules: [
          v => !!v || this.$t('You must provide a valid port.'),
          v => (v >= 0 && v <= 65535) || this.$t('Port must be between 0 and 65535'),
        ],
      }
    },
    watch: {
      form: {
        handler(val) {
          this.$emit('input', val)
        },
        deep: true,
      },
    },
  }
</script>
