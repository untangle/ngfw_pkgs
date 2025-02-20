/**
 * A common file to define types for some of the objects, following JSDoc specs
 * It helps with better documenting function arguments and IDE code intellisense
 */

/**
 * @typedef  {Object} NetworkSettings
 * @property {DnsSettings} dnsSettings - the view id as defined in `constants`
 */

/**
 * @typedef  {Object} DnsSettings
 * @property {String} javaClass - the view id as defined in `constants`
 * @property {Object} localServers - the view category as defined in `constants`
 * @property {DnsStaticEntries} staticEntries - the view locale for it's name shown in navigations
 */

/**
 * @typedef  {Object} DnsStaticEntries
 * @property {String} javaClass - the view id as defined in `constants`
 * @property {DnsStaticEntry[]} list - the view category as defined in `constants`
 */

/**
 * @typedef  {Object} DnsStaticEntry
 * @property {String} javaClass - the view id as defined in `constants`
 * @property {Object} list - the view category as defined in `constants`
 */
