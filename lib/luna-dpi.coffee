SettingsView = require 'settings-view'
LunaDpiView  = require './luna-dpi-view'
WebFrame = require('electron').webFrame

{CompositeDisposable} = require 'atom'


class Slider
  constructor: (@val, @callback) ->
    _this = @
    @desc = document.createElement 'div'
    @desc.style     = 'position:absolute; color:red; width:100%; pointer-events:none; text-align:center;'
    @desc.className = 'label'

    @range = document.createElement 'input'
    @range.className = 'input-range'
    @range.type      = 'range'
    @range.min       = 0.375
    @range.max       = 3.0
    @range.step      = 0.125
    @range.oninput   = () -> _this.desc.innerHTML = _this.range.value
    @range.onchange  = () -> _this.callback _this.range.valueAsNumber

    @domRef = document.createElement 'div'
    @domRef.style     = 'position:relative;'
    @domRef.className = 'slider'
    @domRef.appendChild @desc
    @domRef.appendChild @range

    @setVal @val

  setVal: (val) ->
    @desc.innerHTML = val
    @range.value    = val

  # on: (evt, handler) -> @range.addEventListener(evt, handler)

patchThemesPanel = (el) ->
  tp      = el.getElementsByClassName("themes-picker")[0]
  graphTp = document.createElement 'div'
  graphTp.className = 'themes-picker-item control-group'
  graphTp.innerHTML = '
    <div class="controls">
       <label class="control-label">
          <div class="setting-title themes-label text">Graph Theme</div>
          <div class="setting-description text theme-description">This styles Luna graph representation</div>
       </label>
       <div class="select-container">
          <select class="form-control">
             <option value="atom-dark-ui">Luna Dark</option>
             <option value="atom-light-ui">Luna Light</option>
          </select>
          <button class="btn icon icon-gear active-theme-settings" data-original-title="" title=""></button>
       </div>
    </div>'
  tp.appendChild graphTp

patchCorePanel = (el) ->
  sect      = el.getElementsByClassName("section-container")[0]
  body      = sect.getElementsByClassName("section-body")[0]
  zoomCtrl  = document.createElement 'div'
  controls  = document.createElement 'div'
  zoomCtrl.className = 'control-group'
  controls.className = 'controls'
  controls.innerHTML = '
  <label class="control-label">
    <div class="setting-title">GUI Zoom</div>
    <div class="setting-description">Zoom factor used to scale the interface.</div>
  </label>'
  controls.appendChild @zoomSlider.domRef
  zoomCtrl.appendChild controls
  body.insertBefore zoomCtrl, body.firstChild

patchPanel = (sv, name, patch) ->
  callback = sv.panelCreateCallbacks?[name]
  panel    = sv.panelsByName?[name]
  if panel?
    patch panel.element
  if callback?
    sv.panelCreateCallbacks[name] = () ->
      th = callback()
      patch th.element
      th

module.exports = LunaDpi =
  lunaDpiView   : null
  modalPanel    : null
  subscriptions : null

  setZoom: (val) ->
    console.log "!"
    console.log @
    @zoom = val
    WebFrame.setZoomFactor val


  activate: (state) ->
    @zoom = 1.0

    # Zoom Core/slider <-> config binding
    zoomOpt = 'luna-dpi.zoom'
    @zoomSlider = new Slider @zoom, (val) =>
      @setZoom.call @, val
      atom.config.set zoomOpt, val
    atom.config.observe zoomOpt, (val) =>
      @setZoom val
      @zoomSlider.setVal val

    # Subscriptions
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace', 'luna-dpi:toggle': => @toggle()

    patchSettingsViewInit = (sv) ->
      svInitializePanels = sv.initializePanels
      sv.initializePanels = () ->
        panels = svInitializePanels.call sv
        patchSettingsView sv
        panels
      patchSettingsView sv

    patchSettingsView = (sv) =>
      patchPanel sv, 'Themes', patchThemesPanel
      patchPanel sv, 'Core'  , patchCorePanel.bind @


    atom.packages.activatePackage('settings-view').then (settingsViewPkg) =>
      s = settingsViewPkg.mainModule

      if s.settingsView?
        patchSettingsViewInit s.settingsView

      _newSettingsView_ = s.newSettingsView
      s.newSettingsView = (params) ->
        sv = _newSettingsView_ params
        patchSettingsViewInit sv
        sv

    @lunaDpiView = new LunaDpiView(state.lunaDpiViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @lunaDpiView.getElement(), visible: false)

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @lunaDpiView.destroy()

  serialize: ->
    lunaDpiViewState: @lunaDpiView.serialize()

  toggle: ->
    console.log 'LunaDpi was toggled!'

    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()

  config:
    zoom:
      type:    'number'
      minimum: 0.375
      maximum: 3
      default: 1
      order:   1
