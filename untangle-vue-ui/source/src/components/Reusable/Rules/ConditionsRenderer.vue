<template>
  <div style="line-height: 1.4" class="my-1" v-html="render" />
</template>

<script>
  import Vue from 'vue'

  export default Vue.extend({
    computed: {
      items: ({ params }) => params.value,
      render: ({ items, $i18n }) =>
        items
          .map(item => `<span class="pm-condition-border">${item.type} ${item.op} ${item.value}</span>`)
          .join(` <strong>${$i18n.t('and').toUpperCase()}</strong> `),
    },
  })
</script>
