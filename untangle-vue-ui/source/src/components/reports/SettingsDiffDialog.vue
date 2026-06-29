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

    <template v-else>
      <!-- Color legend -->
      <div class="d-flex align-center caption grey--text text--darken-1 mb-2" style="gap: 16px">
        <span class="d-flex align-center">
          <span class="diff-legend-swatch" style="background: #d9f5cb" />
          {{ $t('added') }}
        </span>
        <span class="d-flex align-center">
          <span class="diff-legend-swatch" style="background: #ffdfd9" />
          {{ $t('removed') }}
        </span>
        <span class="d-flex align-center">
          <span class="diff-legend-swatch" style="background: #ffff99" />
          {{ $t('changed') }}
        </span>
      </div>

      <!-- Diff grid — Line | Previous | Current columns.
           d-flex flex-column is required so UGrid's inner flex-grow-1 has a flex context
           and AG-Grid receives non-zero height from its parent. -->
      <div class="d-flex flex-column" style="height: 60vh">
        <u-grid
          id="settings-diff-grid"
          :column-defs="columnDefs"
          :row-data="diffRows"
          toolbar="hidden"
          :custom-grid-options="gridOptions"
          :custom-default-col-options="defaultColOptions"
        />
      </div>
    </template>
  </u-dialog>
</template>

<script>
  import { UDialog, UGrid } from 'vuntangle'
  import { VAlert, VOverlay, VProgressCircular } from 'vuetify/lib'
  import Rpc from '@/util/Rpc'
  import Util from '@/util/setupUtil'

  // Diff action codes
  const ACTION_ADDED = 1 // '>' line only in current  → green
  const ACTION_REMOVED = 2 // '<' line only in previous → red
  const ACTION_CHANGED = 3 // '|' line differs          → yellow

  // Row background colors
  const ROW_COLORS = {
    [ACTION_ADDED]: '#d9f5cb',
    [ACTION_REMOVED]: '#ffdfd9',
    [ACTION_CHANGED]: '#ffff99',
  }

  export default {
    name: 'SettingsDiffDialog',

    components: { UDialog, UGrid, VAlert, VOverlay, VProgressCircular },

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
        diffRows: [],
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

      columnDefs() {
        return [
          {
            field: 'line',
            headerName: this.$t('line'),
            width: 70,
            flex: 0,
            sortable: false,
            filter: false,
            suppressMenu: true,
          },
          {
            field: 'previous',
            headerName: this.$t('previous'),
            flex: 1,
            sortable: false,
            filter: false,
            suppressMenu: true,
          },
          {
            field: 'current',
            headerName: this.$t('current'),
            flex: 1,
            sortable: false,
            filter: false,
            suppressMenu: true,
          },
        ]
      },

      // Row color by action code
      gridOptions() {
        return {
          getRowStyle: ({ data }) => {
            const color = ROW_COLORS[data?.action]
            return color ? { background: color } : null
          },
        }
      },

      // Monospace font + white-space: pre for diff content.
      // AG-Grid renders text not HTML, so white-space: pre preserves indentation.
      defaultColOptions() {
        return {
          cellStyle: { fontFamily: 'monospace', fontSize: '12px', whiteSpace: 'pre' },
        }
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
        this.diffRows = []
        this.errorMessage = ''
        this.loading = false
      },

      async fetchDiff() {
        this.reset()
        this.loading = true
        try {
          // Full dot-path: rpc.settingsManager → getDiff method
          const result = await Rpc.asyncData('rpc.settingsManager.getDiff', this.fileName)
          this.diffRows = this.parseDiff(result || '')
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
       * Parses the raw output of: diff -y -W1024 -t <previous> <current>
       *
       * Side-by-side format with -W1024:
       *   char 0:      part of previous content (unless '<' or '>')
       *   chars 1–510: rest of previous content (510 chars)
       *   char 511:    separator: ' '=unchanged | '|'=changed | '<'=removed | '>'=added
       *   chars 512+:  current content
       */
      parseDiff(raw) {
        const rows = []
        const lines = raw.split('\n')

        for (let i = 0; i < lines.length; i++) {
          const line = lines[i]
          if (!line) continue

          const prevMarker = line.substring(0, 1)
          let prev = line.substring(1, 511)
          const sep = line.substring(511, 512)
          let curr = line.substring(512)

          // If char 0 is not a diff side-marker, it is part of previous content
          if (prevMarker !== '<' && prevMarker !== '>') {
            prev = prevMarker + prev
          }

          let action
          if (sep === '|') {
            action = ACTION_CHANGED
          } else if (sep === '<') {
            action = ACTION_REMOVED
          } else if (sep === '>') {
            action = ACTION_ADDED
          } else {
            // Separator char belongs to current content (unchanged line)
            curr = sep + curr
            action = 0
          }

          rows.push({
            line: i + 1,
            previous: prev.trimEnd(),
            current: curr.trimEnd(),
            action,
          })
        }

        return rows
      },
    },
  }
</script>

<style scoped>
  .diff-legend-swatch {
    display: inline-block;
    width: 12px;
    height: 12px;
    border-radius: 2px;
    margin-right: 4px;
    border: 1px solid rgba(0, 0, 0, 0.15);
  }
</style>
