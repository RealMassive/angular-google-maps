angular.module("google-maps.directives.api")
.factory "Map", ["$timeout", "Logger", "GmapUtil", "BaseObject", ($timeout, Logger, GmapUtil, BaseObject) ->
        "use strict"
        $log = Logger

        DEFAULTS =
            mapTypeId: google.maps.MapTypeId.ROADMAP

        class Map extends BaseObject
            @include GmapUtil
            constructor:()->
                self = @
            restrict: "ECMA"
            transclude: true
            replace: false
            #priority: 100,
            template: "<div class=\"angular-google-map\"><div class=\"angular-google-map-container\"></div><div ng-transclude style=\"display: none\"></div></div>"

            scope:
                center: "=center" # required
                zoom: "=zoom" # required
                control: "=" # optional
                options: "=options" # optional
                events: "=events" # optional
                styles: "=styles" # optional
                bounds: "=bounds"

            controller: ["$scope", ($scope) ->
                #@return the map instance
                getMap: ->
                    $scope.map
            ]

            ###
            @param scope
            @param element
            @param attrs
            ###
            link: (scope, element, attrs) =>
                # Center property must be specified and provide lat &
                # lng properties
                if not @validateCoords(scope.center)
                    $log.error "angular-google-maps: could not find a valid center property"
                    return
                unless angular.isDefined(scope.zoom)
                    $log.error "angular-google-maps: map zoom property not set"
                    return
                el = angular.element(element)
                el.addClass "angular-google-map"

                # Parse options
                opts =
                    options: {}
                opts.options = scope.options  if attrs.options

                opts.styles = scope.styles  if attrs.styles
                if attrs.type
                    type = attrs.type.toUpperCase()
                    if google.maps.MapTypeId.hasOwnProperty(type)
                        opts.mapTypeId = google.maps.MapTypeId[attrs.type.toUpperCase()]
                    else
                        $log.error "angular-google-maps: invalid map type \"" + attrs.type + "\""

                # Create the map
                _m = new google.maps.Map(el.find("div")[1], angular.extend({}, DEFAULTS, opts,
                    center: @getCoords(scope.center)
                    draggable: @isTrue(attrs.draggable)
                    zoom: scope.zoom
                    bounds: scope.bounds
                ))
                dragging = false
                google.maps.event.addListener _m, "dragstart", ->
                    dragging = true

                google.maps.event.addListener _m, "dragend", ->
                    dragging = false


                google.maps.event.addListener _m, "idle", ->
                    b = _m.getBounds()
                    ne = b.getNorthEast()
                    sw = b.getSouthWest()
                    c = _m.center
                    z = _m.zoom
                    $timeout () ->
                            if scope.bounds isnt null and scope.bounds isnt `undefined` and scope.bounds isnt undefined
                                scope.bounds.northeast =
                                    latitude: ne.lat()
                                    longitude: ne.lng()

                                scope.bounds.southwest =
                                    latitude: sw.lat()
                                    longitude: sw.lng()

                            # update map view center
                            if scope.center && c
                                if scope.center.type
                                    scope.center.coordinates[1] = c.lat() if scope.center.coordinates[1] isnt c.lat()
                                    scope.center.coordinates[0] = c.lng() if scope.center.coordinates[0] isnt c.lng()
                                else
                                    scope.center.latitude = c.lat()  if scope.center.latitude isnt c.lat()
                                    scope.center.longitude = c.lng()  if scope.center.longitude isnt c.lng()

                            # update map view zoom
                            scope.zoom = z
                    #google.maps.event.trigger _m, "resize"

                if angular.isDefined(scope.events) and scope.events isnt null and angular.isObject(scope.events)
                    getEventHandler = (eventName) ->
                        ->
                            scope.events[eventName].apply scope, [_m, eventName, arguments]

                    #TODO: Need to keep track of listeners and call removeListener on each
                    for eventName of scope.events
                        google.maps.event.addListener _m, eventName, getEventHandler(eventName)  if scope.events.hasOwnProperty(eventName) and angular.isFunction(scope.events[eventName])

                # Put the map into the scope
                scope.map = _m
                #            google.maps.event.trigger _m, "resize"

                # check if have an external control hook to direct us manually without watches
                #this will normally be an empty object that we extend and slap functionality onto with this directive
                if attrs.control? and scope.control?
                    scope.control.refresh = (maybeCoords) =>
                        return unless _m?
                        #google.maps.event.trigger _m, "resize" #actually refresh
                        if maybeCoords?.latitude? and maybeCoords?.latitude?
                            coords = @getCoords(maybeCoords)
                            if @isTrue(attrs.pan)
                                _m.panTo coords
                            else
                                _m.setCenter coords
                    ###
                    I am sure you all will love this. You want the instance here you go.. BOOM!
                    ###
                    scope.control.getGMap = ()=>
                        _m

                # Update map when center coordinates change
                scope.$watch "center", ((newValue, oldValue) =>
                    return if not newValue
                    coords = @getCoords newValue
                    return  if coords.lat() is _m.center.lat() and coords.lng() is _m.center.lng()
                    unless dragging
                        if !@validateCoords(newValue)
                            $log.error("Invalid center for newValue: #{JSON.stringify newValue}")
                        if @isTrue(attrs.pan) and scope.zoom is _m.zoom
                            _m.panTo coords
                        else
                            _m.setCenter coords
                ), true
                scope.$watch "zoom", (newValue, oldValue) ->
                    return  if newValue is _m.zoom || typeof newValue == 'undefined' || newValue == null
                    _.defer ->
                        _m.setZoom newValue

                scope.$watch "bounds", (newValue, oldValue) ->
                    return  if newValue is oldValue
                    if !newValue.northeast.latitude? or !newValue.northeast.longitude? or !newValue.southwest.latitude? or !newValue.southwest.longitude?
                        $log.error "Invalid map bounds for new value: #{JSON.stringify newValue}"
                        return
                    ne = new google.maps.LatLng(newValue.northeast.latitude, newValue.northeast.longitude)
                    sw = new google.maps.LatLng(newValue.southwest.latitude, newValue.southwest.longitude)
                    bounds = new google.maps.LatLngBounds(sw, ne)
                    _m.fitBounds bounds

                scope.$watch "options", (newValue,oldValue) =>
                    unless _.isEqual(newValue,oldValue)
                        opts.options = newValue
                        _m.setOptions opts  if _m?
                ,true

                scope.$watch "styles", (newValue,oldValue) =>
                    unless _.isEqual(newValue,oldValue)
                        opts.styles = newValue
                        _m.setOptions opts  if _m?
                ,true

                element.on 'resize', () =>
                    google.maps.event.trigger _m, "resize"
    ]