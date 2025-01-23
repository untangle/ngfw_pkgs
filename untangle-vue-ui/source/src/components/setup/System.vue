<template>
  <v-card width="650" class="mx-auto mt-4" flat>
    <h2 class="font-weight-light faint-color text-h4">{{ `Configure the Server` }}</h2>
    <br />
    <br />
    <ValidationObserver v-slot="{ passes }">
      <div class="d-flex">
        <div class="custom-margin">
          <h2 class="font-weight-light">{{ `Admin Account` }}</h2>
          <br />
          <label class="font-weight-light faint-color">Choose a password for the admin account</label>
          <br />
          <label>Password:</label>
          <ValidationProvider v-slot="{ errors }" vid="newPassword" :rules="{ required: passwordRequired, min: 3 }">
            <u-password v-model="newPassword" :errors="errors" />
          </ValidationProvider>
          <br />
          <label>Confirm Password:</label>
          <ValidationProvider
            v-slot="{ errors }"
            name="confirmPassword"
            :rules="{ required: !!(passwordRequired || newPassword), confirmed: 'newPassword' }"
          >
            <u-password v-model="newPasswordConfirm" :errors="errors" />
          </ValidationProvider>
          <br />
          <label>Adding Email:</label>
          <ValidationProvider>
            <u-text-field />
          </ValidationProvider>
          <label class="font-weight-light faint-color">Administrators receive email alerts and report summaries</label>
        </div>
        <br />
        <div>
          <h2 class="font-weight-light">{{ `Install Type` }}</h2>
          <br />
          <label class="font-weight-light faint-color"
            >Install type determines the optimal default settings for this deployment.</label
          >
          <br />
          <label>Choose Type:</label>
          <ValidationProvider v-slot="{ errors }" rules="required">
            <v-autocomplete
              v-model="selectedType"
              :items="typeOptions"
              outlined
              dense
              hide-details
              return-object
              :error-messages="errors"
              placeholder="Select Type"
            >
              <template v-if="errors.length" #append>
                <u-errors-tooltip :errors="errors" />
              </template>
            </v-autocomplete>
          </ValidationProvider>
          <h2 class="font-weight-light">{{ `Timezone` }}</h2>
          <ValidationProvider ref="tz" v-slot="{ errors }" rules="required">
            <v-autocomplete
              :value="tz.displayName"
              :items="timeZones"
              outlined
              dense
              hide-details
              return-object
              :error-messages="errors"
              @input="val => (tz = { displayName: val ? val.value : '', value: val ? val.openwrt : '' })"
            >
            </v-autocomplete>
          </ValidationProvider>
        </div>
      </div>

      <br />

      <u-btn :small="false" @click="passes(onContinue)">{{ `Network Cards` }}</u-btn>
    </ValidationObserver>
  </v-card>
</template>
<style scoped>
  .custom-margin {
    margin-right: 80px;
  }
  .faint-color {
    color: rgba(0, 0, 0, 0.5); /* Adjust the color and opacity */
  }
</style>
<script>
  import store from '@/store'
  export default {
    data: () => ({
      newPassword: null,
      newPasswordConfirm: null,
      tz: { ...store.getters['settings/timeZoneObject'] },
      loading: false,
      chooseType: '',
      selectedType: '',
      typeOptions: [
        'School',
        'Higher Education',
        'State & Local Government',
        'Federal Government',
        'Nonprofit',
        'Hospitality & Retail',
        'Healthcare',
        'Banking & Financial',
        'Home',
        'Student',
        'Other',
      ],
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
