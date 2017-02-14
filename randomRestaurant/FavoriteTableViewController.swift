//
//  FavoriteTableViewController.swift
//  randomRestaurant
//
//  Created by Zhe Cui on 9/11/16.
//  Copyright © 2016 Zhe Cui. All rights reserved.
//

import UIKit
import CoreData
import CoreLocation

class FavoriteTableViewController: CoreDataTableViewController, UISearchResultsUpdating, UISearchControllerDelegate {
    
    fileprivate var favoriteRestaurants = [Favorite]()
    fileprivate var filteredRestaurants = [Favorite]()
    
    fileprivate var searchResultsVC: UITableViewController?
    fileprivate var searchController: UISearchController?
    
    fileprivate var mySectionsCount = 0 {
        willSet {
            if newValue == 0 {
                setEditing(false, animated: false)
                editButtonItem.isEnabled = false
            } else {
                editButtonItem.isEnabled = true
            }
        }
    }

    //var objToObserve = MyObjectToObserve()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = editButtonItem

        initializeFetchedResultsController()
        
        searchResultsVC = UITableViewController(style: .plain)
        searchResultsVC?.tableView.register(FavoriteTableViewCell.self, forCellReuseIdentifier: "filtered")
        searchResultsVC?.tableView.dataSource = self
        searchResultsVC?.tableView.delegate = self
        
        searchController = UISearchController(searchResultsController: searchResultsVC)
        searchController?.searchResultsUpdater = self
        tableView.tableHeaderView = searchController?.searchBar
        definesPresentationContext = true
        
        searchController?.delegate = self
        
        searchController?.hidesNavigationBarDuringPresentation = true
        searchController?.dimsBackgroundDuringPresentation = true
        searchController?.searchBar.searchBarStyle = .default
        searchController?.searchBar.sizeToFit()
        
        //objToObserve.addObserver(self, forKeyPath: "myTableView", options: .new, context: nil)
    }
    /*
    override func viewWillAppear(_ animated: Bool) {
        //tableView.addObserver(tableView, forKeyPath: "numberOfSections", options: .new, context: nil)
        objToObserve.updateTableView()
    }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        print("hello====")
        if keyPath == "numberOfSections" && object is UITableView {
            print("hello 1====")
            setEditing(false, animated: false)
        }
        objToObserve.removeObserver(self, forKeyPath: "myTableView")
    }
    */
    // Fetch data from DB and reload table view.
    fileprivate func initializeFetchedResultsController() {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Favorite")
        let categorySort = NSSortDescriptor(key: "category", ascending: true)
        let nameSort = NSSortDescriptor(key: "name", ascending: true)
        request.sortDescriptors = [categorySort, nameSort]
        
        let moc = DataBase.managedObjectContext!
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: moc,
            sectionNameKeyPath: "category",
            cacheName: nil
        )
    }
    
    func updateDB(button: HistoryCellButton) {
        let restaurant = Restaurant()
        
        restaurant?.name = button.cellText
        restaurant?.price = button.price
        restaurant?.address = button.address
        restaurant?.rating = button.rating
        restaurant?.reviewCount = button.reviewCount
        restaurant?.category = button.category
        restaurant?.latitude = button.latitude
        restaurant?.longitude = button.longitude
        restaurant?.url = button.url
        
        if button.isSelected {
            DataBase.add(restaurant!, to: "favorite")
        } else {
            DataBase.delete(restaurant!, in: "favorite")
        }
    }
    
    fileprivate func removeFromFavorites(_ name: String) {
        let restaurant = Restaurant()
        restaurant!.name = name
        restaurant!.isFavorite = false
        
        DataBase.delete(restaurant!, in: "favorite")
        DataBase.updateInstanceState(restaurant!, in: "history")
    }
    
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        if tableView == self.tableView {
            mySectionsCount = (fetchedResultsController?.sections?.count)!
            return fetchedResultsController?.sections?.count ?? 0
        } else {
            return 1
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == self.tableView {
            return fetchedResultsController?.sections?[section].numberOfObjects ?? 0
        } else {
            return filteredRestaurants.count
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if tableView == self.tableView {
            return fetchedResultsController?.sections?[section].name.uppercased()
        } else {
            return "Restaurants found"
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let restau: Favorite
        let cellID: String
        
        // Configure the cell...
        if tableView == self.tableView {
            cellID = "favorite"
            restau = fetchedResultsController?.sections?[indexPath.section].objects![indexPath.row] as! Favorite

        } else {
            cellID = "filtered"
            restau = filteredRestaurants[indexPath.row]
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath) as! FavoriteTableViewCell
        cell.textLabel?.text = restau.name
        
        //print("restau url: \(restau.url), restau category: \(restau.category)")
        cell.url = restau.url
        cell.rating = restau.rating
        cell.reviewCount = restau.reviewCount
        cell.price = restau.price
        cell.address = restau.address
        cell.coordinate = CLLocationCoordinate2DMake(restau.latitude!.doubleValue, restau.longitude!.doubleValue)
        cell.category = restau.category
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == searchResultsVC?.tableView {
            performSegue(withIdentifier: "favoritesToResults", sender: tableView.cellForRow(at: indexPath))
        }
    }
    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle:  UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == .delete {
            if let cell = tableView.cellForRow(at: indexPath) {
                // Remove from DB.
                removeFromFavorites((cell.textLabel?.text)!)
            }
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }
    
    // Customize section header, make sure all the headers are rendered when they are inserted.
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        view.tintColor = UIColor.lightGray
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.textColor = UIColor.white
    }
    
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    // Method to conform to UISearchResultsUpdating protocol.
    public func updateSearchResults(for searchController: UISearchController) {
        if let searchText = searchController.searchBar.text {
            let inputText = searchText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            filteredRestaurants = favoriteRestaurants.filter { restaurant in
                return restaurant.name!.lowercased().contains(inputText.lowercased())
            }
            //print("filtered: \(filteredRestaurants)")
        }
        searchResultsVC?.tableView.reloadData()
        //searchResultsVC?.filteredRestaurants = filteredRestaurants
    }
    
    // Notifications to hide/show navigation bar & segmented titles.
    func willPresentSearchController(_ searchController: UISearchController) {
        favoriteRestaurants.removeAll()
        for obj in (fetchedResultsController?.fetchedObjects)! {
            favoriteRestaurants.append(obj as! Favorite)
        }
        //searchResultsVC?.favorites = favoriteRestaurants
        //navigationController?.isNavigationBarHidden = true
    }
    
    func willDismissSearchController(_ searchController: UISearchController) {
        //navigationController?.isNavigationBarHidden = false
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destinationVC = segue.destination as? ResultsViewController, segue.identifier == "favoritesToResults" {
            if let cell = sender as? FavoriteTableViewCell {
                destinationVC.getResults(name: cell.textLabel?.text, price: cell.price, rating: cell.rating, reviewCount: cell.reviewCount, url: cell.url, address: cell.address, coordinate: cell.coordinate, totalBiz: 0, randomNo: 0, category: cell.category)
            }
        }
    }

}
