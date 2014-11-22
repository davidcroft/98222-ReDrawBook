//
//  PlayTableViewCell.swift
//  ReDrawBook2
//
//  Created by Ding Xu on 10/13/14.
//  Copyright (c) 2014 Ding Xu. All rights reserved.
//

import UIKit

class PlayTableViewCell: UITableViewCell {

    @IBOutlet var PlayItemThumb: UIImageView!
    @IBOutlet var PlayItemTitle: UILabel!
    @IBOutlet var PlayItemDesp: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
