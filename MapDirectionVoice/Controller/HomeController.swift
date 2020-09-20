//
//  HomeController.swift
//  MapDirectionVoice
//
//  Created by Vũ Tựu on 9/18/20.
//  Copyright © 2020 Vũ Tựu. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Layoutless
import AVFoundation
import Firebase

class HomeController: UIViewController {
    static let identifier = "HomeController"
    var steps: [MKRoute.Step] = []// decribe step of the route on map
    var stepCouter = 0             // count nuber of step
    var route: MKRoute?
    var showMapRoute = false
    var navigationStarted = false
    let locationDistance: Double = 500
    var speechsyntheizer = AVSpeechSynthesizer()
    
    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(#imageLiteral(resourceName: "baseline_arrow_back_black_36dp").withRenderingMode(.alwaysOriginal), for: .normal)
        button.tintColor = .systemGreen
        button.addTarget(self, action: #selector(actionBtnPressed), for: .touchUpInside)
        return button
    }()
    lazy var locationManager : CLLocationManager = {
        let locationManager = CLLocationManager()
        
        if  CLLocationManager.locationServicesEnabled()
        {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            handleAuthorizationStatus(locationManager: locationManager, status: CLLocationManager.authorizationStatus())// ask user to acess their permisstion
        }
        else
        {
            print("location manager not enable")
        }
        
        return locationManager
    }()
    
    lazy var directionLabel: UILabel = {
        let label = UILabel()
        label.text = "Where do you want to go?"
        label.textColor = .systemGreen
        label.font = .boldSystemFont(ofSize: 16)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    lazy var textField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Enter your destination"
        tf.borderStyle = .roundedRect
        return tf
    }()
    
    lazy var getDirectionButton: UIButton = {
        let button = UIButton()
        button.setTitle("Get Direction", for: .normal)
        button.setTitleColor(.systemGreen, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.addTarget(self, action: #selector(getDirectionButtonTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var startStopButton: UIButton = {
        let button = UIButton()
        button.setTitle("Start Navigation", for: .normal)
        button.setTitleColor(.systemGreen, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.addTarget(self, action: #selector(startStopButtonTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var mapView: MKMapView = {
        let mapView = MKMapView()
        mapView.delegate = self
        mapView.showsUserLocation = true
        return mapView
    }()
    
    @objc fileprivate func getDirectionButtonTapped() {
        guard  let text = textField.text else {
            return
        }
        showMapRoute = true
        textField.endEditing(true)
        let geoCoder = CLGeocoder()
        geoCoder.geocodeAddressString(text) { (placemarks, err) in
            if let err = err {
                print(err.localizedDescription)
                return
            }
            guard let placemarks = placemarks ,
                let placemark = placemarks.first,
                let location = placemark.location
                else {return}
            let destinationCoordinate = location.coordinate
            self.mapRoute(destinationCoordinate: destinationCoordinate)
        }
    }
    @objc  func actionBtnPressed(){
        print("okokoko")
//        signOut()
        mapView.removeOverlays(mapView.overlays)
        textField.text = ""
        self.steps.removeAll()
        self.stepCouter = 0
        directionLabel.text = "Where do you want to go?"
        showMapRoute = true
        if let location = locationManager.location {
            let center = location.coordinate
            centerViewToUserLocation(center: center)
        }
    }
    
    @objc fileprivate func startStopButtonTapped() {
        if !navigationStarted{
            showMapRoute = true
            if let location = locationManager.location {
                let center = location.coordinate
                centerViewToUserLocation(center: center)
            }
        }else{
            if let route = route{
                self.mapView.setVisibleMapRect(route.polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16), animated: true)
                self.steps.removeAll()
                self.stepCouter = 0
            }
        }
        navigationStarted.toggle()
        
        startStopButton.setTitle(navigationStarted ? "Stop Navigation":"Start Navigation", for: .normal)
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        
        // Do any additional setup after loading the view.
        setupViews()
        view.addSubview(backButton)
        checkIfUserIsLogIn()
        signOut()
        locationManager.startUpdatingLocation()
    }
    override func viewDidLayoutSubviews() {
        backButton.anchor(top: view.safeAreaLayoutGuide.topAnchor,left: view.leftAnchor,  paddingTop: 10,paddingLeft: 3, width: 30, height: 30)
    }
    func checkIfUserIsLogIn(){
        if Auth.auth().currentUser?.uid == nil{
            DispatchQueue.main.async {
                let nav = UINavigationController(rootViewController: LoginController())
                nav.modalPresentationStyle = .fullScreen
                self.present(nav, animated: true, completion: nil)
            }
            print("user not logged in...")
        }else{
            print("user id is \(String(describing: Auth.auth().currentUser?.uid))")
        }
    }
    @objc func signOut(){
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                let nav = UINavigationController(rootViewController: LoginController())
                nav.modalPresentationStyle = .fullScreen
                self.present(nav, animated: true, completion: nil)
            }
            checkIfUserIsLogIn()
        }
        catch {
            print("Error Sign Out")
        }
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    fileprivate func setupViews() {
        view.backgroundColor = .systemBackground
        stack(.vertical)(
            directionLabel.insetting(by: 16),
            stack(.horizontal, spacing: 16)(
                textField,
                getDirectionButton
            ).insetting(by: 16),
            startStopButton.insetting(by: 16),
            mapView
        ).fillingParent(relativeToSafeArea: true).layout(in: view)
    }
    
    fileprivate func centerViewToUserLocation(center: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(center: center, latitudinalMeters: locationDistance, longitudinalMeters: locationDistance)
        mapView.setRegion(region, animated: true)
    }
    
    fileprivate func handleAuthorizationStatus(locationManager: CLLocationManager, status: CLAuthorizationStatus) {
        switch status {
            
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            break
        case .restricted:
            //
            break
        case .denied:
            //
            break
        case .authorizedAlways:
            //
            break
        case .authorizedWhenInUse:
            if let center = locationManager.location?.coordinate{
                centerViewToUserLocation(center: center)
            }
            break
        @unknown default:
            //
            break
        }
    }
    
    fileprivate func mapRoute(destinationCoordinate: CLLocationCoordinate2D) {
        guard  let sourceCoordinate = locationManager.location?.coordinate else {
            return
        }
        let sourcePlacemark = MKPlacemark(coordinate: sourceCoordinate)
        
        let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)
        
        let sourceItem = MKMapItem(placemark: sourcePlacemark)
        
        let destinationItem = MKMapItem(placemark: destinationPlacemark)
        
        let routeRequest = MKDirections.Request()
        routeRequest.source = sourceItem
        routeRequest.destination = destinationItem
        routeRequest.transportType = .automobile
        
        let directions = MKDirections(request: routeRequest)
        directions.calculate { (response, err) in
            if let err = err {
                print(err.localizedDescription)
                return
            }
            guard let response = response, let route = response.routes.first else {return}
            self.route = route
            
            self.mapView.addOverlay(route.polyline)
            
            self.mapView.setVisibleMapRect(route.polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16), animated: true)
            
            self.getRouteSteps(route: route)
        }
    }
    
    fileprivate func getRouteSteps(route: MKRoute) {
        for monitoredRegion in locationManager.monitoredRegions{
            locationManager.stopMonitoring(for: monitoredRegion)
        }
        
        let steps = route.steps
        
        self.steps = steps
        
        for i in 0..<steps.count{
            let step = steps[i]
            print(step.instructions)
            print(step.distance)
            
            let region  = CLCircularRegion(center: step.polyline.coordinate, radius: 20, identifier:
                "\(i)")
            
            locationManager.startMonitoring(for: region)
        }
        stepCouter += 1
        let initialMessage = "     In \(steps[stepCouter].distance) mester \(steps[stepCouter].instructions), then \(steps[stepCouter + 1].distance) mester \(steps[stepCouter + 1].instructions)"
        print("DEBUG: ", initialMessage)
        directionLabel.text = initialMessage
        
        let speedUtterance = AVSpeechUtterance(string: initialMessage)
        //        speedUtterance.voice  = AVSpeechSynthesisVoice(language: "ja-JP")
        speechsyntheizer.speak(speedUtterance)
    }
    
}
extension HomeController : CLLocationManagerDelegate{
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        //zoom if it not show whole the route
        if !showMapRoute{
            if let location = locations.last{
                let center = location.coordinate
                centerViewToUserLocation(center: center)
            }
            
        }
    }
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        handleAuthorizationStatus(locationManager: locationManager, status: status)
    }
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        stepCouter += 1
        if stepCouter <= steps.count{
            let message = "     In \(steps[stepCouter].distance) mester \(steps[stepCouter].instructions)"
            
            directionLabel.text = message
            
            let speedUtterance = AVSpeechUtterance(string: message)
            //        speedUtterance.voice  = AVSpeechSynthesisVoice(language: "ja-JP")
            speechsyntheizer.speak(speedUtterance)
        }else{
            let message = "       you have arrived at your destination"
            directionLabel.text = message
            stepCouter = 0
            navigationStarted = false
            for monitoredRegion in locationManager.monitoredRegions{
                locationManager.stopMonitoring(for: monitoredRegion)
            }
        }
    }
}

extension HomeController : MKMapViewDelegate{
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = .systemGreen
        return renderer
    }
}
