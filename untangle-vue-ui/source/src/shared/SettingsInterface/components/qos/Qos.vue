<template>
  <div>
    <!-- qosEnabled -->
    <v-switch v-model="intf.qosEnabled" :label="$t('qos_enabled')" class="ma-0" />
    <v-row>
      <v-col cols="4">
        <!-- downloadKbps -->
        <ValidationProvider v-slot="{ errors }" :rules="intf.qosEnabled ? `required|min_value:1` : ''">
          <u-text-field
            v-model="downloadMbps"
            :label="$vuntangle.$t('download')"
            type="number"
            :disabled="!intf.qosEnabled"
            :error-messages="errors"
            suffix="Mbps"
          >
            <template v-if="errors.length" #append>
              <u-errors-tooltip :errors="errors" />
            </template>
          </u-text-field>
        </ValidationProvider>
      </v-col>

      <v-col cols="4">
        <!-- uploadKbps -->
        <ValidationProvider v-slot="{ errors }" :rules="intf.qosEnabled ? `required|min_value:1` : ''">
          <u-text-field
            v-model="uploadMbps"
            :label="$t('upload')"
            type="number"
            :disabled="!intf.qosEnabled"
            :error-messages="errors"
            suffix="Mbps"
          >
            <template v-if="errors.length" #append>
              <u-errors-tooltip :errors="errors" />
            </template>
          </u-text-field>
        </ValidationProvider>
      </v-col>

      <v-col cols="4" class="d-flex">
        <v-spacer />
        <u-btn v-if="performanceTestEnabled" :small="false" :disabled="!intf.qosEnabled" @click="startPerformanceTest">
          {{ $t('test_performance') }}
        </u-btn>
      </v-col>
    </v-row>

    <v-dialog v-model="test.show" width="400" persistent>
      <v-card>
        <v-card-title class="text-h5 font-weight-light">
          {{ $t('testing_wan_performance') }}
        </v-card-title>
        <v-card-text>
          <v-progress-linear v-if="test.progress" v-model="test.counter" height="10" striped class />
          <div v-else-if="statusWanTest && statusWanTest.download && statusWanTest.upload">
            <span>
              {{ $vuntangle.$t('download') }}: <strong>{{ statusWanTest.download / 1000 }} {{ $t('mbps') }}</strong>
              <br />
              {{ $t('upload') }}: <strong> {{ statusWanTest.upload / 1000 }} {{ $t('mbps') }} </strong>
            </span>
          </div>
          <div v-else>
            {{ $t('wan_test_failed', []) }}
          </div>
        </v-card-text>
        <v-card-actions v-if="!test.progress">
          <v-spacer />
          <u-btn :min-width="null" class="my-2" @click="onCloseTestDialog">
            {{ $t('ok') }}
          </u-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>
<script>
  import { VProgressLinear } from 'vuetify/lib'
  const bpsConvertFactor = 1000

  export default {
    components: {
      VProgressLinear,
    },
    inject: ['$intf', '$status', '$onGetStatusHardware', '$onGetStatusWanTest'],
    data() {
      return {
        statusHardware: null,
        statusWanTest: null,
        test: {
          show: false,
          progress: false,
          counter: 0,
          interval: null,
        },
      }
    },
    computed: {
      intf: ({ $intf }) => $intf(),
      status: ({ $status }) => $status(),

      /** converts settings download Kbps to Mbps and back */
      downloadMbps: {
        get: ({ intf }) => intf.downloadKbps / bpsConvertFactor,
        set(value) {
          this.intf.downloadKbps = value * bpsConvertFactor
        },
      },

      /** converts settings upload Kbps to Mbps and back */
      uploadMbps: {
        get: ({ intf }) => intf.uploadKbps / bpsConvertFactor,
        set(value) {
          this.intf.uploadKbps = value * bpsConvertFactor
        },
      },

      /** enables performance test if interface has a status and is not an E3 device */
      performanceTestEnabled: ({ status, statusHardware }) => {
        if (!status || !statusHardware) return false
        if (statusHardware.boardName && statusHardware.boardName.match(/e3/i)) {
          return false
        }
        return true
      },
    },

    watch: {
      'intf.qosEnabled': {
        handler(value) {
          if (value && !this.intf.downloadKbps && !this.intf.uploadKbps) {
            this.$set(this.intf, 'downloadKbps', 1000)
            this.$set(this.intf, 'uploadKbps', 1000)
          }
        },
        immediate: true,
      },
    },

    created() {
      /** emits event to get hardware status needed for performance test */
      this.$onGetStatusHardware(resp => (this.statusHardware = resp))
    },

    methods: {
      /** shows progress dialog and emits event to start the wan performance test */
      startPerformanceTest() {
        this.test.show = true
        this.test.interval = setInterval(() => {
          // when counter hits 100% stop the progress and clear interval
          if (this.test.counter >= 100) {
            this.test.counter = 100
            clearInterval(this.test.interval)
            this.test.interval = null
          } else {
            // counter value (progress bar update) each 100ms = 0.33% => 30 seconds = 99%
            this.test.counter += 0.33
          }
        }, 100)

        this.test.progress = true
        this.$onGetStatusWanTest(this.status.l3device, resp => {
          this.statusWanTest = resp
          this.test.progress = false
        })
      },

      /** populates the download, upload values with test results and closes the dialog */
      onCloseTestDialog() {
        if (this.statusWanTest?.download >= 0) this.intf.downloadKbps = this.statusWanTest.download
        if (this.statusWanTest?.upload >= 0) this.intf.uploadKbps = this.statusWanTest.upload
        this.statusWanTest = null
        this.test = {
          show: false,
          progress: false,
          counter: 0,
          interval: null,
        }
      },
    },
  }
</script>
