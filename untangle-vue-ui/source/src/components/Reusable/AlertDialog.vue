<!-- <template>
  <table class="text-body-2">
    <tbody>
      <template>
        <tr>
          <td></td>
          <td class="font-weight-bold pt-4">{{ $t('details') }}</td>
        </tr>
        <tr v-for="(value, key) in details" :key="key">
          <td class="px-2 text-right">{{ key }}:</td>
          <td>{{ value }}</td>
        </tr>
      </template>
    </tbody>
  </table>
</template>

<script>
  export default {
    props: {
      alert: {
        type: Object,
        required: true,
      },
    },
    computed: {
      details: ({ alert }) => {
        let details = null
        try {
          details = JSON.parse(atob(alert.data))
        } catch (err) {
          details = {} // Return empty object if there’s an error
        }
        return details
      },
    },
    mounted() {
      console.log('alert', alert)
    },
  }
</script> -->

<template>
  <table class="text-body-2">
    <tbody>
      <tr>
        <td class="px-2 text-right">{{ alert.message }}</td>
      </tr>
    </tbody>
  </table>
</template>

<script>
  export default {
    props: {
      alert: {
        type: Object,
        required: true,
      },
    },
  }
</script>
