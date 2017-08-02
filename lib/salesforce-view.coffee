{$, ScrollView, View}  = require 'atom-space-pen-views'
path          = require 'path'
emitter       = require('./emitter').pubsub
remote        = require 'remote'
BrowserWindow = remote.BrowserWindow

class BrowserView extends ScrollView

  constructor: (@params) ->
    super
    self = @
    @page = Object.keys(self.params.result)[0]
    @url = self.params.result[Object.keys(self.params.result)[0]]
    console.log @page
    console.log @url

    @webview = @find('webview')[0]
    console.log @webview
    console.log @url
    @setLocation @url

    emitter.on 'mavensmate:compile-finished', (params, promiseId) ->
      textEditor = self.params.textEditor
      files = params.payload.paths
      # if textEditor.getPath()? and util.isMetadata(textEditor.getPath())
      if textEditor.getPath()?
        for f in files
          if util.baseName(f) == self.page
            self.iframe.attr 'src', self.url
            break

  @content: ->
    @div class:'browser-page', style:'height:100%', tabindex:-1, =>
      @tag 'webview', style: 'height:100%'

  @deserialize: (state) ->
    new BrowserView(state)

  setLocation: (url) -> $(@webview).attr src: url

  serialize: ->
    deserializer: 'BrowserView'
    version: 1
    uri: @uri

  getTitle: ->
    @page

  getIconName: ->
    'browser'

  getURI: ->
    @uri

  # Tear down any state and detach
  destroy: ->
    @detach()

class BrowserViewOld
  constructor: (@params) ->
    self = @
    @win = new BrowserWindow({ width: 800, height: 600 })
    @url = self.params.result[Object.keys(self.params.result)[0]]
    @resource = Object.keys(self.params.result)[0]
    @win.loadUrl(@url)
    @util = util

    emitter.on 'mavensmate:compile-finished', (params, promiseId) ->
      textEditor = self.params.textEditor
      files = params.payload.paths
      if textEditor.getPath()?
        for f in files
          if self.util.baseName(f) == self.resource
            self.win.reload()
            break

class IFrameView extends ScrollView
  constructor: (@params) ->
    super
    self = @
    # console.log self.params
    @page = Object.keys(self.params.result)[0]
    @url = self.params.result[Object.keys(self.params.result)[0]]

    @promiseId = @params.promiseId
    @iframe.attr 'src', @url
    @iframe.attr 'id', 'iframe-'+@promiseId

    emitter.on 'mavensmate:compile-finished', (params, promiseId) ->
      textEditor = self.params.textEditor
      files = params.payload.paths
      # if textEditor.getPath()? and util.isMetadata(textEditor.getPath())
      if textEditor.getPath()?
        for f in files
          if util.baseName(f) == self.page
            self.iframe.attr 'src', self.url
            break

  @deserialize: (state) ->
    new IFrameView(state)

  # Internal: Initialize mavensmate output view DOM contents.
  @content: ->
    @div class: 'mavensmate', =>
      @iframe outlet: 'iframe', width: '100%', height: '100%', class: 'native-key-bindings', sandbox: 'allow-same-origin allow-top-navigation allow-forms allow-scripts', style: 'border:none;'

  serialize: ->
    deserializer: 'IFrameView'
    version: 1
    uri: @uri

  getTitle: ->
    @page

  getIconName: ->
    'browser'

  getURI: ->
    @uri

  # Tear down any state and detach
  destroy: ->
    @detach()

module.exports.IFrameView = IFrameView
module.exports.BrowserView = BrowserView
