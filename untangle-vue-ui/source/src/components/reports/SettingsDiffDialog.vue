<template>
  <u-dialog
    :show-dialog="value"
    :title="dialogTitle"
    :buttons="closeButton"
    width="90%"
    @close-dialog="$emit('input', false)"
  >
    <!-- Loading overlay — replaces UDialogComplex's :show-progress prop -->
    <v-overlay v-if="loading" absolute color="rgba(255,255,255,0.66)" opacity="1" class="text-center">
      <v-progress-circular indeterminate size="32" color="aristaMediumBlue" />
    </v-overlay>

    <!-- Error state -->
    <div v-if="errorMessage" class="d-flex align-center justify-center py-4">
      <v-alert type="warning" outlined max-width="500" class="ma-0">
        {{ errorMessage }}
      </v-alert>
    </div>

    <div v-else style="height: 60vh" class="d-flex">
      <code-diff
        language="json"
        :old-string="prevString"
        :new-string="currString"
        output-format="side-by-side"
        class="ma-0"
      />
    </div>
  </u-dialog>
</template>

<script>
  import { UDialog } from 'vuntangle'
  import { VAlert, VOverlay, VProgressCircular } from 'vuetify/lib'
  import { CodeDiff } from 'v-code-diff'
  import Rpc from '@/util/Rpc'
  import Util from '@/util/setupUtil'

  export default {
    name: 'SettingsDiffDialog',

    components: { UDialog, VAlert, VOverlay, VProgressCircular, CodeDiff },

    props: {
      // v-model — controls dialog open/close
      value: { type: Boolean, default: false },
      // Full settings_file path from the settings_changes row
      fileName: { type: String, default: '' },
    },

    data() {
      return {
        loading: false,
        errorMessage: '',
        prevString: '',
        currString: '',
      }
    },

    computed: {
      // Single Close button passed to UDialog's buttons array — removes the default OK button
      closeButton() {
        return [{ name: this.$t('close'), handler: 'close-dialog' }]
      },

      // Title shows the stripped file name for context
      dialogTitle() {
        const stripped = this.fileName.replace(/^.*\/settings\//, '').replace(/^.*\/conf\//, '')
        return stripped ? `${this.$t('settings_difference')} — ${stripped}` : this.$t('settings_difference')
      },
    },

    watch: {
      // Trigger diff fetch when dialog opens with a fileName
      value(open) {
        if (open && this.fileName) {
          this.fetchDiff()
        } else if (!open) {
          this.reset()
        }
      },
    },

    methods: {
      reset() {
        this.prevString = ''
        this.currString = ''
        this.errorMessage = ''
        this.loading = false
      },

      async fetchDiff() {
        this.reset()
        this.loading = true
        try {
          const result = await Rpc.asyncData('rpc.settingsManager.getDiff', this.fileName)
          const { prevString, currString } = this.buildFileStrings(result || '')
          this.prevString = prevString
          this.currString = currString
        } catch (err) {
          const msg = err?.message || ''
          if (msg.includes('Could not find an earlier file')) {
            this.errorMessage = this.$t('settings_no_previous_version')
          } else if (msg.includes('too big to compare')) {
            this.errorMessage = this.$t('settings_too_large_to_compare')
          } else {
            Util.handleException(err)
            this.errorMessage = this.$t('error')
          }
        } finally {
          this.loading = false
        }
      },

      /**
       * Reconstructs both file content strings from the raw output of:
       *   diff -y -W1024 -t <previous> <current>
       *
       * Each line: chars 0–510 = previous content, char 511 = separator, chars 512+ = current content
       * Separator: ' '=unchanged  '|'=changed  '<'=removed  '>'=added
       */
      buildFileStrings(raw) {
        const prevLines = []
        const currLines = []

        for (const line of raw.split('\n')) {
          if (!line) continue

          const prevMarker = line.substring(0, 1)
          let prev = line.substring(1, 511)
          const sep = line.substring(511, 512)
          const curr = line.substring(512)

          if (prevMarker !== '<' && prevMarker !== '>') {
            prev = prevMarker + prev
          }

          if (sep === '|') {
            prevLines.push(prev.trimEnd())
            currLines.push(curr.trimEnd())
          } else if (sep === '<') {
            prevLines.push(prev.trimEnd())
          } else if (sep === '>') {
            currLines.push(curr.trimEnd())
          } else {
            prevLines.push(prev.trimEnd())
            currLines.push(prev.trimEnd())
          }
        }

        return { prevString: prevLines.join('\n'), currString: currLines.join('\n') }
      },
    },
  }
</script>
