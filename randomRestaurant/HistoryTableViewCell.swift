//
//  HistoryTableViewCell.swift
//  randomRestaurant
//
//  Created by Zhe Cui on 9/20/16.
//  Copyright © 2016 Zhe Cui. All rights reserved.
//

import UIKit

class HistoryTableViewCell: UITableViewCell {

    @IBOutlet weak var historyLabel: UILabel!
    @IBOutlet weak var addToFav: HistoryCellButton!
    
    private let emptyStar = UIImage(named: "emptyStar")
    private let filledStar = UIImage(named: "filledStar")
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        addToFav.setImage(emptyStar, forState: .Normal)
        addToFav.setImage(filledStar, forState: .Selected)
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}