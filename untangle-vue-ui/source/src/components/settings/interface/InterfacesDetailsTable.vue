<template>
  <v-card class="pa-3 fill-height d-flex flex-column">
    <div class="d-flex justify-space-between align-center mb-2">
      <h1 class="headline">{{ $vuntangle?.$t(title) || title }}</h1>
      <u-btn @click="$emit('refresh')">
        {{ $vuntangle?.$t('Refresh') || 'Refresh' }}
      </u-btn>
    </div>

    <v-data-table
      :headers="headers"
      :items="items"
      :search="searchable ? search : ''"
      :items-per-page="itemsPerPage"
      :dense="dense"
      disable-pagination
      hide-default-footer
    >
      <template v-if="loading" #body>
        <tr>
          <td :colspan="headers.length">
            <div class="d-flex flex-column align-center justify-center pa-6" style="height: 200px">
              <v-progress-circular :size="50" :width="4" color="primary" indeterminate />
              <div class="mt-2">{{ $t('Loading...') }}</div>
            </div>
          </td>
        </tr>
      </template>

      <template v-else-if="$slots.item" #item="slotProps">
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
