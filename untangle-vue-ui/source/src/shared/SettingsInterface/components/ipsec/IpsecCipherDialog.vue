<!--
  dialog component for editing IPsec proposals (cipher suites)
-->
<template>
  <div>
    <ValidationObserver ref="obs">
      <!-- proposal encryption -->
      <ValidationProvider v-slot="{ errors }" rules="required">
        <u-select v-model="entry.encryption" :label="$t('encryption')" :items="encryptionOptions" class="my-4">
          <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
        </u-select>
      </ValidationProvider>

      <!-- proposal hash -->
      <ValidationProvider v-slot="{ errors }" rules="required">
        <u-select v-model="entry.hash" :label="$t('integrity_algorithm_hash')" :items="hashOptions" class="my-4">
          <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
        </u-select>
      </ValidationProvider>

      <!-- proposal DH group -->
      <ValidationProvider v-slot="{ errors }" rules="required">
        <u-select v-model="entry.group" :label="$t('key_group')" :items="groupOptions" class="my-4">
          <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
        </u-select>
      </ValidationProvider>
    </ValidationObserver>
  </div>
</template>
<script>
  import cloneDeep from 'lodash/cloneDeep'
  import defaults from '../../defaults'

  export default {
    props: {
      phase: { type: String, default: '' }, // 'phase1' or 'phase2'
      list: { type: Array, default: () => [] },
      index: { type: Number, default: -1 },
    },
    data: () => ({
      entry: { encryption: '', hash: '', group: '' },

      // options for the select boxes
      encryptionOptions: defaults.ipSecEncryptionOptions,
      hashOptions: defaults.ipSecHashOptions,
      groupOptions: defaults.ipSecGroupOptions,
    }),

    created() {
      if (this.index >= 0) {
        // populate entry when editing a proposal
        this.entry = cloneDeep(this.list[this.index])
      }
    },

    methods: {
      async action() {
        const isValid = await this.$refs.obs.validate()
        if (!isValid) return

        // updates or adds proposal to the list
        this.$set(this.list, this.index > -1 ? this.index : this.list.length, this.entry)
        this.$emit('close')
      },
    },
  }
</script>
