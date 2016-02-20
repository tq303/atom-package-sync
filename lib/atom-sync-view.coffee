fs   = require 'fs'
path = require 'path'

module.exports =
class AtomSyncView
    constructor: (serializedState) ->
        # Create root element
        @element = document.createElement('div')
        @element.classList.add('atom-sync')
        @element.innerHTML = fs.readFileSync(path.join(__dirname, '../templates/settings.html'))

    # Returns an object that can be retrieved when package is activated
    serialize: ->

    # Tear down any state and detach
    destroy: ->
        @element.remove()

    getElement: ->
        @element
