angular.module("google-maps.directives.api.managers")
.factory "MarkerManager", ["Logger", "FitHelper", "MarkerChildModel", "$timeout", (Logger, FitHelper, MarkerChildModel, $timeout) ->
    class MarkerManager extends FitHelper
      @include FitHelper
      constructor: (@gMap, @parentScope, @DEFAULTS, @doClick, @idKey) ->
        super()
        self = @
        @gMarkers = new GeoTree()
        @markersInView = []
        @$log = Logger
        @$log.info(@)
        @currentViewBox
        @dirty = true

      add: (model, optDraw)=>
        @gMarkers.insert model.geo.latitude, model.geo.longitude, {data: {model: model}}
        @dirty = true

      addMany: (models)=>
        @add(model) for model in models

      remove: (model, optDraw)=>
        # TODO: implement remove
        @dirty = true

      removeMany: (models)=>
        @remove(model) for model in models

      draw: (viewBox, zoom)=>
        viewBox = @currentViewBox if not viewBox
        return unless viewBox

        if not @currentViewBox
          @currentViewBox = viewBox
          @dirty = true

        if not @zoom
          @zoom = zoom

        added = 0
        removed = 0
        # hide markers which are not in the view anymore
        updateRegions = @getUpdateRegions @currentViewBox, viewBox, @dirty, @zoom - zoom
        start = new Date()
        for region in updateRegions.remove
          markers = @gMarkers.find region.ne, region.sw
          removed += markers.length
          for marker in markers
            data = marker.data
            if data
              @show data.gMarker, false
              marker.visible = false
        end = new Date()

        # show markers which are new in view
        start = new Date()
        for region in updateRegions.add
          markers = @gMarkers.find region.ne, region.sw
          added += markers.length
          for marker in markers
            if not marker.data.gMarker
              data = new MarkerChildModel(marker.data.model, @parentScope, @map, @DEFAULTS, @doClick, @idKey)
              marker.data = data
            if not marker.visible
              @show marker.data.gMarker, true
              marker.visible = true
        end = new Date()

        @currentViewBox = viewBox
        @dirty = false
        @zoom = zoom

      clear: =>
        @gMarkers.forEach (marker) ->
            marker.data.gMarker.setMap null if marker.data.gMarker
        delete @gMarkers
        @gMarkers = new GeoTree()

      show: (gMarker, show)=>
        if show
            if not gMarker.getMap()
                gMarker.setMap(@gMap)
            if not gMarker.getVisible()
                gMarker.setVisible true
        else
            gMarker.setVisible(false) if gMarker
        undefined
  
      # TODO: fit markers
      fit: ()=>
        super @gMarkers,@gMap

    MarkerManager
  ]