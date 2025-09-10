<template>
  <Troubleshooting :result="result" @run-test="onRunTest" />
</template>
<script>
  import { Troubleshooting } from 'vuntangle'
  import Util from '@/util/setupUtil'

  export default {
    components: { Troubleshooting },
    mixins: [],

    provide() {
      return {
        $remoteData: () => ({
          interfaceOptions: this.interfaceOptions,
          dnsTestHost: this.dnsTestHost,
          tcpTestHost: this.tcpTestHost,
        }),
      }
    },

    data: () => ({
      result: '',
    }),

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
            this.readOutput(resultReader, text, test)
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
       */
      readOutput(resultReader, text, test) {
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
              self.readOutput(resultReader, text, test)
            }, 1000)
          } else {
            test.isRunning = false
            text.push(new Date().toString() + ' - Test Completed')
            text.push('\n\n--------------------------------------------------------\n\n')
          }

          result = text.join('')
          test.output = result
        })
      },
    },
  }
</script>
