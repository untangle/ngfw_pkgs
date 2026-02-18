<template>
  <v-container fluid class="d-flex justify-center pt-12">
    <request-quarantine-digest :company-name="companyName" @request-quarantine-digest="handleQuarantineDigestRequest" />
  </v-container>
</template>

<script>
  import { RequestQuarantineDigest } from 'vuntangle'
  import Util from '../../../util/util'

  /**
   * Wrapper component for quarantine digest request.
   * Handles the API call to request quarantine digest email.
   */
  export default {
    name: 'QuarantineDigestRequest',
    components: { RequestQuarantineDigest },
    computed: {
      companyName() {
        // Get company name from query parameter if provided (even if empty string)
        const queryParam = this.$route.query.companyName
        if (queryParam !== undefined) {
          return queryParam || ''
        }
        return ''
      },
    },
    methods: {
      /**
       * Handle quarantine digest request
       * @param {object} payload - Contains email and callback
       * @param {string} payload.email - The email address to request digest for
       * @param {function} payload.cb - The callback function (receives result boolean or error)
       */
      handleQuarantineDigestRequest({ email, cb }) {
        try {
          const quarantineRpc = Util.getQuarantineRpc()

          // Call requestDigest following ExtJS pattern: requestDigest(callback, email)
          quarantineRpc.requestDigest((result, ex) => {
            if (ex) {
              Util.handleException(ex)
              cb(null, ex)
              return
            }

            // result is boolean:
            // true = successfully sent digest
            // false = quarantine doesn't exist for this email
            cb(result)
          }, email)
        } catch (err) {
          Util.handleException(err)
          cb(null, err)
        }
      },
    },
  }
</script>
