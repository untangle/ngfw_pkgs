<template>
  <div>
    <v-row>
      <v-col>
        <!-- v6AssignHint -->
        <ValidationProvider v-slot="{ errors }" rules="required|numeric">
          <u-text-field v-model="intf.v6AssignHint" :label="$t('assign_hint')" :error-messages="errors">
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
      <v-col>
        <!-- v6AssignPrefix -->
        <ValidationProvider v-slot="{ errors }" rules="required|min_value:1|max_value:128">
          <u-text-field
            v-model.number="intf.v6AssignPrefix"
            :label="$t('assign_prefix')"
            type="number"
            placeholder="1-128"
            :error-messages="errors"
          >
            <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
          </u-text-field>
        </ValidationProvider>
      </v-col>
    </v-row>
  </div>
</template>
<script>
  export default {
    inject: ['$intf'],
    computed: {
      intf: ({ $intf }) => $intf(),
    },
  }
</script>
