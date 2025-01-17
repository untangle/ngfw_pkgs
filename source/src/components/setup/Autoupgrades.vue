<template>
  <v-container class="text-center" style="max-width: 800px">
    <h2>{{ $t('Automatic Upgrades and ETM Dashboard Access') }}</h2>

    <!-- Checkbox for Automatically Install Updates -->
    <v-row>
      <v-col cols="12">
        <v-checkbox
          id="enable-updates"
          v-model="autoUpdatesEnabled"
          :label="$t('Automatically Install Upgrades')"
          hide-details
        ></v-checkbox>
        <v-row>
          <v-col cols="12">
            <p>{{ $t('Automatically install new versions of the software when available.') }}</p>
            <p>{{ $t('This is the recommended choice for most sites.') }}</p>
          </v-col>
        </v-row>
      </v-col>
    </v-row>

    <!-- Checkbox for Connect to ETM Dashboard -->
    <v-row>
      <v-col cols="12">
        <v-checkbox
          id="enable-etm-dashboard"
          v-model="connectToETM"
          :label="$t('Connect to ETM Dashboard')"
          hide-details
        ></v-checkbox>
        <v-row>
          <v-col cols="12">
            <p>
              {{
                $t(
                  'Remain securely connected to the ETM Dashboard for cloud management, hot fixes, and support access.',
                )
              }}
            </p>
            <p>{{ $t('This is the recommended choice for most sites.') }}</p>
          </v-col>
        </v-row>
      </v-col>
    </v-row>
  </v-container>
</template>

<script>
  export default {
    name: 'MyComponent',
    data() {
      return {
        autoUpdatesEnabled: true,
        connectToETM: true,
      }
    },
  }
</script>

<style scoped>
  .text-center {
    text-align: center;
  }

  .v-checkbox {
    margin-bottom: 20px;
  }

  h2 {
    font-size: 24px;
    font-weight: 600;
    margin-bottom: 20px;
  }

  p {
    font-size: 14px;
    color: #6c757d;
    margin: 5px 0;
    text-align: left;
  }
</style>
