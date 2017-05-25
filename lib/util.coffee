_                 = require 'underscore-plus'
_.str             = require 'underscore.string'
__                = require 'lodash'
fs                = require 'fs'
os                = require 'os'
path              = require 'path'
CoreAdapter       = require('./adapter')
BrowserView       = require('./salesforce-view').BrowserView
commands          = require './commands.json'

module.exports =

  class MMUtil

    @getCommands: (scope) ->
      if scope?
        return __.where(commands, {
          scope: scope
        })
      else
        return commands

    @getCommandByCoreName: (name, ui=false) ->
      return __.find(commands, {
        coreName: name,
        ui: ui
      })

    @getCommandByAtomName: (name) ->
      return __.find(commands, {
        atomName: name
      })

    # returns the active file path
    @activeFile: ->
      editor = atom.workspace.getActivePaneItem()
      file = editor?.buffer.file
      file?.path

    # returns base name for active file
    @activeFileBaseName: ->
      editor = atom.workspace.getActivePaneItem()
      file = editor?.buffer?.file
      file?.getBaseName()

    # returns base name for file path
    # e.g. /workspace/MyApexClass.cls -> MyApexClass.cls
    @baseName: (filePath) ->
      filePath.split(/[\\/]/).pop()

    @extension: (filePath) ->
      '.' + filePath.split(/[.]/).pop()

    # takes a file path and returns it as a string or object (synchronously)
    @fileBodyAsString: (path, parseAsJson = false) ->
      fileBody = fs.readFileSync path
      if parseAsJson
        return JSON.parse fileBody
      else
        return fileBody

    # returns the name of the command
    # useful because the command can reside in args or payload
    @getCommandName: (params) ->
      if params.args? and params.command?
        params.command
      else
        params.payload.command

    # filters the selected items against metadata extensions
    @getSelectedFiles: ->
      selectedFilePaths = []
      apex_file_extensions = atom.config.get('MavensMate-Atom').mm_apex_file_extensions
      treeView = this.treeView()
      if treeView.hasFocus() # clicked in sidebar
        filePaths = treeView.selectedPaths()
      else # command palette or right click in editor
        filePaths = [this.activeFile()]
      for filePath in filePaths
        if this.extension(filePath) in apex_file_extensions
          selectedFilePaths.push(filePath)
      return selectedFilePaths

    # whether the given file is a trigger or apex class
    @isClassOrTrigger: (currentFile) ->
      return currentFile? and (currentFile.indexOf('.trigger') >= 0 or currentFile.indexOf('.cls') >= 0)

    @hasMavensMateProjectStructure: (filePath=atom.project.getPaths()[0]) ->
      try
        settingsPath = path.join filePath, 'config', '.settings'
        return fs.existsSync(settingsPath)
      catch
        return false

    @isMetadata: (filePath) ->
      console.log 'checking whether file is valid sfdc metadata: '+filePath
      apex_file_extensions = atom.config.get('MavensMate-Atom').mm_apex_file_extensions
      return (path.extname(filePath) in apex_file_extensions || path.basename(path.dirname(path.dirname(filePath))) == 'aura') and path.basename(path.dirname(filePath)) != 'config'

    # Whether or not a file exists in the project's src directory
    @isInSrcPath: (filepath) ->
      src = fs.realpathSync(atom.project.getPaths() + "/src")
      filepath = fs.realpathSync(filepath)
      return filepath.indexOf(src) == 0

    # compile-related commands
    @compileCommands: ->
      [
        'compile-metadata',
        'compile-project',
        'clean-project',
        'refresh-metadata'
      ]

    @numberOfCompileErrors: (fileName) ->
      numberOfErrors = 0
      if fileName?
        numberOfErrors = atom.project.mavensMateErrors[fileName].length
      else
        for fileName, errors of atom.project.mavensMateErrors
          numberOfErrors += errors.length
      return numberOfErrors

    # list of commands that do not have status displayed in the panel
    @panelExemptCommands: ->
      [
        'get-indexed_metadata',
        'session',
        'new-apex-overlay',
        'delete-apex-overlay',
        'index-apex-overlays',
        'list-metadata'
      ]

    @isWindows = ->
      os.platform() == 'win32'

    @isLinux = ->
      os.platform() == 'linux'

    @isMac = ->
      os.platform() == 'darwin'

    @getHomeDirectory = ->
      if @isMac()
        return process.env.HOME
      else if @isWindows()
        return process.env[if process.platform == 'win32' then 'USERPROFILE' else 'HOME']
      else if @isLinux()
        return process.env.HOME
      return

    # setting object to configure MavensMate for future SFDC updates
    @sfdcSettings:
      maxCheckpoints: 5

    # returns tree view
    @treeView: ->
      atom.packages.getActivePackage('tree-view').mainModule.treeView

    @withoutExtension: (filePath) ->
      filePath.split(/[.]/).shift()

    @uris:
      errorsView: 'mavensmate://errorsView'
