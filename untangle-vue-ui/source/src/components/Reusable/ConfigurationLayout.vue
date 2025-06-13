<template>
  <v-container fluid class="shared-cmp d-flex flex-column flex-grow-1 pa-2">
    <div class="d-flex align-center mb-2">
      <h1 class="headline">{{ title }}</h1>
      <v-spacer />
      <u-btn :min-width="null" :disabled="!isDirty" @click="onSave">{{ $t('save') }}</u-btn>
    </div>
    <slot />
  </v-container>
</template>

<script>
  export default {
    name: 'ConfigurationLayout',
    props: {
      title: String,
      isDirty: Boolean,
      onSave: Function,
      validate: Function,
    },
  }
</script>
