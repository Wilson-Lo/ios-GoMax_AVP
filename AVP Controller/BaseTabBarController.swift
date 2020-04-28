//
//  BaseTabBarController.swift
//  AVP Controller
//
//  Created by 啟發電子 on 2020/4/28.
//  Copyright © 2020 gomax. All rights reserved.
//
import UIKit

class BaseTabBarController: UITabBarController {

    @IBInspectable var defaultIndex: Int = 1

    override func viewDidLoad() {
        super.viewDidLoad()
        selectedIndex = defaultIndex
    }

}
