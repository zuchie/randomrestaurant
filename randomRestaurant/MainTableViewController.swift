//
//  MainTableViewController.swift
//  randomRestaurant
//
//  Created by Zhe Cui on 2/19/17.
//  Copyright © 2017 Zhe Cui. All rights reserved.
//

import UIKit
import CoreData
import CoreLocation


class MainTableViewController: UITableViewController, MainTableViewCellDelegate {
    
    // Properties
    var titleVC = NavItemTitleViewController()
    
    let appDelegate = UIApplication.shared.delegate as? AppDelegate
    var moc: NSManagedObjectContext!

    fileprivate var locationManager = LocationManager.shared
    fileprivate var yelpQueryURL: YelpQueryURL?
    fileprivate var yelpQuery: YelpQuery!
    
    fileprivate var restaurants = [[String: Any]]()
    fileprivate var imgCache = Cache<String>()
    
    struct DataSource {
        var imageUrl: String?
        var name: String?
        var category: String?
        var rating: Float?
        var reviewCount: String?
        var price: String?
        var yelpUrl: String?
        var location: CLLocationCoordinate2D?
        var address: String?
        
    }
    
    var dataSource = [DataSource]()
    
    fileprivate let yelpStars: [Float: String] = [0.0: "regular_0", 1.0: "regular_1", 1.5: "regular_1_half", 2.0: "regular_2", 2.5: "regular_2_half", 3.0: "regular_3", 3.5: "regular_3_half", 4.0: "regular_4", 4.5: "regular_4_half", 5.0: "regular_5"]
    
    struct QueryParams {
        var hasChanged: Bool {
            return categoryChanged || dateChanged || locationChanged
        }
        var categoryChanged = false
        var dateChanged = false
        var locationChanged = false
        
        var category = "" {
            didSet { categoryChanged = (category != oldValue) }
        }
        var date = Date() {
            didSet { dateChanged = (date != oldValue) }
        }
        var location = CLLocation() {
            didSet { locationChanged = (location != oldValue) }
        }
    }
    
    var queryParams = QueryParams()
    var imageCount = 0
    fileprivate var indicator: IndicatorWithContainer!
    
    fileprivate var noResultImgView = UIImageView(image: UIImage(named: "nothing_found"))
    

    // Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("MainTableViewController view did load")
        
        addViewToNavBar()

        titleVC.completion = {
            self.performSegue(withIdentifier: "segueToCategories", sender: self)
        }
        
        moc = appDelegate?.managedObjectContext

        // tableView Cell
        let cellNib = UINib(nibName: "MainTableViewCell", bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: "mainCell")
        
        refreshControl?.addTarget(self, action: #selector(handleRefresh(_:)), for: .valueChanged)
        
        // Start query once location has been got.
        locationManager.completion = { currentLocation in
            let distance = currentLocation.distance(from: self.queryParams.location)
            if distance > 50.0 {
                self.queryParams.location = currentLocation
            }
            // Start Yelp Query
            self.doYelpQuery()
        }
        
        indicator = IndicatorWithContainer(
            indicatorframe: CGRect(x: 0, y: 0,  width: 40, height: 40),
            center: view.center,
            style: .whiteLarge,
            containerFrame: view.frame,
            color: UIColor.gray.withAlphaComponent(0.8))
        
        startIndicator()
        
        getCategoryAndUpdateTitleView("restaurants")
        getDate()
    }
    
    @objc fileprivate func handleRefresh(_ sender: UIRefreshControl) {
        getDate()
        getLocationAndStartQuery()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    fileprivate func startIndicator() {
        DispatchQueue.main.async {
            self.view.addSubview(self.indicator.container)
            self.indicator.start()
        }
    }
    
    fileprivate func stopRefreshOrIndicator() {
        DispatchQueue.main.async {
            if self.refreshControl!.isRefreshing {
                self.refreshControl!.endRefreshing()
            }
            if self.indicator.isAnimating {
                self.indicator.stop()
                self.indicator.container.removeFromSuperview()
            }
        }
    }
    
    fileprivate func addViewToNavBar() {
        titleVC.view.frame = CGRect(x: 0, y: 0, width: navigationController!.navigationBar.frame.width, height: navigationController!.navigationBar.frame.height)
        navigationItem.titleView = titleVC.view
    }
    
    // Cache
    fileprivate func loadImagesToCache(from url: String) {
        guard let urlString = URL(string: url) else {
            fatalError("Unexpected url string while loading image: \(url)")
        }
        URLSession.shared.dataTask(with: urlString) { data, response, error in
            guard error == nil, let imageData = data else {
                print("Error while getting image url response: \(String(describing: error?.localizedDescription))")
                return
            }
            
            guard let image = UIImage(data: imageData) else {
                print("Couldn't create image from data: \(imageData)")
                return
            }

            self.imgCache.add(key: url, value: image)
            self.imageCount -= 1
            
            // Reload table after the last image has been saved.
            if self.imageCount == 0 {
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
                self.stopRefreshOrIndicator()
            }
            
        }.resume()
    }
    
    // Core Data
    func updateSaved(cell: MainTableViewCell, button: UIButton) {
        if button.isSelected {
            print("Save object")
            let saved = NSEntityDescription.insertNewObject(forEntityName: "Saved", into: moc) as! SavedMO
            
            saved.name = cell.name.text
            saved.categories = cell.category.text
            saved.yelpUrl = cell.yelpUrl
        } else {
            let request: NSFetchRequest<SavedMO> = NSFetchRequest(entityName: "Saved")
            request.predicate = NSPredicate(format: "yelpUrl == %@", cell.yelpUrl)
            
            guard let object = try? moc.fetch(request).first else {
                fatalError("Error fetching object in context")
            }
            
            guard let obj = object else {
                print("Didn't find object in context")
                return
            }
            
            moc.delete(obj)
            print("Deleted from Saved entity")
        }
        
        appDelegate?.saveContext()
    }
    
    // Is the object already in Saved?
    fileprivate func objectSaved(url: String) -> Bool {
        let request = NSFetchRequest<SavedMO>(entityName: "Saved")
        request.predicate = NSPredicate(format: "yelpUrl == %@", url)
        guard let object = try? moc.fetch(request).first else {
            fatalError("Error fetching from context")
        }
        
        guard (object != nil) else {
            return false
        }
        
        return true
    }
    
    // Prepare params and do query
    fileprivate func getCategoryAndUpdateTitleView(_ category: String) {
        getCategory(category)
        updateTitleView(category)
    }
    
    fileprivate func getCategory(_ category: String) {
        queryParams.category = category
    }
    
    fileprivate func updateTitleView(_ category: String) {
        let title = (category == "restaurants" ? "What: all" : category)
        guard let stackView = titleVC.view.subviews[0] as? UIStackView else {
            fatalError("Couldn't get stack view from view.")
        }
        guard let label = stackView.arrangedSubviews[1] as? UILabel else {
            fatalError("Couldn't get label from stack view.")
        }
        label.text = title
    }

    fileprivate func getDate() {
        let calendar = Calendar.current
        let myDate = Date()
        let hour = calendar.component(.hour, from: myDate)
        let min = calendar.component(.minute, from: myDate)
        
        guard let date = calendar.date(bySettingHour: hour, minute: min, second: 0, of: myDate) else {
            fatalError("Couldn't get date")
        }
        queryParams.date = date
    }
    
    fileprivate func getLocationAndStartQuery() {
        locationManager.requestLocation()
    }
    
    fileprivate func doYelpQuery() {
        if queryParams.hasChanged {
            yelpQueryURL = YelpQueryURL(
                latitude: queryParams.location.coordinate.latitude,
                longitude: queryParams.location.coordinate.longitude,
                category: queryParams.category,
                radius: 10000,
                limit: 3,
                openAt: Int(queryParams.date.timeIntervalSince1970),
                sortBy: "rating"
            )
            
            guard let queryString = yelpQueryURL?.queryString else {
                fatalError("Couldn't get Yelp query string.")
            }
            guard let query = YelpQuery(queryString) else {
                fatalError("Yelp query is nil.")
            }
            yelpQuery = query
            yelpQuery.completion = { results in
                print("Query completed")
                self.restaurants = results
                self.imgCache.removeAll(keepingCapacity: false)
                self.imageCount = self.restaurants.count
                self.getDataSource()
                
                if self.restaurants.count == 0 {
                    let headerHeight = self.tableView.tableHeaderView!.frame.height
                    let tabBarHeight = self.tabBarController!.tabBar.frame.height
                    self.addImgSubView(imgView: self.noResultImgView, x: 0, y: headerHeight, width: self.view.frame.width, height: self.view.frame.height - headerHeight - tabBarHeight)
                    
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                    self.stopRefreshOrIndicator()
                } else {
                    self.removeImgSubView(imgView: self.noResultImgView)
                }
                
                for member in self.restaurants {
                    self.loadImagesToCache(from: member["image_url"] as! String)
                }
            }

            yelpQuery.startQuery()
            
            queryParams.categoryChanged = false
            queryParams.dateChanged = false
            queryParams.locationChanged = false
        } else {
            print("Params no change, skip query")
            stopRefreshOrIndicator()
        }
    }
    
    // Helpers
    fileprivate func addImgSubView(imgView: UIImageView, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        imgView.frame = CGRect(x: x, y: y, width: width, height: height)
        
        DispatchQueue.main.async {
            self.view.addSubview(imgView)
        }
    }
    
    fileprivate func removeImgSubView(imgView: UIImageView) {
        DispatchQueue.main.async {
            imgView.removeFromSuperview()
        }
    }

    fileprivate func process(dict: [String: Any], key: String) -> Any? {
        switch key {
        case "image_url", "name", "price", "url", "rating":
            return dict[key]
        case "coordinates":
            guard let coordinate = dict[key] as? [String: Double] else {
                fatalError("Couldn't get coordinate.")
            }
            guard let lat = coordinate["latitude"],
                let long = coordinate["longitude"] else {
                    fatalError("Couldnt' get latitude and longitude.")
            }
            return CLLocationCoordinate2DMake(lat, long)
        case "review_count":
            return String(dict[key] as! Int) + " reviews"
        case "categories":
            guard let categories = dict[key] as? [[String: String]] else {
                fatalError("Couldn't get categories from: \(String(describing: dict[key]))")
            }
            let categoriesString = categories.reduce("", { $0 + $1["title"]! + ", " }).characters.dropLast(2)
            return String(categoriesString)
        case "location":
            guard let location = dict[key] as? [String: Any] else {
                fatalError("Couldn't get location from: \(String(describing: dict[key]))")
            }
            guard let address = Address(of: location) else {
                fatalError("Couldn't compose address from location: \(location)")
            }
            return address.composeAddress()
        default:
            fatalError("Key not expected: \(key)")
        }
    }
    
    fileprivate func getDataSource() {
        dataSource.removeAll(keepingCapacity: false)
        for member in restaurants {
            let data = DataSource(
                imageUrl: process(dict: member, key: "image_url") as? String,
                name: process(dict: member, key: "name") as? String,
                category: process(dict: member, key: "categories") as? String,
                rating: process(dict: member, key: "rating") as? Float,
                reviewCount: process(dict: member, key: "review_count") as? String,
                price: process(dict: member, key: "price") as? String,
                yelpUrl: process(dict: member, key: "url") as? String,
                location: process(dict: member, key: "coordinates") as? CLLocationCoordinate2D,
                address: process(dict: member, key: "location") as? String
            )
            dataSource.append(data)
        }
    }
    
    fileprivate func getRatingStar(from rating: Float) -> UIImage {
        guard let name = yelpStars[rating] else {
            fatalError("Couldn't get image name from rating: \(rating)")
        }
        guard let image = UIImage(named: name) else {
            fatalError("Couldn't get image from name: \(name)")
        }
        return image
    }
    
    // Table view
    fileprivate func configureCell(_ cell: MainTableViewCell, _ indexPath: IndexPath) {
        let data = dataSource[indexPath.row]
        cell.imageUrl = data.imageUrl
        var image: UIImage?
        if let value = imgCache.get(by: cell.imageUrl) as? UIImage {
            image = value
        } else {
            // TODO: Pick a globe image
            image = UIImage(named: "globe")
        }
        DispatchQueue.main.async {
            cell.mainImage.image = image
        }
        cell.name.text = data.name
        cell.category.text = data.category
        cell.rating = data.rating
        cell.ratingImage.image = getRatingStar(from: cell.rating)
        cell.reviewCount.text = data.reviewCount
        cell.price.text = data.price
        cell.yelpUrl = data.yelpUrl
        cell.latitude = data.location?.latitude
        cell.longitude = data.location?.longitude
        cell.address = data.address
        cell.likeButton.isSelected = objectSaved(url: cell.yelpUrl)
        cell.delegate = self

    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return restaurants.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Configure the cell...
        let cell = tableView.dequeueReusableCell(withIdentifier: "mainCell", for: indexPath) as! MainTableViewCell
        
        configureCell(cell, indexPath)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 380.0
    }
    
    /*
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Stop refreshing/activity indictor when first cell has been displayed.
        if indexPath.row == 0 {
            stopRefreshOrIndicator()
        }
    }
    */
    /*
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        return section < 4 ? headerHeight: 20.0
    }
    */
    /*
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section < 4 {
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "sectionHeader") as! MainTableViewSectionHeaderView

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleHeaderTap(_:)))
            header.addGestureRecognizer(tap)
            
            header.stackViewHeight.constant = headerHeight
            header.imageView.image = UIImage(named: headers[section].img)
            header.label.text = headers[section].txt
            header.headerName = headers[section].img
         
            return header
        } else {
            return nil
        }
    }
    */
    /*
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        shouldSegue = false
    }
    */
    /*
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section < 4 ? nil : "Restaurants: \(restaurants.count)"
    }
    */

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    // MARK: - Navigation
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if (identifier == "segueToMap" || identifier == "mapButtonToMap"), ((sender is MainTableViewCell) || (sender is UIBarButtonItem)) {
            return true
        } else {
            return false
        }
    }

    @IBAction func handleMapTap(_ sender: UIBarButtonItem) {
        performSegue(withIdentifier: "mapButtonToMap", sender: sender)
    }

    // Segue to Map view controller
    func showMap(cell: MainTableViewCell) {
        performSegue(withIdentifier: "segueToMap", sender: cell)
    }
    
    // Link to Yelp app/website
    func linkToYelp(cell: MainTableViewCell) {
        if cell.yelpUrl != "" {
            UIApplication.shared.openURL(URL(string: cell.yelpUrl)!)
        } else {
            let alert = UIAlertController(title: "Alert",
                                          message: "Couldn't find a restaurant.",
                                          actions: [.ok]
            )
            //self.present(alert, animated: false)
            alert.show()
        }
    }
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueToMap", sender is MainTableViewCell {
            guard let cell = sender as? MainTableViewCell else {
                fatalError("Unexpected sender: \(String(describing: sender))")
            }
            
            let destinationVC = segue.destination
            if cell.address == "" {
                let alert = UIAlertController(title: "Alert",
                                  message: "Couldn't find a restaurant.",
                                  actions: [.ok]
                )
                //self.present(alert, animated: false)
                alert.show()
            } else {
                if let mapVC = destinationVC as? GoogleMapsViewController {
                    mapVC.setBizLocation(cell.address)
                    mapVC.setBizCoordinate2D(CLLocationCoordinate2DMake(cell.latitude
                        , cell.longitude))
                    mapVC.setBizName(cell.name.text!)
                    mapVC.setDepartureTime(Int(queryParams.date.timeIntervalSince1970))
                }
            }
        }
        if segue.identifier == "mapButtonToMap", sender is UIBarButtonItem {
            guard let vc = segue.destination as? GoogleMapsViewController else {
                print("Couldn't show Google Maps VC.")
                return
            }
            vc.getBusinesses(dataSource)
        }
    }
    
    @IBAction func unwindToMain(sender: UIStoryboardSegue) {
        print("Unwind to main")
        
        let sourceVC = sender.source
        guard sender.identifier == "backFromWhat" else {
            fatalError("Unexpeted id: \(String(describing: sender.identifier))")
        }
        
        guard let category = (sourceVC as! FoodCategoriesCollectionViewController).getCategory() else {
            fatalError("Couldn't get category")
        }
        
        startIndicator()
        
        getCategoryAndUpdateTitleView(category)
        getDate()
        getLocationAndStartQuery()
    }
}

/*
extension UIImageView {
    func loadImage(from urlString: String) {
        //print("load image from url")
        guard let url = URL(string: urlString) else {
            fatalError("Unexpected url string: \(urlString)")
        }
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard error == nil, let imageData = data else {
                fatalError("error while getting url response: \(String(describing: error?.localizedDescription))")
            }
            let image = UIImage(data: imageData)
            DispatchQueue.main.async {
                self.image = image
            }
        }.resume()
    }
}
*/
