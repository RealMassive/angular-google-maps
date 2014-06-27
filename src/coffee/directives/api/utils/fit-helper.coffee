angular.module("google-maps.directives.api.utils")
.factory "FitHelper", ["BaseObject", "Logger", (BaseObject,$log) ->
    class FitHelper extends BaseObject
      fit: (gMarkers, gMap) ->
        if gMap and gMarkers and gMarkers.length > 0
          bounds = new google.maps.LatLngBounds();
          everSet = false
          _async.each gMarkers, (gMarker) =>
            if gMarker
              everSet = true unless everSet
              bounds.extend(gMarker.getPosition())
          , () =>
            gMap.fitBounds(bounds) if everSet

      # TODO: make calculations of BBs prety
      getBigBoundingBox: (currentViewBox, viewbox) ->
        bigBB = {
            ne: {
              lat: Math.max(currentViewBox.ne.lat, viewbox.ne.lat),
              lng: Math.max(currentViewBox.ne.lng, viewbox.ne.lng),
            },
            sw: {
              lat: Math.min(currentViewBox.sw.lat, viewbox.sw.lat),
              lng: Math.min(currentViewBox.sw.lng, viewbox.sw.lng),
            }
        }

      getSmallBoundingBox: (currentViewBox, viewbox) ->
        smallBB = {
            ne: {
              lat: Math.min(currentViewBox.ne.lat, viewbox.ne.lat),
              lng: Math.min(currentViewBox.ne.lng, viewbox.ne.lng),
            },
            sw: {
              lat: Math.max(currentViewBox.sw.lat, viewbox.sw.lat),
              lng: Math.max(currentViewBox.sw.lng, viewbox.sw.lng),
            }
        }

      getViewShiftDirection: (smallBB, currentViewBox) ->
        dirLat = 0
        dirLng = 0
        # 1 = up, 0 = no shift, -1 = down
        if smallBB.ne.lat == currentViewBox.ne.lat && smallBB.sw.lat == currentViewBox.sw.lat
            dirLat = 0
        else if smallBB.ne.lat == currentViewBox.ne.lat && smallBB.sw.lat > currentViewBox.sw.lat
            dirLat = 1
        else if smallBB.ne.lat < currentViewBox.ne.lat && smallBB.sw.lat == currentViewBox.sw.lat
            dirLat = -1

        # 1 = right, 0 = no shift, -1 = left
        if smallBB.ne.lng == currentViewBox.ne.lng && smallBB.sw.lng == currentViewBox.sw.lng
            dirLng = 0
        else if smallBB.ne.lng == currentViewBox.ne.lng && smallBB.sw.lng > currentViewBox.sw.lng
            dirLng = -1
        else if smallBB.ne.lng < currentViewBox.ne.lng && smallBB.sw.lng == currentViewBox.sw.lng
            dirLng = 1

        dir = {
          lat: dirLat,
          lng: dirLng
        }

      getBBLat: (bigBB, smallBB, dir) ->
        if dir.lat == 1 # view shifted up
            BB =
              ne:
                lat: smallBB.sw.lat
              sw:
                lat: bigBB.sw.lat
        else if dir.lat == -1 # view shifted down
            BB =
              ne:
                lat: bigBB.ne.lat
              sw:
                lat: smallBB.ne.lat
        if BB
            BB.ne.lng = smallBB.ne.lng
            BB.sw.lng = smallBB.sw.lng
        BB

      getBBLng: (bigBB, smallBB, dir) ->
        if dir.lng == 1 # view shifted right
            BB =
              ne:
                lng: bigBB.ne.lng
              sw:
                lng: smallBB.ne.lng
        else if dir.lng == -1 # view shifted left
            BB =
              ne:
                lng: smallBB.sw.lng
              sw:
                lng: bigBB.sw.lng
        if BB
            BB.ne.lat = smallBB.ne.lat
            BB.sw.lat = smallBB.sw.lat
        BB

      getBBLatLng: (bigBB, smallBB, dir) ->
        if dir.lat == 1 && dir.lng == 1 # view shifted up and right
          BB =
            ne:
              lat:
                smallBB.sw.lat
              lng:
                bigBB.ne.lng
            sw:
              lat:
                bigBB.sw.lat
              lng:
                smallBB.ne.lng
        else if dir.lat == 1 && dir.lng == -1 # view shifted up and left
          BB =
            ne:
                smallBB.sw
            sw:
                bigBB.sw
        else if dir.lat == -1 && dir.lng == -1 # view shifted down and left
          BB =
            ne:
              lat:
                bigBB.ne.lat
              lng:
                smallBB.sw.lng
            sw:
              lat:
                smallBB.ne.lat
              lng:
                bigBB.sw.lng
        else if dir.lat == -1 && dir.lng == 1 # view shifted down and right
          BB =
            ne:
                bigBB.ne
            sw:
                smallBB.ne
        BB

      getBBAll: (bigBB, smallBB) ->
        regions = []
        # right top
        regions.push
          ne:
            bigBB.ne
          sw:
            lat:
              smallBB.sw.lat
            lng:
              smallBB.ne.lng
        # right bottom
        regions.push
          ne:
            lat:
              smallBB.sw.lat
            lng:
              bigBB.ne.lng
          sw:
            lat:
              bigBB.sw.lat
            lng:
              smallBB.sw.lng
        # left bottom
        regions.push
          ne:
            lat:
              smallBB.ne.lat
            lng:
              smallBB.sw.lng
          sw:
            bigBB.sw
        # left top
        regions.push
          ne:
            lat:
              bigBB.ne.lat
            lng:
              smallBB.ne.lng
          sw:
            lat:
              smallBB.ne.lat
            lng:
              bigBB.sw.lng
        #return regions
        regions

      getUpdateRegions: (currentViewBox, viewBox, dirty, zoom) ->
        remove = []
        update = []
        if zoom == 0
            bigBB = @getBigBoundingBox currentViewBox, viewBox
            smallBB = @getSmallBoundingBox currentViewBox, viewBox

            dirRM = @getViewShiftDirection smallBB, currentViewBox
            console.log dirRM
            dirADD = { lat: -dirRM.lat, lng: -dirRM.lng }

            removeBBLat = @getBBLat bigBB, smallBB, dirRM
            remove.push removeBBLat if removeBBLat?
            removeBBLng = @getBBLng bigBB, smallBB, dirRM
            remove.push removeBBLng if removeBBLng?
            removeBBLatLng = @getBBLatLng bigBB, smallBB, dirRM
            remove.push removeBBLatLng if removeBBLatLng?

            updateBBLat = @getBBLat bigBB, smallBB, dirADD
            update.push updateBBLat if updateBBLat?
            updateBBLng = @getBBLng bigBB, smallBB, dirADD
            update.push updateBBLng if updateBBLng?
            updateBBLatLng = @getBBLatLng bigBB, smallBB, dirADD
            update.push updateBBLatLng if updateBBLatLng?

        else if zoom > 0
          update = @getBBAll viewBox, currentViewBox
        else if zoom < 0
          remove = @getBBAll currentViewBox, viewBox

        update.push smallBB if dirty

        {
          remove: remove
          add: update
        }
  ]
