<template>
  <table class="text-body-2">
    <tbody>
      <tr>
        <td class="px-2 text-left">{{ alert.message }}</td>
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
