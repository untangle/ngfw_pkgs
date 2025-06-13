<template>
  <v-simple-checkbox
    :disabled="params.disabled"
    :value="params.value"
    :ripple="false"
    color="primary"
    data-testid="enabled-checkbox"
    @input="checkedHandler"
  />
</template>

<script>
  import Vue from 'vue'
  import { VSimpleCheckbox } from 'vuetify/lib'

  export default Vue.extend({
    components: { VSimpleCheckbox },
    methods: {
      /**
       * Handle checkbox event
       * @param event - true/false
       */
      checkedHandler(event) {
        const colId = this.params.column.colId
        this.params.node.setDataValue(colId, event)
      },
    },
  })
</script>
