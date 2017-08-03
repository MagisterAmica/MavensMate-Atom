_           = require 'underscore-plus'
uuidv1        = require 'uuid/v1'
emitter     = require('./emitter').pubsub

class PromiseTracker

  # object containing promises we're tracking
  # {
  #   'tracked-promise-uuid' : {
  #     id : 'tracked-promise-uuid',
  #     complete: false,
  #     result: 'some result'
  #   }
  # }
  tracked:{}

  constructor: () ->

  # initiates base promise, assigns id
  #
  # returns promise id
  enqueuePromise: (operation) ->
    emitter.emit 'mavensmate:promise-enqueued'

    promiseId = uuidv1()
    promise = {
      id: promiseId,
      complete: false,
      operation: operation
    }
    @tracked[promiseId] = promise
    promiseId

  hasPendingOperation: (operation) ->
    console.debug 'is there a pending operation for: '+operation
    return _.find(@tracked, (item) -> return item.operation == operation ) != undefined

  start: (promiseId, promise) ->
    emitter.emit 'mavensmate:promise-started', promiseId, promise
    @tracked[promiseId].work = promise.then(@completePromise).catch(@completePromise)

  # utility method for determining whether the promiseId pass is finished
  #
  # returns true/false
  isPromiseComplete: (promiseId) ->
    @tracked[promiseId].complete

  # returns the promise requested
  pop: (promiseId, pop=true) ->
    if pop
      p = _.clone(@tracked[promiseId])
      delete @tracked[promiseId]
      return p
    else
      @tracked[promiseId]

  completePromise: (result) ->
    tracker.tracked[result.promiseId].result = result
    tracker.tracked[result.promiseId].complete = true

tracker = new PromiseTracker()
exports.tracker = tracker
