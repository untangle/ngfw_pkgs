<!--
  component for editing phase 1 and phase 2 proposals for IPsec service/tunnel
-->
<template>
  <div>
    <v-row class="mt-4">
      <v-col>
        <p class="font-weight-bold mb-2">{{ $t('cipher_phase1_title') }}</p>

        <u-alert v-if="!ipsec.phase1.length" class="mb-1">
          <span>{{ $t('no_ciphers_defined') }}</span>
        </u-alert>

        <draggable v-model="ipsec.phase1" v-bind="dragOptions" @start="drag = true" @end="drag = false">
          <transition-group>
            <ipsec-cipher-item
              v-for="(item, index) in ipsec.phase1"
              :key="`${item.encryption}-${item.hash}-${item.group}`"
              :ipsec="ipsec"
              :index="index"
              :item="item"
              phase="phase1"
            />
          </transition-group>
        </draggable>

        <div class="d-flex align-center">
          <span v-if="ipsec.phase1.length > 1" class="caption grey--text">
            {{ $t('ipsec_ciphers_drag') }}
          </span>
          <v-spacer />
          <u-btn class="my-2" @click="onEdit(-1, 'phase1')">{{ $t('add_proposal') }}</u-btn>
        </div>

        <!-- phase1 lifetime -->
        <p class="font-weight-bold mb-2 mt-4">
          {{ $t('phase1_lifetime') }}
          <v-tooltip right transition="none">
            <template #activator="{ on, attrs }">
              <v-icon v-bind="attrs" v-on="on"> mdi-information </v-icon>
            </template>
            <span>{{ $t('phase1_lifetime_hint') }}</span>
          </v-tooltip>
        </p>
        <div class="d-flex align-center">
          <ValidationProvider v-slot="{ errors }" rules="required|min_value:3600|max_value:86400">
            <u-text-field
              v-model="ipsec.phase1Lifetime"
              :label="$t('lifetime')"
              type="number"
              :error-messages="errors"
              :suffix="$t('seconds')"
              @keydown="preventExtraChars"
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </div>
      </v-col>

      <v-divider vertical class="mx-8" />

      <v-col>
        <p class="font-weight-bold mb-2">{{ $t('cipher_phase2_title') }}</p>

        <u-alert v-if="!ipsec.phase2.length" class="mb-1">
          <span>{{ $t('no_ciphers_defined') }}</span>
        </u-alert>

        <draggable v-model="ipsec.phase2" v-bind="dragOptions" @start="drag = true" @end="drag = false">
          <transition-group>
            <ipsec-cipher-item
              v-for="(item, index) in ipsec.phase2"
              :key="`${item.encryption}-${item.hash}-${item.group}`"
              :ipsec="ipsec"
              :index="index"
              :item="item"
              phase="phase2"
            />
          </transition-group>
        </draggable>

        <div class="d-flex align-center">
          <span v-if="ipsec.phase2.length > 1" class="caption grey--text">
            {{ $t('ipsec_ciphers_drag') }}
          </span>
          <v-spacer />
          <u-btn class="my-2" @click="onEdit(-1, 'phase2')">{{ $t('add_proposal') }}</u-btn>
        </div>

        <!-- phase2 lifetime -->
        <p class="font-weight-bold mb-2 mt-4">
          {{ $t('phase2_lifetime') }}
          <v-tooltip right transition="none">
            <template #activator="{ on, attrs }">
              <v-icon v-bind="attrs" v-on="on"> mdi-information </v-icon>
            </template>
            <span>{{ $t('phase2_lifetime_hint') }}</span>
          </v-tooltip>
        </p>
        <div class="d-flex align-center">
          <ValidationProvider v-slot="{ errors }" rules="required|min_value:3600|max_value:86400">
            <u-text-field
              v-model="ipsec.phase2Lifetime"
              :label="$t('lifetime')"
              type="number"
              :error-messages="errors"
              :suffix="$t('seconds')"
              @keydown="preventExtraChars"
            >
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </div>
      </v-col>
    </v-row>
  </div>
</template>

<script>
  import draggable from 'vuedraggable'
  import IpsecCipherDialog from './IpsecCipherDialog.vue'
  import IpsecCipherItem from './IpsecCipherItem.vue'

  export default {
    components: { draggable, IpsecCipherItem },
    inject: ['$intf'],
    data() {
      return {
        drag: false,
      }
    },

    computed: {
      ipsec: ({ $intf }) => $intf().ipsec,

      dragOptions() {
        return {
          animation: 200,
          group: 'description',
          disabled: false,
          ghostClass: 'ghost',
        }
      },
    },

    methods: {
      /**
       * Shows an editing dialog for proposal
       * @param {Number} index - the index of the proposal being edited (-1 means new)
       * @param {String} phase - for which phase (phase1 or phase2)
       */
      onEdit(index, phase) {
        this.$vuntangle.dialog.show({
          title: index === -1 ? this.$t(`add_${phase}_proposal`) : this.$t(`edit_${phase}_proposal`),
          component: IpsecCipherDialog,
          width: 400,
          actionLabel: index === -1 ? this.$t('add') : this.$t('update'),
          componentProps: {
            phase,
            list: this.ipsec[phase],
            index,
          },
        })
      },

      /**
       * Removes a proposal from list
       * @param {Number} index - the index of the proposal to be removed
       * @param {String} phase - from which phase (phase1 or phase2)
       */
      onDelete(index, phase) {
        this.ipsec[phase].splice(index, 1)
      },

      /**
       * Method used to re-arrange records after manual sorting via drag
       * When moving records, their order is not reflected in the initial row data
       * A drag end hook was added to handle this order by iterating internal grid nodes
       */
      onRowDragEnd(phase) {
        const newOrder = []
        const grid = this.$refs[phase]
        grid.gridOptions.api.forEachNode(row => {
          newOrder.push(row.data)
        })
        this.ipsec[phase] = newOrder
      },
      /**
       * Prevents entering "e", "-" and "." chars in the lifetime number field
       * @param {Object} e - keydown event
       */
      preventExtraChars(e) {
        if (e.keyCode === 69 || e.keyCode === 189 || e.keyCode === 190) {
          e.preventDefault()
        }
      },
    },
  }
</script>
