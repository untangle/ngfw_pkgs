export const VTypes = {
  // IPv4 Address Validation
  ip4Address: {
    regex:
      /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/,
    message: 'Invalid IPv4 Address.',
    validate(value) {
      return this.regex.test(value)
    },
  },

  // IPv6 Address Validation
  ip6Address: {
    regex: /([0-9a-fA-F]{1,4}:){7}([0-9a-fA-F]{1,4}|:)/,
    message: 'Invalid IPv6 Address.',
    validate(value) {
      return this.regex.test(value)
    },
  },

  // MAC Address Validation
  macAddress: {
    regex: /^[a-fA-F0-9]{2}:[a-fA-F0-9]{2}:[a-fA-F0-9]{2}:[a-fA-F0-9]{2}:[a-fA-F0-9]{2}:[a-fA-F0-9]{2}$/,
    message: 'Invalid MAC Address.',
    validate(value) {
      return this.regex.test(value)
    },
  },

  // CIDR Address Validation (e.g., 192.168.1.0/24)
  cidrAddress: {
    regex: /^([0-9]{1,3}\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[1-9])\/([0-9]|[1-2][0-9]|3[0-2])$/,
    message: 'Invalid CIDR format (e.g., 192.168.1.0/24).',
    validate(value) {
      return this.regex.test(value)
    },
  },

  // Netmask Validation (e.g., 255.255.255.0)
  netmask: {
    regex: /^(255|254|252|248|240|224|192|128|0+)\.0+\.0+\.0+$/,
    message: 'Invalid netmask format.',
    validate(value) {
      return this.regex.test(value)
    },
  },

  // IP Address Range Validation (e.g., 192.168.1.1-192.168.1.255)
  ipRange: {
    regex:
      /^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))-(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/,
    message: 'Invalid IP address range format.',
    validate(value) {
      return this.regex.test(value)
    },
  },

  // Port Validation (1 - 65535)
  port: {
    validate(value) {
      return Number(value) >= 1 && Number(value) <= 65535
    },
    message: 'Port must be between 1 and 65535.',
  },

  // Port Range Validation (e.g., 80-443)
  portRange: {
    regex: /^([0-9]{1,5})-([0-9]{1,5})$/,
    message: 'Invalid port range format (e.g., 80-443).',
    validate(value) {
      if (!this.regex.test(value)) return false
      const [start, end] = value.split('-').map(Number)
      return start >= 1 && end <= 65535 && start <= end
    },
  },

  // Domain Name Validation (e.g., example.com)
  domainName: {
    regex: /^[a-zA-Z0-9\-_.]+$/,
    message: 'Invalid domain name.',
    validate(value) {
      return this.regex.test(value)
    },
  },

  // URL Validation (with or without http/https)
  url: {
    regex: /^(https?:\/\/)?([\da-z.-]+)\.([a-z.]{2,6})([/\w .-]*)*\/?$/,
    message: 'Invalid URL format.',
    validate(value) {
      return this.regex.test(value)
    },
  },

  // Router ID Validation (Uses IPv4 Format)
  routerId: {
    regex:
      /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/,
    message: 'Invalid Router ID.',
    validate(value) {
      return this.regex.test(value)
    },
  },

  // Router Area ID Validation
  routerArea: {
    regex: /^[0-9]+$/,
    message: 'Invalid Router Area.',
    validate(value) {
      return this.regex.test(value)
    },
  },

  // MTU Size Validation (68-9000)
  mtu: {
    validate(value) {
      return Number(value) === 0 || (Number(value) >= 68 && Number(value) <= 9000)
    },
    message: 'Invalid MTU value (must be between 68 and 9000, or 0 for default).',
  },

  // Public Key Length Validation (WireGuard)
  wireguardPublicKey: {
    validate(value) {
      return value.length === 44
    },
    message: 'Public key must be 44 characters long.',
  },

  // Hostname Validation (e.g., server1.local)
  hostName: {
    regex: /^[a-zA-Z0-9\-_.]+$/,
    message: 'Invalid hostname format.',
    validate(value) {
      return this.regex.test(value)
    },
  },
}
