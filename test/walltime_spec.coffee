should = require "should"
helpers = require "../lib/olson/helpers"
OlsonReader = require "../lib/olson/reader"
OlsonCommon = require "../lib/olson/common"
WallTime = require "../lib/walltime"
TimeZoneTime = require "../lib/olson/timezonetime"
OlsonZone = OlsonCommon.Zone
OlsonZoneSet = OlsonCommon.ZoneSet

describe "walltime-js", ->
    rules = []
    zones = []

    noSave = 
        hours: 0
        mins: 0

    dstSave = 
        hours: 1
        mins: 0

    before (next) ->
        reader = new OlsonReader

        reader.singleFile "./test/rsrc/full/northamerica", (result) ->
            should.exist result?.zones, "should have zones in result"
            should.exist result?.rules, "should have rules in result"

            rules = result.rules
            zones = result.zones

            do next

    beforeEach ->
        WallTime.rules = undefined
        WallTime.zones = undefined
        WallTime.doneInit = false

    describe "init", ->
        it "requires an init call to load the rules and zones", ->
            should.exist WallTime.init

            WallTime.init rules, zones

            WallTime.rules.should.equal rules
            WallTime.zones.should.equal zones

        it "throws an error if you fail to init with rules and zones before setting the time zone", ->

            setTimeZoneWithNoInit = -> WallTime.setTimeZone "America/Chicago"
            setTimeZoneWithNoInit.should.throw()

    describe "setTimeZone", ->
        it "allows you to set the time zone", ->
            should.exist WallTime.setTimeZone

            WallTime.init rules, zones

            WallTime.setTimeZone "America/Chicago"

            WallTime.zoneSet.name.should.equal "America/Chicago"

        it "throws an error if the time zone is not found", ->
            WallTime.init rules, zones

            emptyName = -> WallTime.setTimeZone ""
            emptyName.should.throw()

    describe "UTCToWallTime", ->

        commonWallTimeTest = (point, zoneName, expectSave, expectWallTime) ->
            WallTime.init rules, zones

            WallTime.setTimeZone zoneName

            result = WallTime.UTCToWallTime point

            result.save.hours.should.equal expectSave.hours
            result.save.mins.should.equal expectSave.mins

            result.utc.should.equal point, "UTC time"

            result.wallTime.getTime().should.equal expectWallTime.wallTime.getTime(), "WallTimes: #{result.wallTime.toUTCString()} :: #{expectWallTime.wallTime.toUTCString()}"

        ###
    # Rule  NAME    FROM    TO  TYPE    IN  ON  AT  SAVE    LETTER/S
    Rule    US  1918    1919    -   Mar lastSun 2:00    1:00    D
    Rule    US  1918    1919    -   Oct lastSun 2:00    0   S
    Rule    US  1942    only    -   Feb 9   2:00    1:00    W # War
    Rule    US  1945    only    -   Aug 14  23:00u  1:00    P # Peace
    Rule    US  1945    only    -   Sep 30  2:00    0   S
    Rule    US  1967    2006    -   Oct lastSun 2:00    0   S
    Rule    US  1967    1973    -   Apr lastSun 2:00    1:00    D
    Rule    US  1974    only    -   Jan 6   2:00    1:00    D
    Rule    US  1975    only    -   Feb 23  2:00    1:00    D
    Rule    US  1976    1986    -   Apr lastSun 2:00    1:00    D
    Rule    US  1987    2006    -   Apr Sun>=1  2:00    1:00    D
    Rule    US  2007    max -   Mar Sun>=8  2:00    1:00    D
    Rule    US  2007    max -   Nov Sun>=1  2:00    0   S

    # Rule  NAME    FROM    TO  TYPE    IN  ON  AT  SAVE    LETTER
    Rule    Chicago 1920    only    -   Jun 13  2:00    1:00    D
    Rule    Chicago 1920    1921    -   Oct lastSun 2:00    0   S
    Rule    Chicago 1921    only    -   Mar lastSun 2:00    1:00    D
    Rule    Chicago 1922    1966    -   Apr lastSun 2:00    1:00    D
    Rule    Chicago 1922    1954    -   Sep lastSun 2:00    0   S
    Rule    Chicago 1955    1966    -   Oct lastSun 2:00    0   S

    # Zone  NAME        GMTOFF  RULES   FORMAT  [UNTIL]
    Zone America/Chicago    -5:50:36 -  LMT 1883 Nov 18 12:09:24
                -6:00   US  C%sT    1920
                -6:00   Chicago C%sT    1936 Mar  1 2:00
                -5:00   -   EST 1936 Nov 15 2:00
                -6:00   Chicago C%sT    1942
                -6:00   US  C%sT    1946
                -6:00   Chicago C%sT    1967
                -6:00   US  C%sT
        ###

        firstOffset = 
            negative: true
            hours: 5
            mins: 50
            secs: 36

        sixOffset = 
            negative: true
            hours: 6
            mins: 0
            secs: 0

        fiveOffset =
            negative: true
            hours: 5
            mins: 0
            secs: 0

        it "can translate a UTC Time to Chicago Wall Time for times before the first zone line", ->
            # Before any zones
            point = helpers.Time.MakeDateFromParts 1880, 0, 1

            expect = new TimeZoneTime point, { offset: firstOffset }, noSave

            commonWallTimeTest point, "America/Chicago", noSave, expect

        it "can translate a UTC Time to Chicago Wall Time for times at the end of first zone line", ->
            # Right at the end of the first zone line
            point = helpers.Time.MakeDateFromParts 1883, 10, 18, 12, 9, 23
            point = helpers.Time.ApplyOffset point, firstOffset

            expect = new TimeZoneTime point, { offset: firstOffset }, noSave

            commonWallTimeTest point, "America/Chicago", noSave, expect

        it "can translate a UTC Time to Chicago Wall Time for times after the first zone line with -6:00 offset", ->
            # Right after the end of the first zone line
            point = helpers.Time.MakeDateFromParts 1883, 10, 18, 12, 9, 24
            # We use the first offset here because we want it to match the end of the first rule
            point = helpers.Time.ApplyOffset point, firstOffset
            
            expect = new TimeZoneTime point, { offset: sixOffset }, noSave

            commonWallTimeTest point, "America/Chicago", noSave, expect

        it "can apply daylight savings for the first US Rule zone line", ->
            # Right after the end of the first zone line
            point = helpers.Time.MakeDateFromParts 1918, 2, 31, 2, 0, 1
            point = helpers.Time.ApplyOffset point, sixOffset
            
            expect = new TimeZoneTime point, { offset: sixOffset }, dstSave

            commonWallTimeTest point, "America/Chicago", dstSave, expect

        it "can go back to standard time for the first US Rule zone line", ->
            # Right after the end of the first zone line
            point = helpers.Time.MakeDateFromParts 1918, 9, 31, 2, 0, 1
            point = helpers.Time.ApplyOffset point, sixOffset
            # Apply the save because we would be in daylight savings from the previous move
            point = helpers.Time.ApplySave point, dstSave
            
            expect = new TimeZoneTime point, { offset: sixOffset }, noSave

            commonWallTimeTest point, "America/Chicago", noSave, expect



