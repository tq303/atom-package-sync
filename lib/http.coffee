##
# Separate HTTP requests into separate class
myJsonUrl     = "https://api.myjson.com/bins"

q       = require 'q'
fs      = require 'fs'
os      = require 'os'
path    = require 'path'
request = require 'request'

module.exports =
    class Http
        constructor: () ->

        getMyJson: (id) ->
            $q = q.defer()

            request
                method: 'GET'
                uri: "#{myJsonUrl}/#{id}"
                json: true
            , (err, res, myjsonObject) =>
                if err == null && res.statusCode == 200 && @validateJSON myjsonObject
                    return $q.resolve myjsonObject
                else
                    return $q.reject 'ID is incorrect'

            $q.promise


        # check package present and update packages
        mergeJson: (localPkgList = []) ->

        validateJSON: (object) ->
            typeof object.master == 'string' && object.packages.length

        # save to myJSON.com
        saveJson: (savePkgList) ->
            $q = q.defer()

            request
                method: 'POST'
                uri: "#{myJsonUrl}"
                json: true
                body:
                    master:   os.hostname()
                    packages: savePkgList
            , (err, res, body) =>
                if !err
                    $q.resolve body
                else
                    $q.reject body.message

            $q.promise

        # update exisiting myJSON.com
        updateJson: (id, updatePkgList) ->
            $q = q.defer()

            request
                method: 'PUT'
                uri: "#{myJsonUrl}/#{id}"
                json: true
                body:
                    master:   os.hostname()
                    packages: updatePkgList
            , (err, res, body) =>
                if !err
                    $q.resolve body
                else
                    $q.reject body.message

            $q.promise
