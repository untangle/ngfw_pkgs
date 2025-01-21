<template>
  <div class="auto-upgrades">
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
  </div>
</template>

<script>
  export default {
    name: 'Autoupgrades',
    data() {
      return {
        autoUpdatesEnabled: true,
        connectToETM: true,
      }
    },
  }
</script>

<style scoped>
  .auto-upgrades {
    display: flex;
    flex-direction: column;
    justify-content: flex-start; /* Align content to the top */
    align-items: center; /* Horizontally center the content */
    margin: 20px 20px 10px 20px; /* Reduced bottom margin to 10px */
    border: 1px solid #ccc;
    border-radius: 5px;
    background-color: #f9f9f9;
    font-family: Arial, sans-serif;
    height: calc(100vh - 40px); /* Ensure the height fits within the viewport, considering margins */
    overflow: hidden; /* Hide any overflow */
  }
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
