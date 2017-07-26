fuzzaldrin  = require 'fuzzaldrin'
apex        = require './apex.json'
vf          = require './vf.json'
_           = require 'underscore-plus'
__          = require 'lodash'

trailingWhitespace = /\s$/
attributePattern = /\s+([a-zA-Z][-a-zA-Z]*)\s*=\s*$/
# tagPattern = /<(apex:([a-zA-Z][-a-zA-Z]*)|social:([a-zA-Z][-a-zA-Z]*)|site:([a-zA-Z][-a-zA-Z]*)|ideas:([a-zA-Z][-a-zA-Z]*)|support:([a-zA-Z][-a-zA-Z]*)|chatter:([a-zA-Z][-a-zA-Z]*)|chatter:([a-zA-Z][-a-zA-Z]*))(?:\s|$)/
# tagPattern = /<([a-zA-Z][-a-zA-Z]*)(?:\s|$)/
tagPattern = /<([a-zA-Z]*:?[a-zA-Z]*)(?:\s|$)/

apexClasses = []
apexNamespaces = apex.publicDeclarations
_.each _.keys(apexNamespaces), (ns) ->
  _.each _.keys(apexNamespaces[ns]), (cls) ->
    apexClasses.push cls

firstCharsEqual = (str1, str2) ->
  str1[0].toLowerCase() is str2[0].toLowerCase()

# provides code assist for standard Apex Classes
#
# e.g. when user types "S", String, StringException, Site, Set, System, Sobject, etc. are showing in suggestions
ApexProvider =
  selector: '.source.apex'
  filterSuggestions: true

  getSuggestions: (options) ->
    suggestions = []
    console.log('apex suggestions', options)
    [first, ..., last] = options.scopeDescriptor.scopes
    if last == 'meta.definition.variable.apex'
      # variable name, skip
    else
      words = fuzzaldrin.filter apexClasses, options.prefix
      for word in words
        suggestion =
          replacementPrefix: options.prefix
          text: word
          rightLabel: 'Apex'
        suggestions.push(suggestion)
    return suggestions
  
# provides code assist for visualforce tags
#
# e.g. when user types "<", list of vf tags is presented
VisualforceTagProvider =
  # selector: '.visualforce'
  vfTags: vf.tags
  vfDefs: vf.tagDefs

  selector: '.visualforce.text.html.basic'
  disableForSelector: '.visualforce.text.html.basic .comment'
  filterSuggestions: true

  getSuggestions: (request) ->
    console.log 'getting suggestions ...', request

    if request.scopeDescriptor.scopes.indexOf('string.quoted.double.html') == -1
      {prefix} = request
      if @isAttributeValueStartWithNoPrefix(request)
        @getAttributeValueCompletions(request)
      else if @isAttributeValueStartWithPrefix(request)
        @getAttributeValueCompletions(request, prefix)
      else if @isAttributeStartWithNoPrefix(request)
        @getAttributeNameCompletions(request)
      else if @isAttributeStartWithPrefix(request)
        @getAttributeNameCompletions(request, prefix)
      else if @isTagStartWithNoPrefix(request)
        @getTagNameCompletions()
      else if @isTagStartTagWithPrefix(request)
        @getTagNameCompletions(prefix)
      else
        []

  isTagStartWithNoPrefix: ({prefix, scopeDescriptor}) ->
    scopes = scopeDescriptor.getScopesArray()
    if prefix is '<' and scopes.length is 1
      scopes[0] is 'text.html.basic'
    else if prefix is '<' and scopes.length is 2
      scopes[0] is 'text.html.basic' and scopes[1] is 'meta.scope.outside-tag.html'
    else
      false

  isTagStartTagWithPrefix: ({prefix, scopeDescriptor}) ->
    return false unless prefix
    return false if trailingWhitespace.test(prefix)
    @hasTagScope(scopeDescriptor.getScopesArray())

  isAttributeStartWithNoPrefix: ({prefix, scopeDescriptor}) ->
    return false unless trailingWhitespace.test(prefix)
    @hasTagScope(scopeDescriptor.getScopesArray())

  isAttributeStartWithPrefix: ({prefix, scopeDescriptor}) ->
    return false unless prefix
    return false if trailingWhitespace.test(prefix)

    scopes = scopeDescriptor.getScopesArray()
    return true if scopes.indexOf('entity.other.attribute-name.html') isnt -1
    return false unless @hasTagScope(scopes)

    scopes.indexOf('punctuation.definition.tag.html') isnt -1 or
      scopes.indexOf('punctuation.definition.tag.end.html') isnt -1

  isAttributeValueStartWithNoPrefix: ({scopeDescriptor, prefix}) ->
    lastPrefixCharacter = prefix[prefix.length - 1]
    return false unless lastPrefixCharacter in ['"', "'"]
    scopes = scopeDescriptor.getScopesArray()
    @hasStringScope(scopes) and @hasTagScope(scopes)

  isAttributeValueStartWithPrefix: ({scopeDescriptor, prefix}) ->
    lastPrefixCharacter = prefix[prefix.length - 1]
    return false if lastPrefixCharacter in ['"', "'"]
    scopes = scopeDescriptor.getScopesArray()
    @hasStringScope(scopes) and @hasTagScope(scopes)

  hasTagScope: (scopes) ->
    scopes.indexOf('meta.tag.any.html') isnt -1 or
      scopes.indexOf('meta.tag.other.html') isnt -1 or
      scopes.indexOf('meta.tag.block.any.html') isnt -1 or
      scopes.indexOf('meta.tag.inline.any.html') isnt -1 or
      scopes.indexOf('meta.tag.structure.any.html') isnt -1

  hasStringScope: (scopes) ->
    scopes.indexOf('string.quoted.double.html') isnt -1 or
      scopes.indexOf('string.quoted.single.html') isnt -1

  getTagNameCompletions: (prefix) ->
    completions = []
    for tag, attributes of @vfDefs when not prefix or firstCharsEqual(tag, prefix)
      completions.push(@buildTagCompletion(tag))
    completions

  buildTagCompletion: (tag) ->
    text: tag
    type: 'tag'
    description: "Visualforce <#{tag}> tag"
    descriptionMoreURL: @getTagDocsURL(tag)

  getAttributeNameCompletions: ({editor, bufferPosition}, prefix) ->
    completions = []
    tag = @getPreviousTag(editor, bufferPosition)
    tagAttributes = @getTagAttributes(tag)

    console.log('prefix', prefix)
    console.log('tagAttributes', tagAttributes)
    
    for name, val of tagAttributes when not prefix or firstCharsEqual(name, prefix)
      console.log(val, name)
      completions.push(@buildAttributeCompletion(name, val, tag))

    for attribute, options of @vfDefs.attribs when not prefix or firstCharsEqual(attribute, prefix)
      console.log(attribute, options)
      completions.push(@buildAttributeCompletion(attribute)) if options.global

    completions

  buildAttributeCompletion: (attribute, def, tag) ->
    if tag?
      snippet: "#{attribute}=\"$1\"$0"
      displayText: attribute
      type: 'attribute'
      rightLabel: "<#{tag}>"
      description: "(#{def.type}) #{attribute} attribute local to <#{tag}> tags"
      # descriptionMoreURL: @getLocalAttributeDocsURL(attribute, tag)
    else
      snippet: "#{attribute}=\"$1\"$0"
      displayText: attribute
      type: 'attribute'
      description: "Global #{attribute} attribute"
      # descriptionMoreURL: @getGlobalAttributeDocsURL(attribute)

  getAttributeValueCompletions: ({editor, bufferPosition}, prefix) ->
    tag = @getPreviousTag(editor, bufferPosition)
    attribute = @getPreviousAttribute(editor, bufferPosition)
    values = @getAttributeValues(attribute)
    for value in values when not prefix or firstCharsEqual(value, prefix)
      @buildAttributeValueCompletion(tag, attribute, value)

  buildAttributeValueCompletion: (tag, attribute, value) ->
    if @completions.attributes[attribute].global
      text: value
      type: 'value'
      description: "#{value} value for global #{attribute} attribute"
      descriptionMoreURL: @getGlobalAttributeDocsURL(attribute)
    else
      text: value
      type: 'value'
      description: "#{value} value for #{attribute} attribute local to <#{tag}>"
      descriptionMoreURL: @getLocalAttributeDocsURL(attribute, tag)

  loadCompletions: ->
    @completions = {}
    fs.readFile path.resolve(__dirname, '..', 'completions.json'), (error, content) =>
      @completions = JSON.parse(content) unless error?
      return

  getPreviousTag: (editor, bufferPosition) ->
    {row} = bufferPosition
    while row >= 0
      tag = tagPattern.exec(editor.lineTextForBufferRow(row))?[1]
      console.log('getPreviousTag', tag)
      return tag if tag
      row--
    return

  getPreviousAttribute: (editor, bufferPosition) ->
    line = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition]).trim()

    # Remove everything until the opening quote
    quoteIndex = line.length - 1
    quoteIndex-- while line[quoteIndex] and not (line[quoteIndex] in ['"', "'"])
    line = line.substring(0, quoteIndex)

    attributePattern.exec(line)?[1]

  getAttributeValues: (attribute) ->
    attribute = @completions.attributes[attribute]
    attribute?.attribOption ? []

  getTagAttributes: (tag) ->
    @vfDefs[tag]?.attribs ? []

  getTagDocsURL: (tag) ->
    "https://developer.mozilla.org/en-US/docs/Web/HTML/Element/#{tag}"

  getLocalAttributeDocsURL: (attribute, tag) ->
    "#{@getTagDocsURL(tag)}#attr-#{attribute}"

  getGlobalAttributeDocsURL: (attribute) ->
    "https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/#{attribute}"

  getSuggestionsOLD: (options) ->
    console.log 'vf provider'
    console.log options
    suggestions = []
    scopeChain = options.scopeDescriptor.scopes.join(' ')
    console.log(scopeChain)
    if scopeChain == 'visualforce.text.html.basic' or scopeChain.indexOf('entity.name.tag.other.html') > 0
      words = fuzzaldrin.filter @vfTags, options.prefix
      for word in words
        suggestion =
          prefix: options.prefix
          word: word
          label: 'Visualforce'
        suggestions.push(suggestion)
    else if scopeChain.indexOf('visualforce.text.html.basic meta.tag.other.html') == 0
      console.log(@getPreviousTag(options.editor, options.bufferPosition))
      previousTag = @getPreviousTag(options.editor, options.bufferPosition)
      if previousTag?
        previousTag = previousTag.replace('<','')
      console.log(previousTag)
      tagDef = @vfDefs[previousTag]
      console.log(tagDef)
      if tagDef
        __.each(tagDef.attribs, (val, key) ->
          suggestion =
            prefix: options.prefix
            text: key
            displayText: key
            description: ''
            type: val.type
            label: 'VF'
          suggestions.push(suggestion)
        )
    return suggestions

module.exports.ApexProvider = ApexProvider
module.exports.VisualforceTagProvider = VisualforceTagProvider