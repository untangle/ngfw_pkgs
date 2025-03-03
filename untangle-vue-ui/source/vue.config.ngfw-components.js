module.exports = {
  outputDir: 'dist/ngfw-components',
  transpileDependencies: ['vuntangle'],
  pages: {
    'ngfw-components': {
      entry: 'src/vue-components.js',
      template: 'public/vue-components.html',
    },
  },

  filenameHashing: false, // do not hash until dynamically JSP update

  configureWebpack: {
    resolve: {
      fallback: { 'url': false, 'util': false },
    },
  },

  chainWebpack: config => {
    // don't need html
    config.plugins.delete('html')
    config.plugins.delete('preload')
    config.plugins.delete('prefetch')
  },
}
