<template>
  <v-card class="pa-3 fill-height d-flex flex-column">
    <div class="d-flex justify-space-between align-center mb-2">
      <h1 class="headline">{{ $vuntangle?.$t(title) || title }}</h1>
      <u-btn class="ma-2 pa-1" @click="$emit('refresh')">
        {{ $vuntangle?.$t('Refresh') || 'Refresh' }}
      </u-btn>
    </div>

    <v-data-table
      :headers="headers"
      :items="items"
      :search="searchable ? search : ''"
      :loading="loading"
      :items-per-page="itemsPerPage"
      :dense="dense"
      disable-pagination
      hide-default-footer
    >
      <template v-if="$slots.item" #item="slotProps">
        <slot name="item" v-bind="slotProps" />
      </template>
    </v-data-table>
  </v-card>
</template>

<script>
  export default {
    name: 'InterfacesTable',
    props: {
      title: String,
      headers: Array,
      items: Array,
      searchable: {
        type: Boolean,
        default: false,
      },
      itemsPerPage: {
        type: Number,
        default: 1000,
      },
      dense: {
        type: Boolean,
        default: false,
      },
      loading: {
        type: Boolean,
        default: false,
      },
    },
    data() {
      return {
        search: '',
      }
    },
  }
</script>
