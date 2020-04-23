//
//  CustomTableViewCellDevice.swift
//  AVP Controller
//
//  Created by 啟發電子 on 2020/4/23.
//  Copyright © 2020 gomax. All rights reserved.
//

import UIKit

class CustomTableViewCellDevice: UITableViewCell {
    
    @IBOutlet weak var label_device_id: UILabel!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        print("wilosn")
        self.label_device_id = self.viewWithTag(110) as? UILabel
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
