<template>
  <div>
    <p class="font-weight-bold mt-6 mb-2">{{ $t('vrrp_tracking') }}</p>
    <em v-if="!list || !list.length" class="mr-2">{{ $t('no_interface_trackers') }}</em>
    <v-chip v-for="(item, idx) in list" :key="idx" class="mr-1 mb-1" small close @click:close="onRemoveObject(idx)">
      {{ mapNameToDisplayName(item.name) }} / {{ item.decrement }}
    </v-chip>
    <v-chip v-if="!adding" class="mb-1" small color="primary" @click="adding = true">{{ $t('attach') }}</v-chip>

    <ValidationObserver v-slot="{ passes }" tag="div">
      <v-row v-if="adding" no-gutters class="mt-2">
        <v-col class="grow">
          <!-- tracked object -->
          <ValidationProvider v-slot="{ errors }" rules="required">
            <u-select
              v-model="tracked.name"
              :items="trackers"
              item-text="displayName"
              item-value="name"
              :label="$t('interface_tracker')"
              :error-messages="errors"
              class="mr-2"
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
              <template #no-data>
                <div class="d-flex align-center pa-4 justify-center">
                  <span class="caption">{{ $t('no_data') }} </span>
                </div>
              </template>
            </u-select>
          </ValidationProvider>
        </v-col>
        <v-col class="grow">
          <!-- decrement -->
          <ValidationProvider v-slot="{ errors }" rules="required|numeric|integer|min_value:1|max_value:254">
            <u-text-field
              v-model.number="tracked.decrement"
              type="number"
              :label="$t('decrement')"
              :error-messages="errors"
              :hint="$t('vrrp_decremnet_hint')"
              :hide-details="false"
              persistent-hint
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
        <v-col class="shrink">
          <u-btn icon :small="false" :min-width="null" class="primary mx-4" @click="passes(onAddObject)">
            <v-icon color="white">mdi-check</v-icon>
          </u-btn>
        </v-col>
        <v-col class="shrink">
          <u-btn icon :small="false" :min-width="null" @click="adding = false"><v-icon>mdi-close</v-icon></u-btn>
        </v-col>
      </v-row>
    </ValidationObserver>
  </div>
</template>
<script>
  import { VChip, VRow, VCol, VIcon } from 'vuetify/lib'
  import cloneDeep from 'lodash/cloneDeep'

  export default {
    components: { VChip, VRow, VCol, VIcon },
    inject: ['$intf', '$interfaceTrackers'],

    data({ $intf }) {
      const intf = $intf()
      return {
        adding: false, // boolean telling to show the add fields
        tracked: {}, // model for new object
        list: cloneDeep(intf?.vrrptrack || []),
      }
    },
    computed: {
      intf: ({ $intf }) => $intf(),
      trackers: ({ $interfaceTrackers }) => $interfaceTrackers(),
    },
    watch: {
      adding(value) {
        if (!value) {
          // reset
          this.tracked = {}
        }
      },
      list: {
        deep: true,
        handler(newList) {
          // using $set to maintain reactivity in case vrrptrack don't exist in interface settings
          this.$set(this.intf, 'vrrptrack', newList)
        },
      },
    },
    methods: {
      onAddObject() {
        this.list.push(this.tracked)
        this.adding = false
      },
      onRemoveObject(index) {
        this.list.splice(index, 1)
      },
      mapNameToDisplayName(name) {
        return this.trackers.find(tracker => tracker.name === name)?.displayName
      },
    },
  }
</script>
