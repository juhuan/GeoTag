//
//  MapViewController.swift
//  GeoTag
//
//  Created by Marco S Hyman on 7/17/14.
//  Copyright 2014-2018 Marco S Hyman
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in the
// Software without restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
// Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
// AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Cocoa
import MapKit

@objc
class MapViewController: NSViewController {

    var clickDelegate: MapViewDelegate?

    @IBOutlet var mapView: MapView!
    @IBOutlet var mapTypeControl: NSSegmentedControl!
    @IBOutlet weak var search: NSSearchField!

    /// Search Field Recents Menu
    lazy var searchesMenu: NSMenu = {
        let menu = NSMenu(title: "Recents")
        let i1 = menu.addItem(withTitle: "Recents Search", action: nil, keyEquivalent: "")
        i1.tag = Int(NSSearchField.recentsTitleMenuItemTag)
        let i2 = menu.addItem(withTitle: "Item", action: nil, keyEquivalent: "")
        i2.tag = Int(NSSearchField.recentsMenuItemTag)
        let i3 = menu.addItem(withTitle: "Clear", action: nil, keyEquivalent: "")
        i3.tag = Int(NSSearchField.clearRecentsMenuItemTag)
        let i4 = menu.addItem(withTitle: "No Recent Search", action: nil, keyEquivalent: "")
        i4.tag = Int(NSSearchField.noRecentsMenuItemTag)
        return menu
    }()

    // user defaults keys for map configuration
    let mapTypeKey = "MapType"
    let cameraCenterLatitudeKey = "CameraCenterLatitudeKey"
    let cameraCenterLongitudeKey = "CameraCenterLongitudeKey"
    let cameraAltitudeKey = "CameraAltitudeKey"

    // program mapping between MKMapType and segment control selected segment
    let mapTypeStandard = 0
    let mapTypeHybrid = 1
    let mapTypeSatellite = 2

    // Only one point on the map at a time (for now, anyway)
    // This is the point
    var mapPin: MKPointAnnotation?

    // track logs
    var mapLines = [MKPolyline]()

    /// startup

    override
    func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
    }

    // final initialization for the mapView
    override
    func awakeFromNib() {
        let defaults = UserDefaults.standard
        mapTypeControl.selectedSegment = defaults.integer(forKey: mapTypeKey)
        changeMapType(mapTypeControl)
        // set up map from save info
        var center: CLLocationCoordinate2D
        var altitude = defaults.double(forKey: cameraAltitudeKey)
        if (altitude > 0) {
            let latitude = defaults.double(forKey: cameraCenterLatitudeKey)
            let longitude = defaults.double(forKey: cameraCenterLongitudeKey)
            center = CLLocationCoordinate2D(latitude: latitude,
                                            longitude: longitude)
        } else {
            // hard coded default location (SF peninsula)
            altitude = 50000.0
            center = CLLocationCoordinate2D(latitude: 37.7244,
                                            longitude: -122.4381)
        }
        mapView.camera = MKMapCamera(lookingAtCenter: center,
                                     fromEyeCoordinate: center,
                                     eyeAltitude: altitude)
        search.searchMenuTemplate = searchesMenu
    }

    // MARK: Map control actions

    /// action to select the desired map type
    @IBAction
    func changeMapType(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case mapTypeStandard:
            mapView.mapType = .standard
        case mapTypeHybrid:
            mapView.mapType = .hybrid
        case mapTypeSatellite:
            mapView.mapType = .satellite
        case let type:
            unexpected(error: nil, "Unknown segment item \(type), sender \(sender)")
        }
    }

    /// action save the current map type and displayed region
    @IBAction
    func saveMapSetting(_: AnyObject) {
        let defaults = UserDefaults.standard
        var mapTypeAsInt = 0
        switch mapView.mapType {
        case .standard:
            mapTypeAsInt = mapTypeStandard
        case .hybrid:
            mapTypeAsInt = mapTypeHybrid
        case .satellite:
            mapTypeAsInt = mapTypeSatellite
        case let type:
            print("Unknown map type \(type)")
        }
        defaults.set(mapTypeAsInt, forKey: mapTypeKey)

        // save the current region as its component parts
        defaults.set(mapView.camera.centerCoordinate.latitude,
                     forKey: cameraCenterLatitudeKey)
        defaults.set(mapView.camera.centerCoordinate.longitude,
                     forKey: cameraCenterLongitudeKey)
        defaults.set(mapView.camera.altitude,
                     forKey: cameraAltitudeKey)
    }

    // action to search
    @IBAction
    func searchMapLocation(_ sender: NSSearchField) {
        if !sender.stringValue.isEmpty {
            let geocoder = CLGeocoder()
            geocoder.geocodeAddressString(sender.stringValue) {
                placeMark, error in
                if error == nil,
                   let location = placeMark?[0].location {
                    self.pinMapAt(coords: location.coordinate,
                                  dropPin: false)
                }
            }
        }
    }

    // MARK: Map pin related functions

    /// center the map as the given latitude/longitude and drop
    /// a pin at that location
    func pinMapAt(coords: Coord,
                  dropPin: Bool = true) {
        let point = MKMapPointForCoordinate(coords);
        if !MKMapRectContainsPoint(mapView.visibleMapRect, point) {
            mapView.setCenter(coords, animated: false)
        }
        // if an image is selected and a pin exists, move it.
        // Otherwise create a new pin
        if dropPin {
            if let pin = mapPin {
                pin.coordinate = coords;
            } else {
                mapPin = MKPointAnnotation()
                if let pin = mapPin {
                    pin.coordinate = coords;
                    pin.title = "coords"
                    mapView.addAnnotation(pin)
                } else {
                    unexpected(error: nil, "Can't create map pin")
                }
            }
        }
    }

    // remove the pin from the map
    func removeMapPin() {
        if let pin = mapPin {
            mapView.removeAnnotation(pin)
            mapPin = nil
        }
    }

    // MARK: track log

    /// add tracks to the map.  Track segments are turned into polylines and
    /// added to the map view
    func addTracks(gpx: Gpx) {
        gpx.tracks.forEach {
            $0.segments.forEach {
                var trackCoords = $0.points.map {
                    return CLLocationCoordinate2D(latitude: $0.lat,
                                                  longitude: $0.lon)
                }
                let mapLine = MKPolyline(coordinates: &trackCoords,
                                         count: $0.points.count)
                mapLines.append(mapLine)
                mapView.add(mapLine)
            }
        }
    }

}

extension MapViewController: MKMapViewDelegate {

    /// return a pinAnnotationView for a red pin

    func mapView(_ mapView: MKMapView,
                 viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let identifier = "pinAnnotation"
        var annotationView =
            mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKPinAnnotationView
        if (annotationView == nil) {
            annotationView = MKPinAnnotationView(annotation: annotation,
                                                 reuseIdentifier: identifier)
            if let av = annotationView {
                av.isEnabled = true
                av.canShowCallout = true
                av.pinTintColor = .red
                av.animatesDrop = false
                av.canShowCallout = false
                av.isDraggable = true
            } else {
                unexpected(error: nil, "Can't create MKPinAnnotationView")
            }
        } else {
            annotationView!.annotation = annotation
        }
        return annotationView
    }

    /// A pin is being dragged. [DOES NOT WORK]

    func mapView(_ mapView: MKMapView,
                 annotationView view: MKAnnotationView,
                 didChange newState: MKAnnotationViewDragState,
                 fromOldState oldState: MKAnnotationViewDragState) {
         switch newState {
         case .starting:
            view.setDragState(.dragging, animated: true)
         case .ending:
            view.setDragState(.none, animated: true)
            clickDelegate?.mouseClicked(mapView: nil,
                                        location: view.annotation!.coordinate)
         default:
            view.setDragState(.none, animated: false)
        }
    }

    /// Create an MKPolylineRenderer for MKPolyLines added to the map

    func mapView(_ mapview: MKMapView,
                 rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let polyline = overlay as! MKPolyline
        if mapLines.contains(polyline) {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = NSColor.systemRed
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
}
