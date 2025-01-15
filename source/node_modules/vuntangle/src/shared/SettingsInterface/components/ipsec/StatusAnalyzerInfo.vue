<template>
  <div>
    <p class="font-weight-bold mb-4">{{ $t('status_analyzers') }}</p>
    <div v-if="statusAnalyzers.length">
      <div v-for="(item, index) in statusAnalyzers" :key="index">
        &bull; {{ item.name }} {{ !item.enabled ? ` (${$t('disabled')})` : '' }}
      </div>
    </div>
    <div v-else>
      <em>&bull; {{ $t('not_set') }}</em>
    </div>
    <u-btn class="mt-2" @click="$onManageStatusAnalyzers">{{ $t('manage') }}</u-btn>
  </div>
</template>
<script>
  export default {
    inject: ['$onManageStatusAnalyzers', '$pingAnalyzers'],
    props: {
      interfaceId: { type: Number, default: undefined },
    },
    computed: {
      pingAnalyzers: ({ $pingAnalyzers }) => $pingAnalyzers(),
      /**
       * Returns Status Analyzers associated with a given interface id
       * @param {*} param
       */
      statusAnalyzers: ({ interfaceId, pingAnalyzers }) => {
        if (!pingAnalyzers?.length || !interfaceId) return
        return pingAnalyzers.filter(item => item.interfaceIds.includes(interfaceId))
      },
    },
  }
</script>
