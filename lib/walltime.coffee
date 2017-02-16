tzData = require "./walltime-data.json"
helpers = require "./olson/helpers"
Rule = require("./olson/rule").Rule
OlsonZone = require("./olson/zone")
OlsonTimeZoneTime = require './olson/timezonetime'
Zone = OlsonZone.Zone
ZoneSet = OlsonZone.ZoneSet

class WallTime
    @init: (rules = {}, zones = {}) ->
        @zones = {}
        @rules = {}
        @addRulesZones rules, zones
        @zoneSet = null
        @timeZoneName = null
        @doneInit = true

    @addRulesZones: (rules = {}, zones = {}) ->
        currZone = null
        for own zoneName, zoneVals of zones
            newZones = []
            currZone = null
            for z in zoneVals
                newZone = new Zone(z.name, z._offset, z._rule, z.format, z._until, currZone)
                newZones.push newZone
                currZone = newZone

            @zones[zoneName] = newZones

        for own ruleName, ruleVals of rules
            newRules = (new Rule(r.name, r._from, r._to, r.type, r.in, r.on, r.at, r._save, r.letter) for r in ruleVals)
            @rules[ruleName] = newRules



    @setTimeZone: (name) ->
        if !@doneInit
            throw new Error "Must call init with rules and zones before setting time zone"

        if !@zones[name]
            throw new Error "Unable to find time zone named #{name || '<blank>'}"

        matches = @zones[name]
        @zoneSet = new ZoneSet(matches, (ruleName) => @rules[ruleName])
        @timeZoneName = name

    @Date: (y, m = 0, d = 1, h = 0, mi = 0, s = 0, ms = 0) ->
        y or= new Date().getUTCFullYear()

        helpers.Time.MakeDateFromParts y, m, d, h, mi, s, ms

    @UTCToWallTime: (dt, zoneName = @timeZoneName) ->
        if typeof dt == "number"
            dt = new Date(dt)

        if zoneName != @timeZoneName
            @setTimeZone zoneName

        if !@zoneSet
            throw new Error "Must set the time zone before converting times"

        @zoneSet.getWallTimeForUTC dt

    @WallTimeToUTC: (zoneName = @timeZoneName, y, m = 0, d = 1, h = 0, mi = 0, s = 0, ms = 0) ->
        if zoneName != @timeZoneName
            @setTimeZone zoneName

        wallTime = if typeof y == "number" then helpers.Time.MakeDateFromParts y, m, d, h, mi, s, ms else y

        @zoneSet.getUTCForWallTime wallTime

    @IsAmbiguous: (zoneName = @timeZoneName, y, m, d, h, mi = 0) ->
        if zoneName != @timeZoneName
            @setTimeZone zoneName

        wallTime = if typeof y == "number" then helpers.Time.MakeDateFromParts y, m, d, h, mi else y

        @zoneSet.isAmbiguous wallTime

    @TimeZoneTime: OlsonTimeZoneTime

    @valueOf: @TimeZoneTime.prototype.getTime
    @data: tzData
    @autoinit: true

if WallTime.autoinit and WallTime.data?.rules and WallTime.data?.zones
    WallTime.init WallTime.data.rules, WallTime.data.zones
module.exports = WallTime




