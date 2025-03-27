module.exports = {
  presets: ['@vue/cli-plugin-babel/preset'],

  // fixes webpack 4 not being able to read optional chaining
  plugins: ['@babel/plugin-transform-optional-chaining'],
}
