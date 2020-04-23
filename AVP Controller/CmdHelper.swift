//
//  CmdHelper.swift
//  AVP Controller
//
//  Created by 啟發電子 on 2020/4/22.
//  Copyright © 2020 gomax. All rights reserved.
//

import Foundation


struct CmdHelper {
    
    static let cmd_human_mode = "mode human\n"
    static let cmd_require_blueriver_api_2_19_0 = "require blueriver_api 2.19.0\n"
    static let cmd_get_all_list = "get all list\n"
    
    static let hdmi_gerenal = 0;
    static let hdmi_genlock = 1;
    static let hdmi_fastswitch = 2;
    
    static let resolution_4k2k_60 = 0;
    static let resolution_1080p_60 = 1;
    static let resolution_720p_60 = 2;
}
