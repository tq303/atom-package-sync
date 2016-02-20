# atom package sync
# View Model Class
#
{ CompositeDisposable }    = require 'atom'
{ allowUnsafeNewFunction } = require 'loophole'

AtomSyncView               = require './atom-sync-view'

Http = require './http'
Package = require './package'

Help = require './help'

# npm modules
fs      = require 'fs'
os      = require 'os'
path    = require 'path'
Vue     = require 'vue'

# default variables
defaultStore  = { id: "" }
storeFileName = "#{__dirname}/../my.json"

# atom module
module.exports = AtomSync =

    atomSyncView: null
    modalPanel: null
    subscriptions: null

    activate: (state) ->

        @atomSyncView = new AtomSyncView state
        # check store exists
        if fs.existsSync storeFileName
            @savedConfig = @configToJsonObject()
        else
            @savedConfig = defaultStore

        # setup view
        @view  = @atomSyncView.getElement()

        # setup model
        @model =
            id:            @savedConfig.id
            master:        '...'
            disableUi:     false
            editLocked:    true
            makeMaster:    true
            isMaster:      true
            suggestMaster: false
            localPkgList:  []
            myJsonPkgList: []
            helpTitle:     ''
            helpMessage:   ''

        # build Vue.js
        @vue = allowUnsafeNewFunction =>
            new Vue
                el:   @view
                data: @model
                methods:
                    syncJson:      => @syncJson()
                    toggleEdit:    => @toggleEdit()
                    setMakeMaster: => @setMakeMaster()
                    setMakeSlave:  => @setMakeSlave()
                    closeUI:       => @showUI()
                    copyId:        => @copyId()
                    pasteId:       => @pasteId()
                    resetId:       => @resetId()
                    showHelp:      (option) => @showHelp(option)

        @http = new Http @model
        @pkg  = new Package(@showHelp.bind @)
        @help = Help
        @showHelp 'welcome'

        # show panel at bottom
        @modalPanel = atom.workspace.addBottomPanel(item: @view, visible: false)

        # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
        @subscriptions = new CompositeDisposable

        # Register command that toggles this view
        @subscriptions.add atom.commands.add "atom-workspace", "atom-sync:sync": => @showUI()

        # check wheter to retrieve existing configuration
        if @savedConfig.id

            @requestMyJson()

        else
            @showHelp 'No Sync available', 'warning'
            @model.myJsonPkgList = @setDefaultMyJsonObject().myJsonPkgList

    setDefaultMyJsonObject: ->
        myJsonPkgList: []
        master: os.hostname()

    deactivate: ->
        @modalPanel.destroy()
        @subscriptions.dispose()
        @atomSyncView.destroy()

    serialize: ->
        @persistId()

    configToJsonObject: ->
        JSON.parse fs.readFileSync storeFileName, 'utf8'

    persistId: ->
        fs.writeFile storeFileName, JSON.stringify
            id: @model.id

    showUI: ->
        if @modalPanel.isVisible()
          @modalPanel.hide()
        else
          @requestMyJson()
          @modalPanel.show()

    resetId: ->
        @model.id = @configToJsonObject().id

    copyId: ->
        atom.clipboard.write @model.id

    pasteId: ->
        @model.id = atom.clipboard.read()

    toggleEdit: ->
        if !@model.disableUi

            if !@model.editLocked

                # if id has changed
                if @model.id && @model.id != @savedConfig.id

                    @model.disableUi = true

                    # ensure the new id is valid
                    @http.getMyJson(@model.id)
                         .then( (syncObject) =>

                            @model.isMaster         = syncObject.master == os.hostname()
                            @model.makeMaster       = syncObject.master == os.hostname()
                            @model.master           = syncObject.master
                            @model.myJsonPkgList    = syncObject.packages
                            @model.editLocked       = true
                            @model.disableUi        = false

                            @model.suggestMaster = @pkg.requireSync(@model.myJsonPkgList, @model.localPkgList)

                            @showHelp 'New myjson.com response success', 'success'
                        )
                        .catch( (err) =>

                            @model.id            = @savedConfig.id
                            @model.editLocked    = true
                            @model.isMaster      = false
                            @model.makeMaster    = true
                            @model.disableUi     = false
                            @model.suggestMaster = false

                            @showHelp err, 'error'
                        )

                else
                    @model.editLocked = true

            else
                @model.editLocked = false

        else
            @model.editLocked = true

    setMakeMaster: ->
        @showHelp 'Machine is now master', 'warning'
        @model.makeMaster = true

    setMakeSlave: ->
        @showHelp 'Machine is now in slave mode', 'warning'
        @model.makeMaster = false

    requestMyJson: ->
        @model.disableUi = true

        @showHelp 'Validating myjson', 'warning'

        @http.getMyJson(@savedConfig.id)
            .then( (syncObject) =>

                @model.master        = syncObject.master
                @model.isMaster      = syncObject.master == os.hostname()
                @model.makeMaster    = syncObject.master == os.hostname()
                @model.myJsonPkgList = syncObject.packages

                @showHelp 'myjson.com response is valid', 'success'

                @pkg.installed()
                    .then((localPkgList)=>

                        @model.localPkgList  = localPkgList
                        @model.disableUi     = false

                        if @pkg.requireSync(@model.myJsonPkgList, @model.localPkgList)
                            @showHelp 'sync required', 'warning'
                        else
                            @showHelp 'you are up to date', 'success'

                    )

            )
            .catch( (err) =>
                @showHelp err, 'error'

                @model.master        = os.hostname()
                @model.isMaster      = true
                @model.makeMaster    = true
                @model.myJsonPkgList = @setDefaultMyJsonObject().myJsonPkgList
                @model.disableUi     = false
            )

    syncJson: ->

        @model.disableUi = true
        @model.editLocked   = true

        # decide upload / install
        if @model.makeMaster

            @showHelp 'Syncronizing...', 'warning'

            # update / save dependant on id availability
            if @model.id

                @showHelp 'Updating...', 'warning'

                @http.updateJson(@model.id, @model.localPkgList)
                     .then( () =>
                         @model.disableUi = false
                         @showHelp 'Update Successful', 'success'
                     )
                     .catch( (err)->
                         @showHelp err, 'error'
                     )
            else

                @showHelp 'Saving...', 'warning'

                @http.saveJson(@model.localPkgList)
                     .then( (body) =>
                         @model.id = path.basename body.uri
                         @model.disableUi = false
                         @persistId()
                         @showHelp 'Save Successful', 'success'
                     )
                     .catch( (err) ->
                         @showHelp err, 'error'
                     )

        else

            @pkg.installList( @model.myJsonPkgList )
                .then( () =>
                    @model.disableUi = false
                    @showHelp 'Atom modules installed', 'success'
                )
                .catch( (err) =>
                    @model.disableUi = false
                    @showHelp err, 'error'
                )

    showHelp: (option, custom = '', animate = 'fade') ->
        if option != @currentHelpOption && !custom && !@model.disableUi
            @model.helpMessage = @help[option].message
            @currentHelpOption = option
        else if custom && @help[custom]
            @model.helpMessage = @help[custom].message.replace('%s', option)
        else if !@help[option]
            @model.helpMessage = "Message type <strong>#{custom}</strong> not found."
