<template>
  <v-card outlined class="pa-1 my-1 d-flex align-center" :disabled="fullTunnel" style="cursor: pointer" height="44">
    <span v-if="!isFullTunnelItem && fullTunnel" class="py-1 mx-2 font-weight-bold aristaLightGray--text">
      {{ networkWithPrefix }}
    </span>
    <span v-else class="py-1 mx-2 font-weight-bold"> {{ networkWithPrefix }} </span>
    <v-spacer />
    <template v-if="!isFullTunnelItem">
      <v-btn icon @click="onEdit(index)"> <v-icon> mdi-pencil </v-icon></v-btn>
      <v-btn icon @click="onDelete(index)"> <v-icon color="red"> mdi-delete </v-icon></v-btn>
    </template>
  </v-card>
</template>

<script>
  import cloneDeep from 'lodash/cloneDeep'
  import IpsecNetworkDialog from './IpsecNetworkDialog.vue'

  export default {
    props: {
      ipsec: { type: Object, default: () => null },
      item: { type: Object, default: () => null },
      index: { type: Number, default: null },
      fullTunnel: { type: Boolean, default: false },
      type: { type: String, default: null },
    },

    computed: {
      isFullTunnelItem() {
        return this.item.network === '0.0.0.0' && this.item.prefix === 0
      },
      networkWithPrefix() {
        return `${this.item.network}/${this.item.prefix}`
      },
    },

    methods: {
      /**
       * Shows an editing dialog for network
       * @param {Number} index - the index of the network being edited (-1 means new)
       */
      onEdit(index) {
        this.$vuntangle.dialog.show({
          title: index === -1 ? this.$t(`add_${this.type}_network`) : this.$t(`edit_${this.type}_network`),
          component: IpsecNetworkDialog,
          width: 600,
          actionLabel: index === -1 ? this.$t('add') : this.$t('update'),
          componentProps: {
            type: this.type, // type: 'local' or 'remote'
            ipsec: this.ipsec,
            index,
          },
        })
      },

      /**
       * Removes a network from list
       * @param {Number} index - the index of the network to be removed
       */
      onDelete(index) {
        const networksClone = cloneDeep(this.ipsec[this.type].networks)
        networksClone.splice(index, 1)
        this.$set(this.ipsec[this.type], 'networks', networksClone)
      },
    },
  }
</script>
