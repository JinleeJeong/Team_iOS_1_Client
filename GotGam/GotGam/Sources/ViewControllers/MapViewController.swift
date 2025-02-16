//
//  MapViewController.swift
//  GotGam
//
//  Created by woong on 04/04/2020.
//  Copyright © 2020 손병근. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import CenteredCollectionView
import CoreLocation
import KakaoLink
class MapViewController: BaseViewController, ViewModelBindableType {
    
    // MARK: - Properties
    var viewModel: MapViewModel!
    
    class CardSwipeGesture: UISwipeGestureRecognizer {
        var got: Got?
    }
    
    // MARK: - Views
    
    var mapView: MTMapView!
    @IBOutlet weak var mapBackgroundView: UIView!
    @IBOutlet weak var tagCollectionView: UICollectionView!
    @IBOutlet weak var cardCollectionView: UICollectionView!
    @IBOutlet weak var seedButton: UIButton!
    @IBOutlet weak var myLocationButton: UIButton!
    @IBOutlet weak var quickAddView: MapQuickAddView!
    @IBOutlet weak var seedImageView: UIImageView!
    @IBOutlet weak var restoreView: MapRestoreView!
    @IBOutlet var radiusSlider: UISlider! {
        didSet{
            radiusSlider.transform = CGAffineTransform(rotationAngle: -CGFloat.pi/2)
        }
    }
    @IBOutlet var circleRadiusLabel: UILabel!
    @IBOutlet var sliderBackgroundView: UIView!
    
    // MARK: - Constraints
    @IBOutlet weak var cardCollectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var quickAddViewBottomConstraint: NSLayoutConstraint!
	
	@IBOutlet var titleTopView: UIImageView!
	@IBOutlet var titleText: UITextField!
	
	@IBAction func moveSearch(_ sender: UITextField) {
		if sender.isFirstResponder{
			sender.resignFirstResponder()
		}
		viewModel.input.showSearchVC()
		
	}
	
    var centeredCollectionViewFlowLayout = CenteredCollectionViewFlowLayout()
    var poiItem1: MTMapPOIItem!
    
    var state: MapViewModel.SeedState = .none
    
    var gotList: [Got] = []{
        didSet{
            DispatchQueue.main.async {
                self.cardCollectionViewHeightConstraint.constant = self.gotList.isEmpty ? 0 : 170
                self.cardCollectionView.reloadData()
                self.addPin()
            }
            if gotList.isEmpty {
                currentCircle = nil
            }
            
            LocationManager.shared.updateLocation()
        }
    }
    var currentCircle: MTMapCircle? {
        didSet {
            if let circle = currentCircle {
                if circle.tag != -1 {
                    guard !gotList.isEmpty else { return }
                    let got = gotList[circle.tag]
                    radiusSlider.value = Float(got.radius/1000.0)
                    circleRadiusLabel.text = "\(Int(got.radius))m"
                    
                } else {
                    //radiusSlider.value = Float(100.0/1000.0)
                }
                
                //circleRadiusLabel.text = "\(Int(radiusSlider.value * 1000))m"
                mapView.currentLocationTrackingMode = .off
                mapView.showCurrentLocationMarker = false
                sliderBackgroundView.isHidden = false
                
            } else {
                mapView.removeAllCircles()
                sliderBackgroundView.isHidden = true
            }
        }
    }
	
	//search value
	var x: Double = 0.0
	var y: Double = 0.0
	var addressName: String = ""
	var placeName: String = ""
    
    // MARK: - Methods
    
    func drawCircle(latitude: CLLocationDegrees, longitude: CLLocationDegrees, radius: Float, tag: Int) {
        
        let circle = MTMapCircle()
        let center = MTMapPoint(geoCoord: .init(latitude: latitude, longitude: longitude))
        circle.circleCenterPoint = center
        circle.circleLineColor = .orange
        circle.circleFillColor = UIColor.orange.withAlphaComponent(0.1)
        circle.circleRadius = radius
        circle.tag = tag
        
        mapView.removeAllCircles()
        mapView?.addCircle(circle)
        currentCircle = circle
    }
    func drawCircle(point: MTMapPoint, radius: Float = 150, tag: Int? = nil) {
        
        mapView.removeAllCircles()
        let circle = MTMapCircle()
        circle.circleCenterPoint = point
        circle.circleLineColor = .saffron
        circle.circleLineWidth = 2.0
        circle.circleFillColor = UIColor.saffron.withAlphaComponent(0.17)
        circle.circleRadius = radiusSlider.value * 1000
        circleRadiusLabel.text = "\(Int(radiusSlider.value * 1000))m"
        if let tag = tag {
            circle.tag = tag
        } else {
            circle.tag = -1
        }
        currentCircle = circle
        mapView?.addCircle(circle)
    }
    @objc func didChangeRadius(slider: UISlider, event: UIEvent) {
        guard let tag = currentCircle?.tag, let circle = mapView.findCircle(byTag: tag) else { return }
        let meter = slider.value * 1000
        
        if let touchEvent = event.allTouches?.first {
            switch touchEvent.phase {
            case .moved:
                circle.circleRadius = meter
                mapView.addCircle(circle)
                circleRadiusLabel.text = "\(Int(meter))m"
            case .ended:
                if tag != -1 {
                    var got = gotList[tag]
                    got.radius = Double(meter)
                    viewModel.updateGot(got: got)
                }
                mapView.fitArea(toShow: currentCircle)
                
            default:
                break
            }
        }
    }
    
    func appendEmptyTag(_ tags: [Tag]) -> [Tag] {
        var tags = tags
        let emptyTag = Tag(name: "", hex: "empty")
        tags.append(emptyTag)
        return tags
    }
    
    @objc func swipeCard(gesture: CardSwipeGesture) {
        if let got = gesture.got {
            viewModel.input.showAddDetailVC(got: got)
        }
        
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
		
        configureMapView()
        configureSlider()
        configureCardCollectionView()
        configureTagCollectionView()
        
        self.quickAddView.isHidden = true
        self.seedImageView.isHidden = true
        self.restoreView.isHidden = true
		
		titleText.isHidden = true
		titleTopView.isHidden = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
        
        configureQuickAddView()
        //LocationManager.shared.startUpdatingLocation()
        LocationManager.shared.startMonitoringSignificantLocationChanges()
    
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow(noti:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(noti:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        self.viewModel.updateList()
        self.viewModel.updateTagList()
        if !gotList.isEmpty {
            setCard(index: 0)
        } else {
            currentCircle = nil
        }
    }
	
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.isNavigationBarHidden = false
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        mapView.currentLocationTrackingMode = .off
        mapView.showCurrentLocationMarker = false
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.seedButton.layer.applySketchShadow(color: .black, alpha: 0.3, x: 0, y: 2, blur: 10, spread: 0)
        self.seedButton.layer.cornerRadius = self.seedButton.frame.height / 2
        
        self.myLocationButton.layer.applySketchShadow(color: .black, alpha: 0.3, x: 0, y: 2, blur: 10, spread: 0)
        
        self.myLocationButton.layer.cornerRadius = self.seedButton.frame.height / 2
        self.myLocationButton.backgroundColor = .white
    }
    deinit {
        print("map deinit")
    }
    
    
    // MARK: - Initializing
    
    @objc func keyboardWillShow(noti: Notification){
        if let keyboardSize = (noti.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if self.quickAddViewBottomConstraint.constant == 0{
                let moveY = keyboardSize.height - self.view.safeAreaInsets.bottom
                self.quickAddViewBottomConstraint.constant = moveY
                mapView.frame.origin.y -= moveY/2
                seedImageView.transform = CGAffineTransform(translationX: 0, y: -moveY/2)
                sliderBackgroundView.isHidden = true
                self.view.layoutIfNeeded()
            }
        }
    }
    
    @objc func keyboardWillHide(noti: Notification){
        if let _ = (noti.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if self.quickAddViewBottomConstraint.constant != 0 {
                self.quickAddViewBottomConstraint.constant = 0
                mapView.frame.origin.y = 0
                seedImageView.transform = .identity
                sliderBackgroundView.isHidden = false
                self.view.layoutIfNeeded()
            }
        }
    }
    
    func configureQuickAddView() {
        self.quickAddView.addAction = { text in
            self.quickAddView.addField.resignFirstResponder()
            self.cardCollectionView.isHidden = false
            self.view.layoutIfNeeded()
        }
        
        self.quickAddView.detailAction = { [weak self] in
            guard let self = self else { return }
            guard let radius = self.currentCircle?.circleRadius else { return }
            let center = self.mapView.mapCenterPoint.mapPointGeo()
            let centerLocation = CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude)
            
            self.viewModel.input.showAddDetailVC(location: centerLocation, text: self.quickAddView.addField.text ?? "", radius: Double(radius))
            self.viewModel.seedState.onNext(.none)
        }
    }
    
    func configureTagCollectionView() {
        tagCollectionView.allowsMultipleSelection = true
        let tagNibName = UINib(nibName: "TagCollectionViewCell", bundle: nil)
        tagCollectionView.register(tagNibName, forCellWithReuseIdentifier: "tagCell")
        let tagListNibName = UINib(nibName: "TagListCollectionViewCell", bundle: nil)
        tagCollectionView.register(tagListNibName, forCellWithReuseIdentifier: "tagListCollectionViewCell")
    }
    
    func configureMapView() {
        mapView = MTMapView.init(frame: mapBackgroundView.bounds)
        mapView.delegate = self
        mapView.baseMapType = .standard
        mapBackgroundView.insertSubview(mapView, at: 0)
        view.sendSubviewToBack(mapBackgroundView)
    }
    
    private func configureCardCollectionView(){
        cardCollectionView.collectionViewLayout = centeredCollectionViewFlowLayout
        cardCollectionView.decelerationRate = UIScrollView.DecelerationRate.fast
        centeredCollectionViewFlowLayout.itemSize = CGSize (width: 195, height: 158)
        centeredCollectionViewFlowLayout.minimumLineSpacing = 10
    }
    
    func configureSlider() {
        radiusSlider.addTarget(self, action: #selector(didChangeRadius(slider:event:)), for: .valueChanged)
    }
    
    func bindViewModel() {
        
        viewModel.seedState
            .subscribe(onNext:{ [weak self] state in
            guard let self = self else { return }
            
            switch state{
            case .none:
                self.setNormalStateUI()
            case .seeding:
                self.setSeedingStateUI()
            case .adding:
//                if aimToPlace {
//                    let centerPoint = self.mapView.mapCenterPoint.mapPointGeo()
//                    let location = CLLocationCoordinate2D(latitude: centerPoint.latitude, longitude: centerPoint.longitude)
//                    self.viewModel.input.savePlace(location: location)
//                    return
//                }
                self.setAddingStateUI()
            }
            self.state = state
            }).disposed(by: disposeBag)
        
        self.seedButton.rx.tap.subscribe(onNext: { [weak self] in
            print("버튼 클릭됨")
            guard let self = self else { return }
            switch self.state {
            case .none:
                self.viewModel.seedState.onNext(.seeding)
            case .seeding:
                self.viewModel.seedState.onNext(.adding)
            case .adding:
                self.viewModel.seedState.onNext(.none)
            }
            }).disposed(by: disposeBag)
        self.myLocationButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.setMyLocation()
            }).disposed(by: disposeBag)
        
        self.tagCollectionView.rx.setDelegate(self).disposed(by: self.disposeBag)
        self.cardCollectionView.rx.setDelegate(self).disposed(by: self.disposeBag)
        
//        self.viewModel.output.gotList
//            .subscribe(onNext: { list in
//            self.gotList = list
//        }).disposed(by: self.disposeBag)
        
        self.viewModel.output.gotList
            .do(onNext: { [weak self] in self?.gotList = $0})
            .bind(to: cardCollectionView.rx.items(cellIdentifier: MapCardCollectionViewCell.reuseIdenfier, cellType: MapCardCollectionViewCell.self)) { [weak self] (index, got, cell) in
                guard let self = self else { return }
                
                let swipeGesture = CardSwipeGesture(target: self, action: #selector(self.swipeCard(gesture:)))
                swipeGesture.direction = .up
                swipeGesture.got = got
                cell.addGestureRecognizer(swipeGesture)
                
                cell.got = got
                
                cell.doneButton.rx.tap
                    .subscribe(onNext: {
                        guard let got = cell.got else { return }
                        self.viewModel.setGotDone(got: got)
                    }).disposed(by: cell.disposeBag)
                
                cell.cancelButton.rx.tap
                    .subscribe(onNext: {
                        self.viewModel.deleteGot(got: cell.got!)
                        self.currentCircle = nil
                    }).disposed(by: cell.disposeBag)
            }.disposed(by: self.disposeBag)
        
        viewModel.output.tagList
            .compactMap { [weak self] in self?.appendEmptyTag($0) }
            .bind(to: tagCollectionView.rx.items) { [weak self] (collectionView, cellItem, tag) -> UICollectionViewCell in
                if cellItem != collectionView.numberOfItems(inSection: 0)-1 {
                    guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "tagCell", for: IndexPath(item: cellItem, section: 0)) as? TagCollectionViewCell else { return UICollectionViewCell()}
                    
                    if self?.viewModel.output.emptyTagList.value.contains(tag) ?? false {
                        cell.isEmpty = true
                    } else {
                        cell.isEmpty = false
                    }
                    cell.configure(tag)
                    cell.layer.cornerRadius = cell.bounds.height/2
                    return cell
                } else {
                    guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "tagListCollectionViewCell", for: IndexPath(item: cellItem, section: 0)) as? TagListCollectionViewCell else { return UICollectionViewCell()}
                    cell.layer.cornerRadius = cell.bounds.height/2
                    return cell
                }
            }
            .disposed(by: disposeBag)
        
        cardCollectionView.rx.modelSelected(Got.self)
            .subscribe(onNext: { [weak self] got in
                self?.viewModel.input.showAddDetailVC(got: got)
            })
            .disposed(by: disposeBag)
        
        Observable.zip(tagCollectionView.rx.itemSelected, tagCollectionView.rx.modelSelected(Tag.self))
            .bind { [weak self] indexPath, tag in
                if let collectionView = self?.tagCollectionView, indexPath.item == collectionView.numberOfItems(inSection: 0)-1 {
                    self?.viewModel.input.tagListCellSelect.onNext(())
                    return
                } else if var tags = self?.viewModel.input.filteredTagSubject.value {
                    if !tags.contains(tag) {
                        tags.append(tag)
                        self?.viewModel.input.filteredTagSubject.accept(tags)
                    }
                    
                }
            }
            .disposed(by: disposeBag)
        
        Observable.zip(tagCollectionView.rx.itemDeselected, tagCollectionView.rx.modelDeselected(Tag.self))
            .bind { [weak self] indexPath, tag in
                if var tags = self?.viewModel.input.filteredTagSubject.value, let index = tags.firstIndex(of: tag) {
                    tags.remove(at: index)
                    self?.viewModel.input.filteredTagSubject.accept(tags)
                }
            }
            .disposed(by: disposeBag)

        quickAddView.addButotn.rx.tap
            .throttle(.milliseconds(500), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                if let centerPoint = self?.mapView.mapCenterPoint.mapPointGeo() {
                    let location = CLLocationCoordinate2D(latitude: centerPoint.latitude, longitude: centerPoint.longitude)
                    
                    let currentSliderValue = self?.radiusSlider.value ?? 0.1
                    self?.viewModel.input.quickAdd(location: location, radius: Double(currentSliderValue * 1000))
                    
                }
            })
            .disposed(by: disposeBag)
        
        quickAddView.addField.rx.text.orEmpty
            .bind(to: viewModel.input.addText)
            .disposed(by: disposeBag)
        
//        self.quickAddView.addAction = { [weak self] text in
//            guard let self = self else { return }
//
//            let centerPoint = self.mapView.mapCenterPoint.mapPointGeo()
//            let location = CLLocationCoordinate2D(latitude: centerPoint.latitude, longitude: centerPoint.longitude)
//
//            self.viewModel.input.quickAdd(text: text ?? "", location: location)
//        }
        
        self.viewModel.output.doneAction.bind { got in
            self.restoreView.isHidden = false
            self.restoreView.restoreAction = {
                self.restoreView.isHidden = true
                var tmpGot = got
                tmpGot.isDone = false
                self.viewModel.input.updateGot(got: tmpGot)
                self.currentCircle = nil
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.viewModel.updateList()
                //self.currentCircle = nil
                self.restoreView.isHidden = true
            }
        }.disposed(by: self.disposeBag)
    }
    
    //MARK: Set UI According to the State
    func setNormalStateUI(){
        self.mapView.removeAllCircles()
        self.radiusSlider.value = 0.15
        circleRadiusLabel.text = "\(Int(radiusSlider.value * 1000))m"
        sliderBackgroundView.isHidden = true
        self.seedButton.backgroundColor = .white
        self.seedButton.setImage(UIImage(named: "icMapBtnAdd"), for: .normal)
        self.seedButton.isEnabled = true
        self.quickAddView.isHidden = true
        self.quickAddView.addField.text = ""
        self.seedImageView.isHidden = true
    }
    
    func setSeedingStateUI(){
        
        //drawCircle(latitude: conter.lat, longitude: <#T##CLLocationDegrees#>, radius: <#T##Float#>, tag: <#T##Int#>)
        radiusSlider.value = 0.15
        drawCircle(point: mapView.mapCenterPoint)
        mapView.fitArea(toShow: currentCircle)
        //setCircle(point: mapView.mapCenterPoint)
        self.seedButton.backgroundColor = .saffron
        self.seedButton.setImage(UIImage(named: "icMapBtnSeeding"), for: .normal)
        self.seedButton.isEnabled = true
        self.seedImageView.isHidden = false
    }
    
    func setAddingStateUI(){
        self.seedButton.isEnabled = false
        self.quickAddView.isHidden = false
        self.seedImageView.isHidden = false
        self.seedButton.backgroundColor = .white
        self.seedButton.setImage(UIImage(named: "icMapBtnAdd"), for: .normal)
        self.quickAddView.addField.becomeFirstResponder()
    }
    
    func setRestoreViewUI(){
        
    }
    
    // MARK: Set Methods
    
    func addPin(){
        mapView.removeAllPOIItems()
        for (i, got) in gotList.enumerated() {
            let pin = MTMapPOIItem()
            pin.itemName = got.title
            pin.markerType = .customImage
            let gamImage = UIImage(named: "icPin1")
            pin.customImage = gamImage
            let gamWidth = (gamImage?.size.width ?? .zero)
            let gamHeight = (gamImage?.size.height ?? .zero)
            pin.customImageAnchorPointOffset = .init(offsetX: Int32(gamWidth*0.9), offsetY: Int32(gamHeight*0.5))
            
            pin.mapPoint = MTMapPoint(geoCoord: MTMapPointGeo(latitude: got.latitude, longitude: got.longitude))
            //pin.showAnimationType = .springFromGround
            pin.tag = i
			
			pin.showDisclosureButtonOnCalloutBalloon = false
//			let icView = CGRect(titleText.x: 0.0, y: 0.0, width: 100.0, height: 30.0)
//			let icUIView = UIView(frame: icView)
//			icUIView.backgroundColor = .black
//			pin.customCalloutBalloonView = icUIView
            mapView.addPOIItems([pin])
        }
    }
    func setMyLocation(){
        viewModel.seedState.onNext(.none)
        //LocationManager.shared.requestAuthorization()
        LocationManager.shared.updateLocation()
        if LocationManager.shared.locationServicesEnabled {
            let status = LocationManager.shared.authorizationStatus
            switch status{
            case .denied:
              print("거부됨")
            case .notDetermined, .restricted:
                print("설정으로 이동시키기")
            case .authorizedWhenInUse, .authorizedAlways:
                guard let currentLocation = LocationManager.shared.currentLocation else { return }
                self.mapView.setMapCenter(MTMapPoint(geoCoord: MTMapPointGeo(latitude: currentLocation.latitude, longitude: currentLocation.longitude)), animated: true)
                mapView.currentLocationTrackingMode = .onWithoutHeading
                mapView.showCurrentLocationMarker = true
				let icon = MTMapLocationMarkerItem()
				icon.customTrackingImageName = "icCurrent"
				mapView.updateCurrentLocationMarker(icon)
            @unknown default:
                break
            }
            
        }else{
        }
    }
    
//    func setCircle(point: MTMapPoint){
//        mapView.removeAllCircles()
//        let circle = MTMapCircle()
//        circle.circleCenterPoint = point
//        circle.circleLineColor = .saffron
//        circle.circleLineWidth = 2.0
//        circle.circleFillColor = UIColor.saffron.withAlphaComponent(0.17)
//        circle.tag = 1234
//        circle.circleRadius = 100
//      mapView.addCircle(circle)
//    }
    
    func setCard(index: Int) {
        guard let gotList = try? self.viewModel.output.gotList.value() else { return }
        let got = gotList[index]
        let geo = MTMapPointGeo(latitude: got.latitude, longitude: got.longitude)
        self.mapView.setMapCenter(MTMapPoint(geoCoord: geo), animated: true)
        mapView.removeAllCircles()
        drawCircle(latitude: got.latitude, longitude: got.longitude, radius: Float(got.radius), tag: index)
        centeredCollectionViewFlowLayout.scrollToPage(index: index, animated: true)
        if let currentCircle = currentCircle {
            mapView.fitArea(toShow: currentCircle)
        }
    }
	
	func updateAddress() {
        currentCircle = nil
		self.mapView.setMapCenter(MTMapPoint(geoCoord: MTMapPointGeo(latitude: y, longitude: x)), animated: true)
		currentCircle = nil
		self.seedImageView.isHidden = false
		titleText.isHidden = false
		titleTopView.isHidden = false
		titleText.text = placeName
	}
    
    func linkTest(){
        KakaoLinkManager.shared.shareLink("곳감", "손병근님이 000태그를 보냈습니다\n\n곳감에서000님의 장소를 확인해보세요", thumbnail: "http://k.kakaocdn.net/dn/JoPV3/btqD3IuoYzJ/MeAWwvHSXDx4eZAMfkHfs1/img_640x640.jpg")
    }
}

extension MapViewController: MTMapViewDelegate{
    func mapView(_ mapView: MTMapView!, singleTapOn mapPoint: MTMapPoint!) {
        print(mapPoint.mapPointGeo())
        if self.quickAddView.addField.isFirstResponder{
            self.quickAddView.addField.resignFirstResponder()
            self.quickAddView.isHidden = true
            viewModel.seedState.onNext(.seeding)
        } else {
            currentCircle = nil
            viewModel.seedState.onNext(.none)
        }
		titleText.isHidden = true
		titleTopView.isHidden = true
    }
    func mapView(_ mapView: MTMapView!, centerPointMovedTo mapCenterPoint: MTMapPoint!) {
        switch self.state {
        case .adding, .seeding:
//            setCircle(point: mapCenterPoint)
            if let currentCircle = currentCircle {
                drawCircle(point: mapCenterPoint, radius: currentCircle.circleRadius, tag: currentCircle.tag)
            }
            break
        case .none:
            break
        }
    }
    
    func mapView(_ mapView: MTMapView!, dragEndedOn mapPoint: MTMapPoint!) {
        if state == .none {
            currentCircle = nil
        }
        mapView.currentLocationTrackingMode = .off
        mapView.showCurrentLocationMarker = false
		
		titleText.isHidden = true
		titleTopView.isHidden = true
    }
    func mapView(_ mapView: MTMapView!, finishedMapMoveAnimation mapCenterPoint: MTMapPoint!) {
        switch self.state{
        case .adding, .seeding:
            if let currentCircle = currentCircle {
                drawCircle(point: mapCenterPoint, radius: currentCircle.circleRadius, tag: currentCircle.tag)
            }
            break
        case .none:
            break
        }
    }
    
    func mapView(_ mapView: MTMapView!, selectedPOIItem poiItem: MTMapPOIItem!) -> Bool {
        let got = gotList[poiItem.tag]
        if state != .none {
            viewModel.seedState.onNext(.none)
        }
        mapView?.removeAllCircles()
        drawCircle(latitude: got.latitude, longitude: got.longitude, radius: Float(got.radius), tag: poiItem.tag)

        return true
    }
}

// MARK: - UICollectionView Delegate

extension MapViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) as? TagCollectionViewCell {
            cell.contentView.alpha = 0.3
        } else {
            tagCollectionView.deselectItem(at: indexPath, animated: true)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) as? TagCollectionViewCell {
            guard !cell.isEmpty else { return }
            cell.contentView.alpha = 1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) as? TagCollectionViewCell {
            cell.contentView.alpha = 0.3
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) as? TagCollectionViewCell {
            guard !cell.isEmpty else { return }
            cell.contentView.alpha = 1
        }
    }
}

// MARK: - UICollectionView DelegateFlowLayout

extension MapViewController: UICollectionViewDelegateFlowLayout{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        if collectionView == self.tagCollectionView{
            // 8 + 태그뷰
            var tagWidth: CGFloat = 0
            var title = "태그 목록"
            
            //마지막 셀 = 태그목록
            if indexPath.item != collectionView.numberOfItems(inSection: 0) - 1 {
                tagWidth = 8 + 15
                if let tagList = try? viewModel.output.tagList.value() {
                    title = tagList[indexPath.item].name
                }
//                title = viewModel.output.tagList.value[indexPath.item].name
            }
            
            let rect = NSString(string: title).boundingRect(with: .init(width: 0, height: 30), options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 14)], context: nil)
            
            // tagWidth + 8 + 글자
            let width: CGFloat = tagWidth + 8 + rect.width + 8
            // cell height - inset(10)
            let height: CGFloat = 30
            return CGSize(width: width, height: height)
            
        }else if collectionView == cardCollectionView{
            return centeredCollectionViewFlowLayout.itemSize
        }else{
            fatalError()
        }
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        if collectionView == self.tagCollectionView{
            return 8
        }else if collectionView == self.cardCollectionView{
            return centeredCollectionViewFlowLayout.minimumLineSpacing
        }else{
            fatalError()
        }
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if collectionView == self.tagCollectionView{
            return UIEdgeInsets(top: 11, left: 16, bottom: 10, right: 48)
        }else if collectionView == self.cardCollectionView{
            return centeredCollectionViewFlowLayout.sectionInset
        }else{
            fatalError()
        }
    }
}

extension MapViewController: UIScrollViewDelegate{
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard let currentIndex = self.centeredCollectionViewFlowLayout.currentCenteredPage else { return }
        setCard(index: currentIndex)
//        guard let gotList = try? self.viewModel.output.gotList.value() else { return }
//        let got = gotList[currentIndex]
//        let geo = MTMapPointGeo(latitude: got.latitude ?? .zero, longitude: got.longitude ?? .zero)
//        self.mapView.setMapCenter(MTMapPoint(geoCoord: geo), animated: true)
    }
}
