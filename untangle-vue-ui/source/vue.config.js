const path = require('path')

module.exports = {
  // ip6 is some package in dependency chain that requires transpiling
  transpileDependencies: ['vuntangle', 'ip6'],
  publicPath: process.env.VUE_APP_BASE_URL,
  devServer: {
    public: 'ngfw-ui.untangle.com:9090',
    port: 9090,
    proxy: {
      // proxy URLs to backend development server
      '/auth': {
        target: `http://ngfw.untangle.com/`,
      },
      '/admin': {
        target: `http://ngfw.untangle.com/`,
      },
    },
  },
  configureWebpack: {
    // output: {
    //   filename: `vue-app.js`,
    //   chunkFilename: `chunk-vendors.js`,
    // },
    watchOptions: {
      aggregateTimeout: 300,
      poll: 1000,
    },
    // module: {
    //   rules: [
    //     {
    //       test: /\.css$/,
    //       use: [
    //         'to-string-loader',
    //         // 'vue-style-loader',
    //         {
    //           loader: 'css-loader',
    //           options: {},
    //         },
    //       ],
    //     },
    //   ],
    // },
  },
  // css: {
  //   extract: {
  //     ignoreOrder: true,
  //     filename: 'vue-app.css',
  //     chunkFilename: 'chunk-vendors.css',
  //   },
  // },
  chainWebpack: config => {
    // this is a fix for a vue-cli linter/cache bug: https://github.com/vuejs/vue-cli/issues/5399
    config.module.rule('vue').uses.delete('cache-loader')
    config.module.rule('js').uses.delete('cache-loader')

    // set aliases so vuntangle package does not duplicate dependencies when 'yarn link' is enabled
    if (process.env.NODE_ENV === 'development') {
      config.resolve.alias.set('highcharts', path.resolve('./node_modules/highcharts'))
      config.resolve.alias.set('lodash', path.resolve('./node_modules/lodash'))
      config.resolve.alias.set('vee-validate', path.resolve('./node_modules/vee-validate'))
      config.resolve.alias.set('vue', path.resolve('./node_modules/vue'))
      config.resolve.alias.set('vue-i18n', path.resolve('./node_modules/vue-i18n'))
      config.resolve.alias.set('vuetify', path.resolve('./node_modules/vuetify'))
    }
  },
}
