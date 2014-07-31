{$, View, EditorView} = require 'atom'

SearchModel = require './search-model'

module.exports =
class InputView extends View
  @content: ->
    @div tabIndex: -1, class: 'isearch tool-panel panel-bottom', =>
      @div class: 'block', =>
        @span outlet: 'descriptionLabel', class: 'description', 'Incremental Search'
        @span outlet: 'optionsLabel', class: 'options'

      @div class: 'find-container block', =>
        @div class: 'editor-container', =>
          @subview 'findEditor', new EditorView(mini: true, placeholderText: 'search')

        @div class: 'btn-group btn-toggle btn-group-options', =>
          @button outlet: 'regexOptionButton', class: 'btn', '.*'
          @button outlet: 'caseOptionButton', class: 'btn', 'Aa'

  initialize: (serializeState) ->
    serializeState = serializeState || {}
    @searchModel = new SearchModel(serializeState.modelState)
    @handleEvents()

  handleEvents: ->
    # Setup event handlers

    @on 'core:cancel core:close', => @cancelSearch()

    @findEditor.on 'core:confirm', => @stopSearch()
    @findEditor.getEditor().on 'contents-modified', => @updateSearchText()

    @command 'incremental-search:toggle-regex-option', @toggleRegexOption
    @command 'incremental-search:toggle-case-option', @toggleCaseOption

    @searchModel.on 'updatedOptions', =>
      console.log('got event')
      @updateOptionButtons()
      @updateOptionsLabel()

  afterAttach: ->
    unless @tooltipsInitialized
      @regexOptionButton.setTooltip("Use Regex", command: 'incremental-search:toggle-regex-option', commandElement: @findEditor)
      @caseOptionButton.setTooltip("Match Case", command: 'incremental-search:toggle-case-option', commandElement: @findEditor)
      @tooltipsInitialized = true

  hideAllTooltips: ->
    @regexOptionButton.hideTooltip()
    @caseOptionButton.hideTooltip()

  toggleRegexOption: =>
    @searchModel.update({pattern: @findEditor.getText(), useRegex: !@searchModel.useRegex})
    @updateOptionsLabel()
    @updateOptionButtons()

  toggleCaseOption: =>
    @searchModel.update({pattern: @findEditor.getText(), caseSensitive: !@searchModel.caseSensitive})
    @updateOptionsLabel()
    @updateOptionButtons()

  updateSearchText: ->
    pattern = @findEditor.getText()
    @searchModel.update({ pattern })

  # Returns an object that can be retrieved when package is activated
  serialize: ->
    modelState: @searchModel.serialize()

  # Tear down any state and detach
  destroy: ->
    @detach()

  detach: ->
    @hideAllTooltips()
    atom.workspaceView.focus()
    super()

  trigger: (direction) ->
    # The user pressed one of the shortcut keys.
    #
    # If focus is not in the edit control put it there and do not search.  This works for the
    # initial trigger which displays the form and for cases where the user searched, edited the
    # buffer, and now wants to continue.  (I expect this to be tweaked over time.)
    #
    # Always record the direction in case it changed.
    #
    # If focus was in the edit control then we need to search.  If the edit control is empty,
    # first populate with the previous search.

    initial = not @hasParent()

    if not @hasParent()
      atom.workspaceView.prependToBottom(this)

    @updateOptionsLabel()
    @updateOptionButtons()

    @searchModel.direction = direction

    if initial
      # The model keeps track of where the search started.  If we haven't done that yet
      # then we are starting a new search.
      @findEditor.setText('');
      @searchModel.start('')
    else if @findEditor.getText()
      # We already have text in the box, so search for the next item
      @searchModel.findNext()
    else
      # There is no text in the box so populate with the previous search.
      if @searchModel.history.length
        pattern = @searchModel.history[@searchModel.history.length-1]
        @findEditor.setText(pattern)
        @searchModel.update({ pattern })

    if not @findEditor.is(':focus')
      @findEditor.focus()
      return

  stopSearch: ->
    # Enter was pressed, so leave the cursor at its current position and clean up.
    @searchModel.stopSearch()
    @detach()

  cancelSearch: ->
    @searchModel.cancelSearch()
    @detach()

  updateOptionsLabel: ->
    label = []
    if @searchModel.useRegex
      label.push('regex')
    if @searchModel.caseSensitive
      label.push('case sensitive')
    else
      label.push('case insensitive')
    @optionsLabel.text(' (' + label.join(', ') + ')')

  updateOptionButtons: ->
    @setOptionButtonState(@regexOptionButton, @searchModel.useRegex)
    @setOptionButtonState(@caseOptionButton, @searchModel.caseSensitive)

  setOptionButtonState: (optionButton, selected) ->
    if selected
      optionButton.addClass 'selected'
    else
      optionButton.removeClass 'selected'