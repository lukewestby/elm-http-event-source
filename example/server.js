const path = require('path')
const express = require('express')
const sseMiddelware = require('server-sent-events')
const webpack = require('webpack')
const StringReplacePlugin = require('string-replace-webpack-plugin')
const webpackMiddleware = require('webpack-dev-middleware')

const app = express()

// Don't mind this, it's just loading our front-end Elm for us
app.use(webpackMiddleware(webpack({
  entry: {
    main: path.join(__dirname, './client.js'),
  },
  module: {
    loaders: [
      {
        test: /\.elm$/,
        loaders: [
          StringReplacePlugin.replace({
            replacements: [
              {
                pattern: /_user\$project\$Native_EventSource/g,
                replacement: () => '_lukewestby$elm_http_event_source$Native_EventSource',
              },
            ],
          }),
          'elm-webpack',
        ],
      },
    ],
  },
  output: {
    filename: '[name].js',
    path: '/',
    publicPath: '/assets/'
  },
  plugins: [
    new StringReplacePlugin(),
  ]
}), {
  noInfo: false,
  quiet: false,
  lazy: false,
  watchOptions: {
    aggregateTimeout: 300,
    poll: true,
  },
  publicPath: '/assets/',
  stats: {
    colors: true,
  },
}))

// Send the user a document with our Elm app
app.get('/', (req, res) => {
  res.send(`<!DOCTYPE html>
<html>
  <head>
    <title>Elm HTTP EventSource example</title>
  </head>
  <body>
    <script src="/assets/main.js"></script>
  </body>
</html>`)
})

// The real magic: wire up some events
app.get('/events', sseMiddelware, (req, res) => {
  setInterval(() => {
    res.sse(`event: short-timeout\ndata: Short timeout at ${Date.now()}\n\n`)
  }, 1000)

  setInterval(() => {
    res.sse(`event: long-timeout\ndata: Long timeout at ${Date.now()}\n\n`)
  }, 5000)
})


app.listen(8080, () => {
  console.log('app running on port 8080')
})
