MavensMate = require './mavensmate'

module.exports =

  mavensmate: null

  # configure MM for Atom SPECIFIC settings (global MavensMate settings handled in mavensmate-app)
  config:
    mm_compile_on_save :
      title: 'Compile files on save'
      description: ''
      type: 'boolean'
      default: true
      order: 100
    mm_close_panel_on_successful_operation:
      title: 'Close panel on successful operation'
      description: ''
      type: 'boolean'
      default: true
      order: 200
    mm_close_panel_delay:
      title: 'Close panel delay'
      description: 'Delay in milliseconds before panel closes on successful operation'
      type: 'integer'
      default: 2000
      order: 300
    mm_apex_file_extensions:
      title: 'Salesforce file extensions'
      description: ''
      type: 'array'
      default: [".page", ".component", ".cls", ".object", ".trigger", ".layout", ".resource", ".remoteSite", ".labels", ".app", ".dashboard", ".permissionset", ".workflow", ".email", ".profile", ".scf", ".queue", ".reportType", ".report", ".weblink", ".tab", ".letter", ".role", ".homePageComponent", ".homePageLayout", ".objectTranslation", ".flow", ".datacategorygroup", ".snapshot", ".site", ".sharingRules", ".settings", ".callCenter", ".community", ".authProvider", ".customApplicationComponent", ".quickAction", ".approvalProcess", ".html" ]
      order: 400
    mm_app_server_port :
      title: 'MavensMate app server port'
      description: ''
      type: 'integer'
      default: 56248
      order: 500
    mm_panel_height :
      title: 'Panel height'
      description: ''
      type: 'integer'
      default: 200
      order: 600

  # todo: should we initiate the app per editorview?
  # right now, this activates MavensMate once per Atom window
  # i think we want to keep each MavensMate() instance tied to a project, but not 100% sure how to approach that
  activate: (state) ->
    console.log '===========> Activating MavensMate-Atom'
    @unsetDeprecatedSettings()
    @mavensmate = new MavensMate()

  # removes deprecated mm for atom settings from config.cson (most are now managed globally in mavensmate-app)
  unsetDeprecatedSettings: ->
    config = atom.config.get('MavensMate-Atom')
    deprecatedSettings = [
      'mm_workspace'
      'mm_api_version'
      'mm_compile_check_conflicts'
      'mm_timeout'
      'mm_default_subscription'
      'mm_log_location'
      'mm_log_level'
      'mm_play_sounds'
      'mm_template_location'
      'mm_template_source'
      'mm_atom_exec_path'
      'mm_ignore_managed_metadata'
      'mm_community_api_token'
      'mm_http_proxy'
      'mm_https_proxy'
      'mm_use_keyring'
    ]
    for ds in deprecatedSettings
      if config[ds]?
        atom.config.unset('MavensMate-Atom.'+ds)

  deactivate: ->
    console.log '===========> Deactivating MavensMate-Atom'
    @mavensmate?.destroy()
    delete @mavensmate
