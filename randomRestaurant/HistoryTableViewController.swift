//
//  HistoryTableViewController.swift
//  randomRestaurant
//
//  Created by Zhe Cui on 9/11/16.
//  Copyright © 2016 Zhe Cui. All rights reserved.
//

import UIKit
import CoreData

class HistoryTableViewController: CoreDataTableViewController {
    
    //private var favoriteRestaurant: FavoriteTableViewController?
    fileprivate var historyRest = Restaurant()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("history view did load")
        
        //favoriteRestaurant = SlotMachineViewController.favoriteTableVC
        updateUI()
    }
    
    // Fetch data from DB and reload table view.
    func updateUI() {
        if let context = HistoryDB.managedObjectContext {
            let request: NSFetchRequest<History> = NSFetchRequest(entityName: "History")
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            print("updating history UI")
            
            fetchedResultsController = NSFetchedResultsController(
                fetchRequest: request,
                managedObjectContext: context,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
            
        } else {
            fetchedResultsController = nil
            print("managedObjectContext is nil")
        }
    }

    func removeFromFavorites(_ name: String) {
        let restaurant = Restaurant()
        restaurant!.name = name
        restaurant!.isFavorite = false
        
        HistoryDB.updateEntryState(restaurant!)
        updateUI()
        
        // Delete from Favorite list.
        //favoriteRestaurant!.removeFromFavorites(restaurant!)
    }
    
    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        //print("history cell section: \(indexPath.section) row: \(indexPath.row)")
        let cell = tableView.dequeueReusableCell(withIdentifier: "history", for: indexPath) as! HistoryTableViewCell
        
        // Configure the cell...
        if let historyRestaurant = fetchedResultsController?.object(at: indexPath) {
            var name: String?
            var isFavorite: Bool?
            
            historyRestaurant.managedObjectContext?.performAndWait {
                name = historyRestaurant.name
                isFavorite = historyRestaurant.isFavorite?.boolValue
            }
            cell.addToFav.isSelected = isFavorite!
            cell.historyLabel.text = name
            
            cell.addToFav.cellText = cell.historyLabel.text
            cell.addToFav.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchDown)
        }
        
        return cell
    }
    
    fileprivate func updateButtonStatus(_ button: UIButton) {

        if button.isSelected == false {
            button.isSelected = true
        } else {
            button.isSelected = false
        }
    }
    
    func buttonTapped(_ sender: HistoryCellButton) {
        
        // Pass to favorite restaurant database.
        historyRest!.name = sender.cellText
        historyRest!.price = ""
        historyRest!.address = ""
        historyRest!.rating = ""
        historyRest!.reviewCount = ""
        
        updateButtonStatus(sender)
        
        historyRest!.isFavorite = sender.isSelected
        
        HistoryDB.updateEntryState(historyRest!)
        updateUI()
        
        /*
        // Update favorite restaurant list and update table view.
        if historyRest!.isFavorite! {
            favoriteRestaurant!.addToFavorites(historyRest!)
        } else {
            favoriteRestaurant!.removeFromFavorites(historyRest!)
        }
        
        favoriteRestaurant!.updateUI()
        */
    }

}
