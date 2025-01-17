<template>
  <v-card width="650" class="mx-auto mt-4" flat>
    <h2 class="font-weight-light">{{ `Configure the Server` }}</h2>
    <br />
    <br />
    <ValidationObserver v-slot="{ passes }">
      <div class="d-flex">
        <div class="custom-margin">
          <h2 class="font-weight-light">{{ `Admin Account` }}</h2>
          <br />
          <label>Choose a password for the admin account</label>
          <br />
          <label>Password:</label>
          <ValidationProvider v-slot="{ errors }" name="password" rules="required">
            <u-text-field
              :type="passwordReveal ? 'text' : 'password'"
              :error-messages="errors"
              @click:append="passwordReveal = !passwordReveal"
            />
          </ValidationProvider>
          <label>Confirm Password:</label>
          <ValidationProvider v-slot="{ errors }" name="confirmPassword" rules="required">
            <u-text-field
              :type="passwordReveal ? 'text' : 'password'"
              :error-messages="errors"
              @click:append="passwordReveal = !passwordReveal"
            />
          </ValidationProvider>
          <label>Adding Email:</label>
          <ValidationProvider>
            <u-text-field />
          </ValidationProvider>
        </div>
        <br />
        <div>
          <h2 class="font-weight-light">{{ `Install Type` }}</h2>
          <br />
          <label>Install type determines the optimal default settings for this deployment.</label>
          <br />
          <label>Choose Type:</label>
          <ValidationProvider v-slot="{ errors }" name="chooseType" rules="required">
            <u-text-field list="chooseTypes" :error-messages="errors" />
            <datalist id="chooseTypes">
              <option value="Higher Education" />
              <option value="School" />
            </datalist>
          </ValidationProvider>
          <h2 class="font-weight-light">{{ `Timezone` }}</h2>
          <ValidationProvider v-slot="{ errors }" rules="required">
            <u-text-field list="timezones" />
            <datalist id="timezones">
              <option value="(~UTC+00.00) Etc/UTC" />
              <option value="PST" />
              <option value="EST" />
              <option value="CET" />
            </datalist>
            <span class="text-danger">{{ errors[0] }}</span>
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
    margin-right: 20px;
  }
</style>
<script>
  export default {
    data: () => ({
      password: '',
      confirmPassword: '',
      chooseType: '',
    }),
    error: false,
    passwordReveal: false,

    methods: {
      async onContinue() {},
      validatePassword(e) {
        console.log(this)
        e.preventDefault()
      },
    },
  }
</script>
