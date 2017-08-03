{Subscriber,Emitter}  = require 'emissary'
util                  = require './util'
emitter               = require('./emitter').pubsub

module.exports =
class ErrorMarkers
  Subscriber.includeInto(this)

  constructor: (@editor) ->
    @initialize()
    @refreshMarkers()

  initialize: ->
    thisView = @
    emitter.on 'mavensmate:compile-finished', (params) ->
      thisView.refreshMarkers()

  clearMarkers: ->
    return unless @markers?
    marker.destroy() for marker in @markers
    @markers = null

  refreshMarkers: ->
    try
      console.log 'refreshing buffer markers ...'
      if @editor.getPath()
        if atom.project.mavensMateErrors[@editor.getPath()]?
          errors = atom.project.mavensMateErrors[@editor.getPath()]
        else
          currentFileNameWithoutExtension = util.baseName(@editor.getPath())
          errors = atom.project.mavensMateErrors[currentFileNameWithoutExtension] ? []

      @clearMarkers()

      if errors?
        lines_to_highlight = (error['lineNumber'] for error in errors when error['lineNumber']?)
        for line in lines_to_highlight
          @markRange(line-1, line-1, 'mm-compile-error-gutter', 'gutter')
          @markRange(line-1, line-1, 'mm-compile-error-line', 'highlight')
    catch error
      console.log 'error refreshing buffer markers'
      console.error error

  markRange: (startRow, endRow, klass, type) ->
    marker = @editor.markBufferRange([[startRow, 0], [endRow, Infinity]], invalidate: 'never')
    @editor.decorateMarker(marker, type: type, class: klass)
    @markers ?= []
    @markers.push(marker)
