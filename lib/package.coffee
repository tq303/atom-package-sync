##
# Separate PACKAGE functions into separate class
{ BufferedNodeProcess } = require 'atom'

q       = require 'q'
fs      = require 'fs'
path    = require 'path'

module.exports =
    class Packages
        constructor: (showHelp) ->
            @showHelp = showHelp

        # get package list and convert to array, showing non empty entries
        installed: ->
            console.log 'reading package list'

            $q = q.defer()

            bufferProcess = new BufferedNodeProcess
                command: path.join(__dirname, '..', '/apm/list.js')
                args: []
                options:
                    encoding: 'utf8'
                stdout: (output) -> $q.resolve output.split("\n").filter((pkg) -> pkg.indexOf('@') >= 0 && pkg.indexOf('atom-sync') == -1)
                stderr: (err)    -> $q.reject err
                exit:   (code)   -> console.log "apm/list.js :: exited with #{code}"

            $q.promise

        # check to see whether machine has more pacakges
        requireSync: (myJson, myPackages) ->

            # split into package and version
            mpMyJson = myJson.map (p)->
                p = p.split('@')
                pkg: p[0]
                ver: p[1]

            mpMyPackages = myPackages.map (p)->
                p = p.split('@')
                pkg: p[0]
                ver: p[1]

            # check all myjson pacakges are installed
            mpMyJson.filter( (mj)-> mpMyPackages.filter( (lc)-> mj.pkg == lc.pkg ).length == 0).length


        installList: (packageList) ->
            console.log 'installing package list'

            packageList = packageList.map(( p ) ->

                @showHelp "installing :: #{p}", 'warning'

                defer = q.defer()

                bufferProcess = new BufferedNodeProcess
                    command: path.join(__dirname, '..', '/apm/install.js')
                    args: [ p ]
                    options:
                        encoding: 'utf8'
                    stderr: (err) =>
                        @showHelp "error :: #{p}", 'error'
                    exit:   (code) ->
                        defer.resolve code

                defer.promise

            )

            q.all packageList.reduce((p, next)-> p.then(next))
