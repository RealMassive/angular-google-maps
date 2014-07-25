angular.module("google-maps.directives.api.models.child")
.factory "MarkerChildModel", [ "ModelKey", "GmapUtil", "Logger", "$injector", "MarkerEventHelper",
    (ModelKey, GmapUtil, Logger, $injector, MarkerEventHelper) ->
      class MarkerChildModel extends ModelKey
        @include GmapUtil
        @include MarkerEventHelper
        constructor: (@model, @parentScope, @gMap, @defaults, @doClick, @idKey)->
          self = @
          @id = @model[@idKey] if @model[@idKey]
          @iconKey = @parentScope.icon
          @coordsKey = @parentScope.coords
          @clickKey = @parentScope.click()
          @labelContentKey = @parentScope.labelContent
          @optionsKey = @parentScope.options
          @labelOptionsKey = @parentScope.labelOptions

          super(@parentScope.$new(false))

          @scope.model = @model
          @setMyScope(@model, undefined, true)
          @createMarker(@model)

          @scope.$watch 'model', (newValue, oldValue) =>
            if (newValue != oldValue)
              @setMyScope(newValue, oldValue)
          , true

          @$log = Logger
          @$log.info(self)
          @watchDestroy(@scope)

        setMyScope: (model, oldModel = undefined, isInit = false) =>
          @maybeSetScopeValue('icon', model, oldModel, @iconKey, @evalModelHandle, isInit, @setIcon)
          @maybeSetScopeValue('coords', model, oldModel, @coordsKey, @evalModelHandle, isInit, @setCoords)
          @maybeSetScopeValue('labelContent', model, oldModel, @labelContentKey, @evalModelHandle, isInit)
          if _.isFunction(@clickKey) and $injector
            @scope.click = () =>
              $injector.invoke(@clickKey, undefined, {"$markerModel": model})
          else
            @maybeSetScopeValue('click', model, oldModel, @clickKey, @evalModelHandle, isInit)
            @createMarker(model, oldModel, isInit)

        createMarker: (model, oldModel = undefined, isInit = false)=>
          @maybeSetScopeValue 'options', model, oldModel, @optionsKey, (lModel, lModelKey) =>
            if lModel == undefined
              return undefined
            value = if lModelKey == 'self' then lModel else lModel[lModelKey]
            if value == undefined # we still dont have a value see if this is something up the tree or default it
              value = if lModelKey == undefined then @defaults else @scope.options
            else
              value
          , isInit, @setOptions


        maybeSetScopeValue: (scopePropName, model, oldModel, modelKey, evaluate, isInit, gSetter = undefined) =>
          if oldModel == undefined
            @scope[scopePropName] = evaluate(model, modelKey)
            unless isInit
              gSetter(@scope) if gSetter?
            return

          oldVal = evaluate(oldModel, modelKey)
          newValue = evaluate(model, modelKey)
          if(newValue != oldVal and @scope[scopePropName] != newValue)
            @scope[scopePropName] = newValue
            unless isInit
              gSetter(@scope) if gSetter?

        destroy: () =>
          @scope.$destroy()

        setCoords: (scope) =>
          if(scope.$id != @scope.$id or @gMarker == undefined)
            return
          if (scope.coords?)
            if !@validateCoords(@scope.coords)
              @$log.error "MarkerChildMarker cannot render marker as scope.coords as no position on marker: #{JSON.stringify @model}"
              return
            @gMarker.setPosition(@getCoords(scope.coords))
            @gMarker.setVisible(@validateCoords(scope.coords))
          else
            @gMarkerManager.remove(@gMarker)

        setIcon: (scope) =>
          if(scope.$id != @scope.$id or @gMarker == undefined)
            return
          @gMarker.setIcon(scope.icon)
          @gMarker.setPosition(@getCoords(scope.coords))
          @gMarker.setVisible(@validateCoords(scope.coords))

        setOptions: (scope) =>
          if(scope.$id != @scope.$id)
            return

          if @gMarker?
            delete @gMarker
          unless scope.coords ? scope.icon? scope.options?
            return
          @opts = @createMarkerOptions(scope.coords, scope.icon, scope.options)

          if @isLabelDefined(scope)
            @gMarker = new MarkerWithLabel(@setLabelOptions(@opts, scope))
          else
            @gMarker = new google.maps.Marker(@opts)

          # save reference to model
          @gMarker.model = @model

          @setEvents @gMarker, @parentScope, @model

          @gMarker.key = @id if @id

          google.maps.event.addListener @gMarker, 'click', =>
            if @doClick and @scope.click?
              @scope.click()

        isLabelDefined: (scope) =>
          scope.labelContent?

        setLabelOptions: (opts, scope) =>
          opts.labelAnchor = @getLabelPositionPoint(scope.labelAnchor)
          opts.labelClass = scope.labelClass
          opts.labelContent = scope.labelContent
          opts

        watchDestroy: (scope)=>
          scope.$on "$destroy", =>
            if (@gMarker && @gMarkerManager)? #this is possible due to _async in that we created some Children but no gMarker yet
              google.maps.event.clearListeners @gMarker, 'click'
              if @parentScope?.events and _.isArray @parentScope.events
                @parentScope.events.forEach (event, eventName) ->
                  google.maps.event.clearListeners @gMarker, eventName
              @gMarkerManager.remove @gMarker, true
              delete @gMarker
            self = undefined
      MarkerChildModel
  ]