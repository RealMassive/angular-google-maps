angular.module("google-maps.directives.api.models.parent")
.factory "MarkersParentModel", ["IMarkerParentModel", "ModelsWatcher", "PropMap", "ClustererMarkerManager", "MarkerManager",
    (IMarkerParentModel, ModelsWatcher, PropMap, ClustererMarkerManager, MarkerManager) ->
        class MarkersParentModel extends IMarkerParentModel
            @include ModelsWatcher
            constructor: (scope, element, attrs, mapCtrl, $timeout) ->
                super(scope, element, attrs, mapCtrl, $timeout)
                self = @
                @$timeout = $timeout
                @$log.info @
                #assume do rebuild all is false and were lookging for a modelKey prop of id
                @doRebuildAll = if @scope.doRebuildAll? then @scope.doRebuildAll else true
                @setIdKey scope
                @scope.$watch 'doRebuildAll', (newValue, oldValue) =>
                    if (newValue != oldValue)
                        @doRebuildAll = newValue
                @viewInProgress = false

            onTimeOut: (scope)=>
                #watch all the below properties with end up being processed by onWatch below
                @watch('models', scope, false)
                @watch('doCluster', scope)
                @watch('clusterOptions', scope)
                @watch('clusterEvents', scope)
                @watch('fit', scope)
                @watch('idKey', scope)
                @gMarkerManager = undefined
                @createMarkersFromScratch(scope)
                _mySelf = @
                @map = @mapCtrl.getMap()
                #google.maps.event.addListener @map, "drag", ->
                #    if _mySelf.dirty(_mySelf)
                #        _mySelf.updateView _mySelf, scope
                #google.maps.event.addListener @map, "zoom_changed", ->
                #    if _mySelf.dirty(_mySelf)
                #        _mySelf.updateView _mySelf, scope
                google.maps.event.addListener @map, "idle", ->
                    if _mySelf.isMapResized() || !_mySelf.initialized
                        # during first idle, force redraw map
                        _mySelf.redrawMap _mySelf.map
                        _mySelf.initialized = true
                    else
                        _mySelf.updateView _mySelf, scope
                $(window).resize ->
                    _mySelf.$timeout ->
                        if _mySelf.initialized
                            _mySelf.initialized = false
                            google.maps.event.trigger _mySelf.map, "resize"

            isMapResized: () =>
                $googleMap = @element.parents '.google-map'
                if(!$googleMap.length)
                    return false

                newWidth = $googleMap.width()
                newHeight = $googleMap.height()

                ret = false
                if newWidth != @mapWidth || newHeight != @mapHeight
                    @mapWidth = newWidth
                    @mapHeight = newHeight
                    google.maps.event.trigger this.map, "resize"
                    ret = true
                ret

            onWatch: (propNameToWatch, scope, newValue, oldValue) =>
                if propNameToWatch == "idKey" and newValue != oldValue
                    @idKey = newValue
                if @doRebuildAll
                    @reBuildMarkers(scope)
                else
                    @pieceMealMarkers(scope)


            validateScope: (scope)=>
                modelsNotDefined = angular.isUndefined(scope.models) or scope.models == undefined
                if(modelsNotDefined)
                    @$log.error(@constructor.name + ": no valid models attribute found")

                super(scope) or modelsNotDefined

            redrawMap: (map) =>
                if @updateInProgress()
                    return
                boundary = @mapBoundingBox map
                zoom = map.zoom
                if boundary and zoom
                    @fixBoundaries boundary
                    @gMarkerManager.redraw boundary, zoom
                @inProgress = false

            createMarkersFromScratch: (scope) =>
                if scope.doCluster
                    if scope.clusterEvents
                      @clusterInternalOptions = do _.once =>
                          self = @
                          unless @origClusterEvents
                              @origClusterEvents =
                                  click: scope.clusterEvents?.click
                                  mouseout: scope.clusterEvents?.mouseout
                                  mouseover: scope.clusterEvents?.mouseover
                              _.extend scope.clusterEvents,
                                  click:(cluster) ->
                                      self.maybeExecMappedEvent cluster, "click"
                                  mouseout:(cluster) ->
                                      self.maybeExecMappedEvent cluster, "mouseout"
                                  mouseover:(cluster) ->
                                    self.maybeExecMappedEvent cluster, "mouseover"

                    if scope.clusterOptions or scope.clusterEvents
                        if @gMarkerManager == undefined
                            @gMarkerManager = new ClustererMarkerManager @mapCtrl.getMap(),
                                    undefined,
                                    scope.clusterOptions,
                                    @clusterInternalOptions,
                                    scope,
                                    @DEFAULTS,
                                    @doClick,
                                    @idKey
                        else
                            if @gMarkerManager.opt_options != scope.clusterOptions
                                @gMarkerManager = new ClustererMarkerManager @mapCtrl.getMap(),
                                      undefined,
                                      scope.clusterOptions,
                                      @clusterInternalOptions,
                                      scope,
                                      @DEFAULTS,
                                      @doClick,
                                      @idKey
                    else
                        @gMarkerManager = new ClustererMarkerManager(@mapCtrl.getMap())
                else
                    @gMarkerManager = new MarkerManager(@mapCtrl.getMap(), scope, @DEFAULTS, @doClick, @idKey)

                @gMarkerManager.addMany scope.models
                @fit(scope.models) if scope.fit
                @redrawMap @mapCtrl.getMap()

            mapBoundingBox: (map) =>
                if map
                    b = map.getBounds()
                    if b
                        ne = b.getNorthEast()
                        sw = b.getSouthWest()
                        boundary = { ne: {
                                lat: ne.lat(),
                                lng: ne.lng()
                            }, sw: {
                                lat: sw.lat(),
                                lng: sw.lng()
                            } }
                boundary

            dirty: (_mySelf) =>
                center = _mySelf.map.getCenter()
                zoom = _mySelf.map.getZoom()
                if not _mySelf.center || _mySelf.center != center || not _mySelf.zoom || _mySelf.zoom != zoom
                    _mySelf.center = center
                    _mySelf.zoom = zoom
                    return true
                false

            fixBoundaries: (boundary) =>
                if boundary.ne.lng < boundary.sw.lng
                    boundary.sw.lng = if boundary.ne.lng > 0 then -180 else 180

            updateInProgress: () =>
                now = new Date()
                if now - @lastUpdate <= 250
                    return true
                if @inProgress
                    return true
                @inProgress = true
                @lastUpdate = now
                return false

            updateView: (_mySelf, scope) =>
                if @updateInProgress()
                    return

                map = _mySelf.map
                boundary = _mySelf.mapBoundingBox map
                if not boundary
                    _mySelf.inProgress = false
                    return true

                zoom = _mySelf.map.zoom
                _mySelf.fixBoundaries boundary
                _mySelf.gMarkerManager.draw boundary, zoom
                _mySelf.inProgress = false


            reBuildMarkers: (scope) =>
                if(!scope.doRebuild and scope.doRebuild != undefined)
                    return
                @onDestroy(scope) #clean @scope.markerModels
                @createMarkersFromScratch(scope)

            pieceMealMarkers: (scope)=>
                if @scope.models? and @scope.models.length > 0 and @scope.markerModels.length > 0 #and @scope.models.length == @scope.markerModels.length
                    #find the current state, async operation that calls back
                    @figureOutState @idKey, scope, @scope.markerModels, @modelKeyComparison, (state) =>
                        payload = state
                        #payload contains added, removals and flattened (existing models with their gProp appended)
                        #remove all removals clean up scope (destroy removes itself from markerManger), finally remove from @scope.markerModels
                        _async.each payload.removals, (child)=>
                            if child?
                                child.destroy()
                                @scope.markerModels.remove(child.id)
                        , () =>
                            #add all adds via creating new ChildMarkers which are appended to @scope.markerModels
                            _async.each payload.adds, (modelToAdd) =>
                                @newChildMarker(modelToAdd, scope)
                            , () =>
                                #finally redraw
                                @gMarkerManager.draw()
                                scope.markerModels = @scope.markerModels #for other directives like windows
                else
                    @reBuildMarkers(scope)

            newChildMarker: (model, scope)=>
                unless model[@idKey]?
                    @$log.error("Marker model has no id to assign a child to. This is required for performance. Please assign id, or redirect id to a different key.")
                    return
                @$log.info('child', child, 'markers', @scope.markerModels)
                child = new MarkerChildModel(model, scope, @mapCtrl, @$timeout, @DEFAULTS,
                    @doClick, @gMarkerManager, @idKey)
                child.inView = false
                @scope.markerModels.put(model[@idKey], child) #major change this makes model.id a requirement
                child

            onDestroy: (scope)=>
                #need to figure out how to handle individual destroys
                #slap index to the external model so that when they pass external back
                #for destroy we have a lookup?
                #this will require another attribute for destroySingle(marker)
                @gMarkerManager.clear(true)
                showMarker = @gMarkerManager.showMarker if @gMarkerManager?
                _.each @markersInView, (marker) ->
                    data = marker.data
                    if (showMarker && data && data.gMarker)?
                        showMarker data.gMarker, false
                #_.each @scope.markerModels.values(), (model)->
                #    if (showMarker && model.gMarker && model.inView)?
                #        showMarker model.gMarker, false
                #    model.destroy() if (model.destroy)?
                delete @scope.markerModels
                @scope.markerModels = new GeoTree()

            maybeExecMappedEvent:(cluster, fnName) ->
              if _.isFunction @scope.clusterEvents?[fnName]
                pair = @mapClusterToMarkerModels cluster
                @origClusterEvents[fnName](pair.cluster,pair.mapped) if @origClusterEvents[fnName]

            mapClusterToMarkerModels:(cluster) ->
                gMarkers = cluster.getMarkers()
                mapped = gMarkers.map (gMarker) =>
                    gMarker.data.model
                cluster: cluster
                mapped: mapped

            fit: (models) ->
                if models && models.length > 0
                    bounds = new google.maps.LatLngBounds();
                    everSet = false
                    _async.each models, (model) =>
                        everSet = true unless everSet
                        bounds.extend(new google.maps.LatLng(model.geo.latitude, model.geo.longitude))
                    , () =>
                        @map.fitBounds(bounds) if everSet

        return MarkersParentModel
]