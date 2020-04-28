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
    
    static let hdmi_audio_type_1 = "HDMI audio (original audio from video subscription in)"
    static let hdmi_audio_type_2 = "HDMI audio (stereo downmix)"
    static let hdmi_audio_type_3 = "HDMI audio (all available channels)"
    static let hdmi_audio_type_4 = "I2S audio subscription"
    static let hdmi_audio_type_5 = "I2S audio local loop out"
    static var hdmi_audio_array = [hdmi_audio_type_1, hdmi_audio_type_2, hdmi_audio_type_3, hdmi_audio_type_4, hdmi_audio_type_5]
    
    static let i2s_audio_type_1 = "HDMI audio (stereo downmix) local loop out"
    static let i2s_audio_type_2 = "HDMI audio (all chanmels) local loop out"
    static let i2s_audio_type_3 = "I2S audio subscription(audio return channel)"
    static var i2s_audio_array = [i2s_audio_type_1, i2s_audio_type_2, i2s_audio_type_3]
    
    static let usb_role_LOCAL = "LOCAL"
    static let usb_role_REMOTE = "REMOTE"
    static let usb_role_DISABLED = "DISABLED"
}
