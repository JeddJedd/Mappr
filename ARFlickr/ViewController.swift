//
//  ViewController.swift
//  ARFlickr
//
//  Created by jgoble52 on 10/10/17.
//  Copyright © 2017 Jedd Goble. All rights reserved.
//

import UIKit
import ARCL
import CoreLocation
import SceneKit
import SDWebImage
import ARKit

class ViewController: UIViewController {

    var sceneLocationView = SceneLocationView()
    var locationManager = CLLocationManager()
    
    var downloadTimer: Timer?
    var downloadAllowed: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneLocationView.locationDelegate = self
        sceneLocationView.run()
        view.addSubview(sceneLocationView)
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneLocationView.pause()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        sceneLocationView.frame = view.bounds
    }
    
    @objc func reEnableDownloadAllowed() {
        downloadAllowed = true
    }
    
    func downloadPhotos(photos: [FlickrPhoto]) {
        
        print("Attempting photos download")
        
        for photo in photos {
            guard let urlString = photo.urlString, let url = URL(string: urlString) else {
                print("Photo has no URL")
                return
            }
            
            SDWebImageDownloader().downloadImage(with: url, options: .highPriority, progress: nil, completed: { (image, data, error, completed) in
                if let error = error {
                    print(error.localizedDescription)
                }
                
                guard let image = image else {
                    print("Image download unsuccessful")
                    return
                }
                
                self.addAnnotation(photo: photo, image: image)
            })
        }
    }
    
    func addAnnotation(photo: FlickrPhoto, image: UIImage) {
        guard let lat = photo.latitude, let lon = photo.longitude else {
            return
        }
        
        let location = CLLocation(latitude: lat, longitude: lon)
        let annotationNode = LocationAnnotationNode(location: location, image: image)
        annotationNode.scaleRelativeToDistance = false
        sceneLocationView.addLocationNodeWithConfirmedLocation(locationNode: annotationNode)
        print("Added annotation")
    }
}

extension ViewController: CLLocationManagerDelegate {
    
}

extension ViewController: SceneLocationViewDelegate {
    
    func sceneLocationViewDidAddSceneLocationEstimate(sceneLocationView: SceneLocationView, position: SCNVector3, location: CLLocation) {
        guard downloadAllowed == true else {
            return
        }
        
        downloadAllowed = false
        downloadTimer = Timer.scheduledTimer(timeInterval: 15.0, target: self, selector: #selector(self.reEnableDownloadAllowed), userInfo: nil, repeats: false)
        
        print("Attempting Flickr API call")
        
        let urlString = "https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=0fa112504f3a3e7c9d74cad429d6f709&format=json&accuracy=16&sort=date-posted-desc&per_page=10&nojsoncallback=1&extras=url_m,geo&lat=\(location.coordinate.latitude)&lon=\(location.coordinate.longitude)"
        
        if let url = URL(string: urlString) {
            let urlSession = URLSession.shared
            let task = urlSession.dataTask(with: url, completionHandler: { (data, response, error) in
                if let error = error {
                    print(error.localizedDescription)
                }
                
                guard let data = data else {
                    print("Data returned null")
                    return
                }
                
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String : Any] {
                        
                        if let root = json["photos"] as? [String : Any], let photosJson = root["photo"] as? [[String : Any]] {
                            var photos: [FlickrPhoto] = []
                            
                            for photoJson in photosJson {
                                if let photo = FlickrPhoto(json: photoJson) {
                                    photos.append(photo)
                                }
                            }
                            
                            DispatchQueue.main.async {
                                self.downloadPhotos(photos: photos)
                            }
                        }
                    }
                } catch let error {
                    print(error.localizedDescription)
                }
            })
            
            task.resume()
        }
    }
    
    func sceneLocationViewDidRemoveSceneLocationEstimate(sceneLocationView: SceneLocationView, position: SCNVector3, location: CLLocation) {
        
    }
    
    func sceneLocationViewDidConfirmLocationOfNode(sceneLocationView: SceneLocationView, node: LocationNode) {
        
    }
    
    func sceneLocationViewDidSetupSceneNode(sceneLocationView: SceneLocationView, sceneNode: SCNNode) {
        
    }
    
    func sceneLocationViewDidUpdateLocationAndScaleOfLocationNode(sceneLocationView: SceneLocationView, locationNode: LocationNode) {
        
    }
}

