
import UIKit
import MapKit
import AWSMobileClient
import CoreLocation // 位置情報を取得するためのモジュール

class MapViewController: UIViewController, CLLocationManagerDelegate,MKMapViewDelegate {
    
    @IBOutlet weak var createRouteButton: UIButton!
    @IBOutlet weak var showCurrentLoacationButton: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    let locationManager = CLLocationManager()
    var nowCoordinate:CLLocationCoordinate2D!
    var identityId:String! //AWSユーザーUID
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        showCurrentLoacationButton.layer.cornerRadius = 10
        createRouteButton.layer.cornerRadius = 10
        //画面起動時にサインイン情報がなければサインイン画面を上に作成
        AwsSignUp()
        //自身の位置情報を起点としてマップを表示
        showMyLocationWithMap()
    }
    
    //AWSでのサインイン処理
    private func AwsSignUp(){
        AWSMobileClient.default().initialize { (userState, error) in
            if let userState = userState {
                switch(userState){
                case .signedIn:
                    DispatchQueue.main.async {
                        AWSMobileClient.default().getIdentityId().continueWith { (task) -> Any? in
                            if let error = task.error {
                                print("Error fetching user ID: \(error.localizedDescription)")
                            } else if let identityId = task.result {
                                print("SignIn状態です: \(identityId)")
                                self.identityId = identityId as String
                            }
                            return nil
                        }
                    }
                case .signedOut:
                    AWSMobileClient.default().showSignIn(navigationController: self.navigationController!, { (userState, error) in
                        if(error == nil){ //Successful signin
                            DispatchQueue.main.async {
                                print("SignIn状態です。")
                            }
                        }
                    })
                default:
                    AWSMobileClient.default().signOut()
                }
            } else if let error = error {
                print(error.localizedDescription)
            }
        }
    }
    
    //AWSでのサインアウト処理
    @IBAction func SignOutButtonAction(_ sender: Any) {
        AWSMobileClient.default().signOut()
        // サインイン画面を表示
        AWSMobileClient.default().showSignIn(navigationController: self.navigationController!, { (userState, error) in
            if(error == nil){ //Successful signin
                DispatchQueue.main.async {
                    print("SignIn状態です。")
                }
            }
        })
    }
    
    //位置情報を取得しマップ生成の関数につなげる
    private func showMyLocationWithMap(){
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }
    
    //MapViewで現在地に焦点を当てる
    @IBAction func ShowCurrentLocationAction(_ sender: Any) {
        mapView.setCenter(nowCoordinate, animated:true)
        var region = mapView.region
        region.center = nowCoordinate
        region.span.latitudeDelta = 0.02
        region.span.longitudeDelta = 0.02
        mapView.setRegion(region, animated:true)
        let pin = MKPointAnnotation()
        pin.title = "現在地"
        pin.subtitle = "現在地をピン留めしています。"
        pin.coordinate = nowCoordinate
        mapView.addAnnotation(pin)
    }
    
    //現在地から東京駅までのルートを算出しmapViewに表示
    @IBAction func CreateRouteToTokyoStation(_ sender: Any) {
        
        //出発地点は位置情報取得時に更新した現在地を使用する
        let sourceLocation = nowCoordinate
        //目的地である東京駅の位置情報を設定（緯度: 35.681236 経度: 139.767125）
        let destinationLocation = CLLocationCoordinate2D(latitude: 35.681236, longitude: 139.767125)
        
        //位置設定
        let coordinate = CLLocationCoordinate2DMake((sourceLocation!.latitude + destinationLocation.latitude) / 2, (sourceLocation!.longitude + destinationLocation.longitude) / 2)
        let span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        let region = MKCoordinateRegion(center: coordinate, span: span)
        mapView.setRegion(region, animated: true)
        
        //目的地計算
        let sourcePlacemark = MKPlacemark(coordinate: sourceLocation!, addressDictionary: nil)
        let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
        
        let destinationPlacemark = MKPlacemark(coordinate: destinationLocation, addressDictionary: nil)
        let destinationMapItem = MKMapItem(placemark: destinationPlacemark)
        
        let directionsRequest = MKDirections.Request()
        directionsRequest.transportType = .walking
        directionsRequest.source = sourceMapItem
        directionsRequest.destination = destinationMapItem
        let direction = MKDirections(request: directionsRequest)
        direction.calculate { [weak self] response, error in
            guard let response = response, let route = response.routes.first else {
                return
            }
            //徒歩の速度を分足80mと仮定し目的地までの所要時間を算出
            let walkingTime = route.distance/Double(80)
            self?.mapView.addOverlay(route.polyline, level: .aboveRoads)
            //現在地にピンをセット
            let pin = MKPointAnnotation()
            pin.title = "目的地"
            pin.subtitle = "徒歩での所要時間は\(Int(walkingTime))分"
            pin.coordinate = destinationLocation
            self?.mapView.addAnnotation(pin)
        }
    }
    
    //位置情報の取得に成功した際に処理
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            print("位置情報の取得に成功しました。: \(location)")
            //実機でないと正しい位置情報を取得できないことに注意
            let location = CLLocationCoordinate2DMake(location.coordinate.latitude, location.coordinate.longitude)
            self.nowCoordinate = location
            // マップビューに緯度・軽度・縮尺を設定
            mapView.setCenter(location, animated:true)
            var region = mapView.region
            region.center = location
            region.span.latitudeDelta = 0.02
            region.span.longitudeDelta = 0.02
            mapView.setRegion(region, animated:true)
            // 現在地にピンをセット
            let pin = MKPointAnnotation()
            pin.title = "現在地"
            pin.subtitle = "現在地をピン留めしています。"
            pin.coordinate = location
            mapView.addAnnotation(pin)
        }
    }
    
    //位置情報の取得に失敗した際の処理
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置情報の取得に失敗しました: \(error)")
        //取得にした場合は適当に東京スカイツリーの位置を現在地とする（緯度: 35.7101 経度: 139.8704335）
        let location = CLLocationCoordinate2DMake(35.7101, 139.8107)
        self.nowCoordinate = location
        mapView.setCenter(location, animated:true)
        var region = mapView.region
        region.center = location
        region.span.latitudeDelta = 0.02
        region.span.longitudeDelta = 0.02
        mapView.setRegion(region, animated:true)
        let pin = MKPointAnnotation()
        pin.title = "現在地"
        pin.subtitle = "現在地をピン留めしています。"
        pin.coordinate = location
        mapView.addAnnotation(pin)
    }
    
    @IBAction func ToUserSettingScreenButtonTapped(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let nextVC =  storyboard.instantiateViewController(withIdentifier: "UserSettingViewController") as! UserSettingViewController
        nextVC.identityId = self.identityId
        self.navigationController?.pushViewController(nextVC, animated: true)
    }
    
    //mapViewの追加設定
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .red
            renderer.lineWidth = 3
            return renderer
        }
        return MKOverlayRenderer()
    }
    
}
