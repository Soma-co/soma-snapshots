import CoreLocation

class ItemsSearchProvider: SearchProvider {
    weak var delegate: SearchProviderDelegate?
    
    let title = NSLocalizedString("Items", comment: "")
    var controller: UIViewController {
        return itemsController
    }
    
    let minCharsToQuery: Int? = nil
    
    fileprivate lazy var itemsController: ItemCardCollectionViewController = {
        let storyboard = UIStoryboard.storyboard(storyboard: .main)
        
        let controller: ItemCardCollectionViewController = storyboard.instantiateViewController()
        controller.isForSearch = false
        
        let options = ItemsSearchOptions.fromSettings()
        
        apply(options: options, to: controller)
        
        return controller
    }()
    
    func search(for query: String) {
        itemsController.query = query
        itemsController.refresh()
    }
    
    let hasOptions: Bool = true
    
    var areOptionsModified: Bool {
        return options != .default
    }
    
    func makeSearchOptionsController() -> UIViewController? {
        let storyboard = UIStoryboard.storyboard(storyboard: .advancedSearch)
        
        let controller: SearchOptionsViewController = storyboard.instantiateViewController()
        
        controller.options = ItemsSearchOptions.fromSettings()
        controller.delegate = self
        
        return controller
    }
    
    let canGetSuggestions: Bool = false
    
    func getSuggestions(for query: String, completion: @escaping ([String]?) -> Void) {
        DispatchQueue.main.async {
            completion(nil)
        }
    }

    fileprivate var options: ItemsSearchOptions = .default {
        didSet {
            delegate?.optionsDidChange()
        }
    }
}

extension ItemsSearchProvider: SearchOptionsViewControllerDelegate {
    func optionsDidChange(options: ItemsSearchOptions) {
        options.save()
        self.options = options
        apply(options: options, to: itemsController)
        itemsController.refresh()
    }
}

fileprivate func apply(options: ItemsSearchOptions,
                       to itemController: ItemCardCollectionViewController) {
    
    let candidates = [options.location, userCurrentLocation, userProfileLocation]
    itemController.searchLocation = candidates.flatMap { $0 }.map { CLLocation(coordinate: $0) }.first
    itemController.searchRadius = options.radius
    
    switch options.order {
    case .expensiveFirst:
        itemController.sortBy = .price
        itemController.sortOrder = .desc
    case .cheapFirst:
        itemController.sortBy = .price
        itemController.sortOrder = .asc
    case .newFirst:
        itemController.sortBy = .created
        itemController.sortOrder = .desc
    case .mostPopular:
        itemController.sortBy = .liked
        itemController.sortOrder = .desc
    }
}

fileprivate var userProfileLocation: CLLocationCoordinate2D? {
    guard
        ProfileUtility.isProfileDataAvailable(),
        let locationSettings = ProfileUtility.loadUserInfo().locationSettings,
        let latitude = locationSettings["lat"] as? Double,
        let longitude = locationSettings["long"] as? Double
        else {
            return nil
    }
    
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
}

fileprivate var userCurrentLocation: CLLocationCoordinate2D? {
    return LocationManager.sharedInstance.currentLocation?.coordinate
}

fileprivate extension CLLocation {
    convenience init(coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}


fileprivate extension ItemsSearchOptions {
    static func fromSettings() -> ItemsSearchOptions {
        if let params = UserDefaults.standard.dictionary(forKey: "ItemsSearchOptions") {
            return ItemsSearchOptions(dict: params)
        } else {
            return .default
        }
    }
    
    func save() {
        UserDefaults.standard.set(asDict, forKey: "ItemsSearchOptions")
        UserDefaults.standard.synchronize()
    }
}
