//
//  RecordTableViewCell.swift
//  ReDrawBook2
//
//  Created by Ding Xu on 10/14/14.
//  Copyright (c) 2014 Ding Xu. All rights reserved.
//

import UIKit

class RecordTableViewCell: UITableViewCell {
    
    @IBOutlet var RecordItemThumb: UIImageView!
    @IBOutlet var RecordItemTitle: UILabel!
    @IBOutlet var RecordItemDesp: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
