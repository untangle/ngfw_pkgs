<template>
  <Troubleshooting @run-test="onRunTest" @export-output="onExportOutput" />
</template>
<script>
  import { Troubleshooting } from 'vuntangle'
  import settingsMixin from '../settingsMixin'
  import Util from '@/util/setupUtil'
  import util from '@/util/util'

  export default {
    components: { Troubleshooting },
    mixins: [settingsMixin],

    provide() {
      return {
        $remoteData: () => ({
          interfaceOptions: this.interfaceOptions,
          dnsTestHost: this.dnsTestHost,
          tcpTestHost: this.tcpTestHost,
        }),
      }
    },

    computed: {
      // uri settings from store
      uriSettings: ({ $store }) => $store.getters['settings/uriSettings'],

      // network settings from the store
      networkSettings: ({ $store }) => $store.getters['settings/networkSetting'],

      // dns test host from uri settings for Connectivity test
      dnsTestHost: ({ uriSettings }) => uriSettings?.dnsTestHost,
      // tcp test host from uri settings for Connectivity test
      tcpTestHost: ({ uriSettings }) => uriSettings?.tcpTestHost,

      // interface options for select dropdown in packet test
      interfaceOptions: ({ networkSettings }) => {
        const interfaces = networkSettings?.interfaces || []
        const interfaceOptions = interfaces.map(intf => ({
          text: intf.name,
          value: intf.systemDev,
        }))
        interfaceOptions.push({ text: 'OpenVPN', value: 'tun0' })
        return interfaceOptions
      },
    },

    created() {
      this.$store.dispatch('settings/getUriSettings', false)
      this.$store.dispatch('settings/getNetworkSettings', false)
    },

    methods: {
      /**
       * handler for run-test event
       * runs the selected test by calling rpc
       * @param params parameters for the test
       * @param test test object from vuntangle component
       */
      onRunTest(params, test) {
        const text = []

        test.isRunning = true
        text.push(test?.output)
        text.push(new Date().toString() + ' - Test Started\n')

        // call RPC
        window.rpc.networkManager.runTroubleshooting(
          (resultReader, err) => {
            if (err) {
              test.isRunning = false
              Util.handleException(err)
              return
            }
            // integrate with readOutput loop
            this.readOutput(resultReader, text, test, params)
          },
          params?.command,
          params?.args,
        )
      },

      /**
       * read output from resultReader and append to text array
       * @param resultReader reader object from rpc
       * @param text array of text lines
       * @param test test object from vuntangle component
       * @param params parameters for the test
       */
      readOutput(resultReader, text, test, params) {
        let result = text.join('')
        if (!resultReader) return

        const self = this

        resultReader.readFromOutput(function (res, ex) {
          if (ex) {
            Util.handleException(ex)
            return
          }

          if (res !== null) {
            text.push(res)
            setTimeout(function () {
              self.readOutput(resultReader, text, test, params)
            }, 1000)
          } else {
            test.isRunning = false
            text.push(new Date().toString() + ' - Test Completed')
            text.push('\n\n--------------------------------------------------------\n\n')
            if (params?.args?.FILENAME) {
              test.exportFilename = params.args.FILENAME
              params.args.FILENAME = ''
            }
          }

          result = text.join('')
          test.output = result
        })
      },

      /**
       * handler for export-output event
       * downloads the file from server
       * @param filename name of the file to be downloaded
       */
      async onExportOutput(filename) {
        try {
          await util.downloadFile(
            '/admin/download',
            {
              type: 'NetworkTestExport',
              arg1: filename,
            },
            filename,
          )
          this.$vuntangle.toast.add(this.$vuntangle.$t('downloading_packet_dump'))
        } catch {
          this.$vuntangle.toast.add(this.$vuntangle.$t('download_failed_try_again'), 'error')
        }
      },

      /**
       * Optional hook triggered on browser refresh. refetches the settings.
       */
      onBrowserRefresh() {
        this.$store.dispatch('settings/getNetworkSettings', true)
      },
    },
  }
</script>
