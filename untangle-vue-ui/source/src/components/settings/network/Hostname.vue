<template>
  <v-container class="d-flex flex-column pa-2" fluid>
    <div style="border: 1px solid #ccc; border-radius: 8px; padding: 16px">
      <v-row>
        <v-col><v-divider /></v-col>
        <span class="mx-2 font-weight-medium text-grey">Hostname</span>
        <v-col><v-divider /></v-col>
      </v-row>
      <v-row dense>
        <v-col cols="4">
          <span>Hostname : </span>
          <ValidationProvider v-slot="{ errors }">
            <u-text-field :label="$t('Hostname')" :error-messages="errors">
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
        <v-col cols="6" class="pt-8">
          <span class="pa-2">
            <span class="text-grey ma-2">(eg: gateway)</span>
          </span>
        </v-col>
      </v-row>
      <v-row dense>
        <v-col cols="4">
          <span>Domain Name : </span>
          <ValidationProvider v-slot="{ errors }" :rules="{ required: true }">
            <u-text-field :label="$t('address')" :error-messages="errors">
              <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
            </u-text-field>
          </ValidationProvider>
        </v-col>
        <v-col cols="6" class="pt-8">
          <span class="pa-2">
            <span class="text-grey ma-2">(eg: example.com)</span>
          </span>
        </v-col>
      </v-row>
    </div>
  </v-container>
</template>
