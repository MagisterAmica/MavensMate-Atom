{ScrollView}  = require 'atom-space-pen-views'
_             = require 'underscore-plus'
path          = require 'path'
Promise       = require 'bluebird'
tracker       = require('./promise-tracker').tracker
emitter       = require('./emitter').pubsub
request       = require 'request'

class CoreAdapter

  couldNotContactMessage: 'Error: Could not contact the local MavensMate server. Please ensure MavensMate-app \
  is installed and running (https://github.com/joeferraro/mavensmate-app/releases). MavensMate will not run properly \
  until resolved.\n\nMore Information: This version of MavensMate for Atom requires MavensMate-app. MavensMate-app is a \
  new executable that makes it easy to use MavensMate from Sublime Text, Atom, Visual Studio Code, etc.'

  checkStatus: () ->
    self = @

    new Promise((resolve, reject) ->
      request
        .get("http://localhost:#{atom.config.get('MavensMate-Atom').mm_app_server_port}/app/home/index")
        .on('response', (response) =>
          if response.statusCode == 200
            # mavensmate-app is up and running
            resolve()
          else
            console.log(response)
            reject(@couldNotContactMessage)
        )
        .on('error', (err) =>
          console.log(err)
          reject(@couldNotContactMessage)
        )
    )

  executeCommand: (params) ->
    console.log 'executing command via core adapter: '
    console.log params

    payload = params.payload
    promiseId = params.promiseId

    # command = if args.operation then args.operation else payload.command
    command = params.command

    if not promiseId?
      promiseId = tracker.enqueuePromise(command)

    p = new Promise((resolve, reject) ->

      reqUrl = "http://localhost:#{atom.config.get('MavensMate-Atom').mm_app_server_port}/execute?command=#{command}&async=1"
      if atom.project.mavensmateId
        reqUrl += '&pid='+atom.project.mavensmateId

      reqOptions =
        method: 'POST'
        url: reqUrl
        headers:
          'Content-Type': 'application/json'
          'MavensMate-Editor-Agent': 'atom'
        body: JSON.stringify payload

      console.log('executing MavensMate command', reqOptions)

      request(reqOptions, (err, response, body) ->
        console.log('REQUEST CALLBACK')
        console.log err
        console.log response
        console.log body
        if err
          err.message = 'Error reaching local MavensMate server. Please ensure MavensMate-app (https://github.com/joeferraro/mavensmate-app) is installed and running.'
          err.promiseId = promiseId
          console.log err
          reject err
        else
          console.log('response from mavensmate', response, body)
          if response.statusCode > 300
            res =
              promiseId: promiseId
              error: new Error body
            resolve res
          else
            statusResponse = JSON.parse body
            requestId = statusResponse.id
            requestDone = false
            requestResponse = null

            console.log 'Need to poll local MavensMate server for response ...'

            poll = ->
              console.log 'polling for response ...'

              statusOption =
                method: 'GET',
                url: "http://localhost:#{atom.config.get('MavensMate-Atom').mm_app_server_port}/status?id=#{requestId}"
                headers:
                  'MavensMate-Editor-Agent': 'atom'

              request(statusOption, (err, response, body) ->
                if err
                  err.promiseId = promiseId
                  reject err
                else
                  # todo: catch interruption
                  res = JSON.parse body
                  if res.status and res.status == 'pending'
                    setTimeout(->
                      poll()
                    , 500)
                  else
                    console.log('request done >>')
                    console.log(res)
                    res.promiseId = promiseId
                    resolve res
              )

            poll()
      )
    )

    # add to promise tracker,
    tracker.start promiseId, p
    # emit an event so the panel knows when to do its thing
    emitter.emit 'mavensmate:panel-notify-start', params, promiseId

    return p

module.exports = new CoreAdapter()
