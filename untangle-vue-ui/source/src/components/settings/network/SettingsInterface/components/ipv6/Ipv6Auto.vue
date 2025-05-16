<template>
  <div v-if="intf.v6ConfigType === CONFIG_TYPE.AUTO">
    <v-row>
      <v-col v-if="!isDisabledv6 && !isAutov6 && !intf.isWan">
        <!-- Auto (SLAAC/RA) -->
        <v-checkbox v-model="intf.raEnabled" :label="$t('send_router_advertisements')" hide-details />
        <span v-if="showRouterWarning" class="mx-2">
          <v-avatar size="12" class="bg-orange-darken-2 mx-2"></v-avatar>
          <span class="text-body-2 text-warning">{{ $t('SLAAC only works with /64 subnets.') }}</span>
        </span>
      </v-col>
    </v-row>
  </div>
</template>
<script>
  import { CONFIG_TYPE } from '../constants'
  import mixin from '../mixin'
  export default {
    mixins: [mixin],
    inject: ['$intf'],
    data() {
      return {
        CONFIG_TYPE,
      }
    },
    computed: {
      intf: ({ $intf }) => $intf(),
    },
  }
</script>
