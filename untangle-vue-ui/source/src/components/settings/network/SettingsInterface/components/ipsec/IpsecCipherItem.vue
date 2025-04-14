<template>
  <v-card outlined class="pa-1 my-1 d-flex align-center" style="cursor: pointer" height="44">
    <pre> {{ fullCipher }} </pre>
    <v-spacer />
    <v-btn icon @click="onEdit(index)"> <v-icon> mdi-pencil </v-icon></v-btn>
    <v-btn v-if="ipsec[phase].length > 1" icon @click="onDelete(index)">
      <v-icon color="red"> mdi-delete </v-icon></v-btn
    >
  </v-card>
</template>

<script>
  import cloneDeep from 'lodash/cloneDeep'
  import IpsecCipherDialog from './IpsecCipherDialog.vue'

  export default {
    props: {
      ipsec: { type: Object, default: () => null },
      item: { type: Object, default: () => null },
      index: { type: Number, default: null },
      phase: { type: String, default: null },
    },

    computed: {
      fullCipher() {
        return `${this.item.encryption}-${this.item.hash}-${this.item.group}`
      },
    },

    methods: {
      /**
       * Shows an editing dialog for proposal
       * @param {Number} index - the index of the proposal being edited (-1 means new)
       */
      onEdit(index) {
        this.$vuntangle.dialog.show({
          title: index === -1 ? this.$t(`add_${this.phase}_proposal`) : this.$t(`edit_${this.phase}_proposal`),
          component: IpsecCipherDialog,
          width: 400,
          actionLabel: index === -1 ? this.$t('add') : this.$t('update'),
          componentProps: {
            phase: this.phase,
            list: this.ipsec[this.phase],
            index,
          },
        })
      },

      /**
       * Removes a proposal from list
       * @param {Number} index - the index of the proposal to be removed
       */
      onDelete(index) {
        const phaseClone = cloneDeep(this.ipsec[this.phase])
        phaseClone.splice(index, 1)
        this.$set(this.ipsec, this.phase, phaseClone)
      },
    },
  }
</script>
