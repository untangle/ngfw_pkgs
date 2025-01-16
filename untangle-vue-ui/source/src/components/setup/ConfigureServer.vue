<template>
  <v-card width="350" class="mx-auto text-center mt-4" flat>
    <h2 class="font-weight-light">{{ `Configure the Server` }}</h2>
    <p>{{ $t('admin_account_choose_password') }}</p>
    <ValidationObserver v-slot="{ passes }">
      <ValidationProvider v-slot="{ errors }" vid="newPassword" :rules="{ required: passwordRequired, min: 4 }">
        <u-password v-model="newPassword" :label="$t('new_password')" :errors="errors" />
      </ValidationProvider>
      <br />
      <ValidationProvider
        v-slot="{ errors }"
        :rules="{ required: !!(passwordRequired || newPassword), confirmed: 'newPassword' }"
      >
        <u-password v-model="newPasswordConfirm" :label="$t('confirm_new_password')" :errors="errors" />
      </ValidationProvider>

      <br /><br />

      <h2 class="font-weight-light">{{ $t('time_zone') }}</h2>
      <ValidationProvider ref="tz" v-slot="{ errors }" rules="required">
        <v-autocomplete
          :value="tz.displayName"
          :items="timeZones"
          :label="$t('time_zone')"
          outlined
          dense
          hide-details
          return-object
          :error-messages="errors"
          @input="val => (tz = { displayName: val ? val.value : '', value: val ? val.openwrt : '' })"
        >
          <template v-if="errors.length" #append><u-errors-tooltip :errors="errors" /></template>
        </v-autocomplete>
      </ValidationProvider>
      <br />

      <u-btn :small="false" @click="passes(onContinue)">{{ $t('continue') }}</u-btn>
    </ValidationObserver>
  </v-card>
</template>
<script>
  import store from '@/store'

  export default {
    data: () => ({
      newPassword: null,
      newPasswordConfirm: null,
      tz: { ...store.getters['settings/timeZoneObject'] },
      loading: false,
    }),

    computed: {
      timeZones() {
        return this.$vuntangle.dates.timeZones.filter(timeZone => 'openwrt' in timeZone)
      },
      passwordRequired() {
        return this.$store.state.setup?.status?.step ? this.$store.state.setup?.status.step === 'system' : true
      },
    },
    methods: {
      async onContinue() {
        store.commit('SET_LOADER', true)

        // save admin account password if one was given
        let accountResponse = true
        if (this.newPassword) {
          const credentials = store.getters['settings/credentials']
          const account = credentials.find(account => account.username === 'admin')

          if (account) {
            // if admin account found, just update password
            account.passwordCleartext = this.newPassword
          } else {
            // else add the new `admin` account to the credentials
            credentials.push({
              username: 'admin',
              passwordCleartext: this.newPassword,
            })
          }
          accountResponse = await store.dispatch('settings/setAccounts', credentials)
        }

        // save timezone
        const tzResponse = await store.dispatch('settings/setTimezone', this.tz)

        // if saving account or timezone fails do not jump to the next step
        if (!accountResponse.success || !tzResponse.success) {
          store.commit('SET_LOADER', false)
          return
        }

        const nextStep = await store.dispatch('setup/setStatus', 'system')
        store.commit('SET_LOADER', false)
        if (nextStep) {
          this.$router.push(`/setup/${nextStep}`)
        }
      },
    },
  }
</script>
