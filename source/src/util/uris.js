import http from '@/plugins/http'

/**
 * return translated URI if found otherwise fallsback to the original URI
 * uses http instead of api, so it avoids displaying UI toast errors
 * @returns {string} - translated uri
 */
async function translate(uri) {
  let response
  try {
    response = await http.get(`/api/uri/geturiwithpath/uri=${uri}`)
  } catch (ex) {
    // return the initial uri passed to translation
    return uri
  }
  // return translated or original uri
  return response?.data || uri
}

const list = {
  feedback: 'https://aristamicroedge.featureupvote.com/',
  help: 'https://support.untangle.com/hc/en-us/categories/360001799354',
  articles: 'https://support.untangle.com/hc/en-us/articles',
  subscriptions: 'https://launchpad.edge.arista.com/organization/subscriptions',
  account: 'https://www.untangle.com/cmd/account',
  legal: 'https://edge.arista.com/legal',
  networks: 'https://launchpad.edge.arista.com/appliances/networks',
  privacyPolicy: 'https://www.arista.com/en/privacy-policy',
  dataProtectionAddendum: 'https://edge.arista.com/dpa/',
}

export default {
  list,
  translate,
}
