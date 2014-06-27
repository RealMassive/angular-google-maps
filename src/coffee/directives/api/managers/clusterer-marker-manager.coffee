angular.module("google-maps.directives.api.managers")
.factory "ClustererMarkerManager", ["Logger", "FitHelper", "MarkerChildModel", ($log, FitHelper, MarkerChildModel) ->
    class ClustererMarkerManager extends FitHelper
      constructor: (gMap, opt_markers, opt_options, @opt_events, @parentScope, @DEFAULTS, @doClick, @idKey) ->
        super()
        self = @
        @opt_options = opt_options
        if opt_options? and opt_markers == undefined
          @clusterer = new MarkerClusterer(gMap, undefined, opt_options)
        else if opt_options? and opt_markers?
          @clusterer = new MarkerClusterer(gMap, opt_markers, opt_options)
        else
          @clusterer = new MarkerClusterer(gMap)

        @attachEvents @opt_events, "opt_events"

        @clusterer.setIgnoreHidden(true)
        @noDrawOnSingleAddRemoves = true
        $log.info(@)
        @gMarkers = new GeoTree()
        @currentViewBox
        @dirty = true

      add: (model)=>
        @gMarkers.insert model.geo.latitude, model.geo.longitude, {data: {model: model}}
        @dirty = true
        #@clusterer.addModel(gMarker, @noDrawOnSingleAddRemoves)
      addMany: (models)=>
        @add(model) for model in models
        #@clusterer.addModels(gMarkers)
      remove: (model)=>
        #@clusterer.removeMarker(gMarker, @noDrawOnSingleAddRemoves)
      removeMany: (models)=>
        @remove(model) for model in models
        #@clusterer.removeModels(gMarkers)

      draw: (viewBox, zoom) =>
        return unless viewBox

        if not @currentViewBox
          @currentViewBox = viewBox
          @dirty = true

        if not @zoom
          @zoom = zoom

        added = 0

        updateRegions = @getUpdateRegions @currentViewBox, viewBox, @dirty, @zoom - zoom
        # show markers which are new in view
        start = new Date()
        for region in updateRegions.add
          markers = @gMarkers.find region.ne, region.sw
          added += markers.length
          for marker in markers
            if not marker.data.gMarker
              data = new MarkerChildModel(marker.data.model, @parentScope, @map, @DEFAULTS, @doClick, @idKey)
              data.gMarker.setVisible true
              marker.data = data
            if not marker.visible
              @clusterer.addMarker marker.data.gMarker, true
              marker.visible = true
        end = new Date()
        console.log 'update time: ' + (end - start) / 1000 + 's'

        @currentViewBox = viewBox
        @dirty = false
        @zoom = zoom
        console.log 'added: ' + added + ' markers'

        @clusterer.repaint()

      clear: ()=>
        @clusterer.clearMarkers()
        @clusterer.repaint()
        @gMarkers.forEach (marker) ->
            marker.data.gMarker.setMap null if marker.data.gMarker
        delete @gMarkers
        @gMarkers = new GeoTree()

      attachEvents:(options, optionsName) ->
        if angular.isDefined(options) and options? and angular.isObject(options)
          for eventName, eventHandler of options
            if options.hasOwnProperty(eventName) and angular.isFunction(options[eventName])
              $log.info "#{optionsName}: Attaching event: #{eventName} to clusterer"
              google.maps.event.addListener @clusterer, eventName, options[eventName]

      clearEvents:(options) ->
        if angular.isDefined(options) and options? and angular.isObject(options)
          for eventName, eventHandler of options
            if options.hasOwnProperty(eventName) and angular.isFunction(options[eventName])
              $log.info "#{optionsName}: Clearing event: #{eventName} to clusterer"
              google.maps.event.clearListeners @clusterer, eventName

      destroy: =>
        @clearEvents @opt_events
        @clearEvents @opt_internal_events
        @clear()

      fit: ()=>
        super @clusterer.getMarkers() , @clusterer.getMap()

    ClustererMarkerManager
  ]