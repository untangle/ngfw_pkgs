<template>
  <div>
    <v-form ref="form">
      <v-select
        v-model="importMode"
        :items="importModes"
        item-text="text"
        item-value="value"
        :label="$vuntangle.$t('how_to_process')"
        outlined
        dense
        class="mb-4"
      />
      <v-file-input v-model="file" outlined dense label="Widget File" :rules="fileRules" @change="fileHandler" />
    </v-form>
    <u-alert v-if="importError" error class="mt-4 mb-0">{{ importError }}</u-alert>
  </div>
</template>

<script>
  import { VFileInput, VForm, VSelect } from 'vuetify/lib'
  import { UAlert } from 'vuntangle'

  export default {
    name: 'DashboardImportDialog',
    components: { UAlert, VFileInput, VForm, VSelect },
    data() {
      return {
        file: null,
        importMode: 'replace',
        importError: null,
        importModes: [
          { text: 'Replace current widgets', value: 'replace' },
          { text: 'Prepend to current widgets', value: 'prepend' },
          { text: 'Append to current widgets', value: 'append' },
        ],
      }
    },
    computed: {
      fileRules() {
        return [
          value => !!value || this.$vuntangle.$t('required'),
          value => !value || value.name.endsWith('.json') || this.$vuntangle.$t('invalid_file_type'),
        ]
      },
    },
    methods: {
      fileHandler(file) {
        if (!file) return
        this.file = file
        this.importError = null
      },
      async action() {
        const isValid = await this.$refs.form.validate()
        if (!isValid || !this.file) return

        if (!this.file.name.endsWith('.json')) {
          this.importError = this.$vuntangle.$t('invalid_file_type')
          return
        }

        this.$emit('import', { file: this.file, importMode: this.importMode })
        this.$emit('close')
      },
    },
  }
</script>
