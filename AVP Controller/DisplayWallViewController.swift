//
//  TVWallViewController.swift
//  AVP Controller
//
//  Created by 啟發電子 on 2020/4/29.
//  Copyright © 2020 gomax. All rights reserved.
//

import UIKit
import CocoaAsyncSocket
import RSSelectionMenu
import Toast_Swift
import RSSelectionMenu
import PopupDialog

class DisplayWallViewController:UIViewController, GCDAsyncSocketDelegate{
    
    var mSocket:GCDAsyncSocket!
    var queueTCP: DispatchQueue!
    var alert: UIAlertController!
    let preferences = UserDefaults.standard
    var isConnected = false
    let _1_cmd_mode_human = 1
    let _2_cmd_require_blueriver_api_2_19_0 = 2
    let _3_get_all_list = 3
    let _4_get_device_settings = 4
    let _5_set_display_wall = 5
    var currentCmdNumber = 0// current send cnmd number
    var deviceList: Array<String> = []
    var receiveData: String = ""
    var isLockRead: Bool = false
    var bt_device_id: UIButton!
    var menu: RSSelectionMenu<String>!
    var userSelectedDeviceIndex = -1//recoed user select which device id
    var userSelectedHCut = 1
    var userSelectedVCut = 1
    var userSelectedNumber = 1
    var userSelectedHDMIType = 0
    var source_width = 0
    var source_height = 0
    var segmentedHDMIType: UISegmentedControl!
    var label_resolution: UILabel!
    var bt_h: UIButton!
    var bt_v: UIButton!
    var bt_number: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.alert = UIAlertController(title: nil, message: "Please wait...", preferredStyle: .alert)
        self.bt_device_id = self.view.viewWithTag(701) as? UIButton
        self.segmentedHDMIType = self.view.viewWithTag(702) as? UISegmentedControl
        self.label_resolution = self.view.viewWithTag(703) as? UILabel
        self.bt_h = self.view.viewWithTag(704) as? UIButton
        self.bt_v = self.view.viewWithTag(705) as? UIButton
        self.bt_number = self.view.viewWithTag(706) as? UIButton
        self.segmentedHDMIType.addTarget(self, action: #selector(HDMITypeChanged(_:)), for: .valueChanged)
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        print("USBRoutingViewController-viewDidAppear")
        self.userSelectedDeviceIndex = -1
        self.userSelectedHCut = 1
        self.userSelectedVCut = 1
        self.userSelectedNumber = 1
        self.userSelectedHDMIType = 0
        self.bt_h.setTitle("1", for: .init())
        self.bt_v.setTitle("1", for: .init())
        self.queueTCP = DispatchQueue(label: "com.gofanco.tcp", qos: DispatchQoS.userInitiated)
        if(preferences.value(forKey: key_server_ip) != nil){
            var fullIP = preferences.value(forKey: key_server_ip) as! String
            self.queueTCP.async {
                DispatchQueue.main.async {
                    self.showLoading()
                }
                // if(currentDeviceIP != nil){
                self.mSocket = nil
                self.mSocket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
                do {
                    
                    try self.mSocket.connect(toHost: fullIP, onPort: 6970)
                    
                    print("connect to device success")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        if(!self.isConnected){
                            self.closeLoading()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.view.makeToast("Request timeout !", duration: 3.0, position: .bottom)
                            }
                        }
                    }
                    
                } catch let error {
                    print("error to connect device")
                }
                
                
            }
        }
        
    }
    
    
    
    
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print("USBRoutingViewController-socketDidDisconnect")
        self.isConnected = false
    }
    
    
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("USBRoutingViewController-didConnectToHost")
        self.isConnected = true
        self.queueTCP.asyncAfter(deadline: .now() + 0.5) {
            print("send command")
            self.currentCmdNumber = self._1_cmd_mode_human
            self.mSocket.write((CmdHelper.cmd_human_mode.data(using: String.Encoding.utf8))!, withTimeout: -1, tag: 0)
            self.mSocket.readData(withTimeout: -1, tag: 0)
        }
    }
    
    public func socket(_ sock: GCDAsyncSocket, didRead: Data, withTag tag:CLong){
        print("USBRoutingViewController-didRead")
        
        switch self.currentCmdNumber {
            
        case self._1_cmd_mode_human:
            print("_1_cmd_mode_human")
            
            do {
                _ = try JSONSerialization.jsonObject(with: didRead)
                print("Valid Json")
                let humanMode: HumanMode = try! JSONDecoder().decode(HumanMode.self, from: didRead)
                if(humanMode.status == "SUCCESS"){
                    queueTCP.async  {
                        self.currentCmdNumber = self._2_cmd_require_blueriver_api_2_19_0
                        
                        self.mSocket.write((CmdHelper.cmd_require_blueriver_api_2_19_0.data(using: String.Encoding.utf8))!, withTimeout: -1, tag: 0)
                        self.mSocket.readData(withTimeout: 1, tag: 0)
                    }
                }else{
                    DispatchQueue.main.async {
                        self.closeLoading()
                        self.ShowToast(message: "Request timeout")
                    }
                }
            } catch {
                print("Error deserializing JSON: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.closeLoading()
                    self.ShowToast(message: "Request timeout")
                }
            }
            
            break
            
            
        case self._2_cmd_require_blueriver_api_2_19_0:
            print("_2_cmd_require_blueriver_api_2_19_0")
            
            do {
                _ = try JSONSerialization.jsonObject(with: didRead)
                print("Valid Json")
                let humanMode: HumanMode = try! JSONDecoder().decode(HumanMode.self, from: didRead)
                if(humanMode.status == "SUCCESS"){
                    print("initial successful")
                    self.isLockRead = true
                    self.currentCmdNumber = self._3_get_all_list
                    self.deviceList.removeAll()
                    self.receiveData = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.isLockRead = false
                        
                        do {
                            _ = try JSONSerialization.jsonObject(with: self.receiveData.data(using: .utf8)!)
                            let checkFeedbackStatus:CheckFeedbackstatus  = try! JSONDecoder().decode(CheckFeedbackstatus.self, from: self.receiveData.data(using: .utf8)!)
                            
                            if(checkFeedbackStatus.status == "SUCCESS"){
                                let get_all_list: GetAllList = try! JSONDecoder().decode(GetAllList.self, from: self.receiveData.data(using: .utf8)!)
                                if(get_all_list.result.devices.count > 0){
                                    for index in get_all_list.result.devices{
                                        self.deviceList.append(index.device_id)
                                        print(index.device_id)
                                    }
                                    
                                    DispatchQueue.main.async {
                                        self.closeLoading()
                                    }
                                }
                            }else{
                                DispatchQueue.main.async {
                                    self.closeLoading()
                                    self.ShowToast(message: "Request timeout")
                                }
                            }
                            
                            
                        } catch {
                            print("Error deserializing JSON: \(error.localizedDescription)")
                            DispatchQueue.main.async {
                                self.closeLoading()
                                self.ShowToast(message: "Request timeout")
                            }
                        }
                        
                        
                    }
                    self.queueTCP.async {
                        self.mSocket.write((CmdHelper.cmd_get_all_list.data(using: String.Encoding.utf8))!, withTimeout: -1, tag: 0)
                        while(true){
                            if(self.isLockRead){
                                self.mSocket.readData(withTimeout: -1, tag: 0)
                            }else{
                                break
                            }
                        }
                    }
                }else{
                    DispatchQueue.main.async {
                        self.closeLoading()
                        self.ShowToast(message: "Request timeout")
                    }
                }
            } catch {
                print("Error deserializing JSON: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    DispatchQueue.main.async {
                        self.closeLoading()
                    }
                    self.view.makeToast("Request timeout")
                }
            }
            
            break
            
            
        case self._3_get_all_list:
            print("_3_get_all_list")
            if(self.isLockRead && didRead != nil){
                self.receiveData.append(String(decoding: didRead, as: UTF8.self))
            }
            break
            
            
        case self._4_get_device_settings:
            print("_4_get_device_settings")
            if(self.isLockRead && didRead != nil){
                self.receiveData.append(String(decoding: didRead, as: UTF8.self))
            }
            
            break
            
        case self._5_set_display_wall:
            print("_5_set_display_wall")
            print(String(decoding: didRead, as: UTF8.self))
            DispatchQueue.main.async(){
                self.closeLoading()
            }
            DispatchQueue.main.async {
                self.view.makeToast("Successful")
            }
            //feedBackUser(didRead: didRead)
            break
            
            
        default:
            
            break
        }
    }
    
    @objc func HDMITypeChanged(_ sender: UISegmentedControl){
        print(sender.selectedSegmentIndex)
        self.userSelectedHDMIType = sender.selectedSegmentIndex
        print(self.userSelectedHDMIType)
    }
    
    //handler server feedback (processing)
    private func feedBackUser(didRead: Data){
        
        
        var isJSONFormate = true
        
        do {
            _ = try JSONSerialization.jsonObject(with: didRead)
            
        } catch {
            isJSONFormate = false
            print("Error deserializing JSON: \(error.localizedDescription)")
            
        }
        
        if(isJSONFormate){
            print("Valid Json")
            let status: Status = try! JSONDecoder().decode(Status.self, from: didRead)
            DispatchQueue.main.async(){
                self.closeLoading()
            }
            if(status.status == "PROCESSING"){
                DispatchQueue.main.async {
                    self.view.makeToast("Send successful ", duration: 2.0, position: .bottom)
                }
            }else if(status.status == "SUCCESS"){
                
                let error_message : Error = try! JSONDecoder().decode(Error.self, from: didRead)
                print("change error " + String(error_message.result.error.count))
                DispatchQueue.main.async {
                    self.view.makeToast("Send failed: " + error_message.result.error[0].message, duration: 2.0, position: .bottom)
                }
            }else{
                DispatchQueue.main.async {
                    self.view.makeToast("Send failed")
                }
            }
        }else{
            DispatchQueue.main.async {
                self.view.makeToast("Request timeout")
            }
        }
        
    }
    
    private func showLoading(){
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = UIActivityIndicatorView.Style.gray
        loadingIndicator.startAnimating();
        
        alert.view.addSubview(loadingIndicator)
        present(alert, animated: true, completion: nil)
    }
    
    
    private func closeLoading(){
        dismiss(animated: false, completion: nil)
    }
    
    struct CheckFeedbackstatus: Decodable{
        let status: String!
    }
    
    struct HumanMode: Decodable {
        let  status: String
        let  request_id: String!
        let  result: String!
        let  error: String!
    }
    
    struct GetAllList: Decodable {
        let status: String
        let result: Result
    }
    
    struct Result: Decodable{
        let devices: [DeviceList]!
        let error: [DeviceList]!
    }
    
    struct DeviceList: Decodable {
        let device_id: String!
    }
    
    struct Status: Decodable{
        let status: String!
    }
    
    struct DeviceSettings: Decodable{
        let result: SettingsResult!
    }
    
    struct SettingsResult: Decodable{
        let devices: [Devices]!
    }
    
    struct Devices: Decodable{
        let nodes: [Nodes]!
    }
    
    struct Nodes: Decodable{
        let type: String!
        let status: StatusType!
    }
    
    struct USBConfiguration: Decodable{
        let role: String!
    }
    
    struct Inputs: Decodable {
        let name:String!
        let configuration: Configuration!
    }
    
    struct Configuration: Decodable{
        let source: Source!
    }
    
    struct Source: Decodable{
        let value:UInt16
    }
    
    struct Error: Decodable{
        let result : ErrorResult!
    }
    
    struct ErrorResult: Decodable{
        let error: [ErrorDevicr]!
    }
    
    struct ErrorDevicr: Decodable{
        let message: String!
    }
    //    struct Nodes: Decodable{
    //        let type: String!
    //       // let status: StatusType!
    //    }
    struct StatusType: Decodable{
        let source_video: SourceVideo!
    }
    
    struct SourceVideo: Decodable{
        let width: UInt16!
        let height: UInt16!
    }
    //
    
    //popup device list
    @IBAction func showDeviceList(sender: UIButton) {
        print("showDeviceList")
        self.menu = RSSelectionMenu(dataSource: self.deviceList) { (cell, name, indexPath) in
            cell.textLabel?.text = name
        }
        
        let selectedNames: [String] = []
        // provide selected items
        self.menu.setSelectedItems(items: selectedNames) { (name, index, selected, selectedItems) in
            self.userSelectedDeviceIndex = index
            self.bt_device_id.setTitle(self.deviceList[index], for: .init())
            self.queueTCP.async  {
                self.userSelectedDeviceIndex = index
                self.currentCmdNumber = self._4_get_device_settings
                let cmd = "get " + self.deviceList[index] + " settings\n" //get device identity cmd
                self.isLockRead = true //prepare to read server feedback
                self.receiveData = "" //server feedback data
                self.mSocket.write((cmd.data(using: String.Encoding.utf8))!, withTimeout: -1, tag: 0)//send cmd to server
                
                DispatchQueue.main.async(){
                    self.showLoading()
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.closeLoading()
                    self.isLockRead = false
                    // print(self.receiveData)
                    do {
                        _ = try JSONSerialization.jsonObject(with: self.receiveData.data(using: .utf8)!)
                        
                        let checkFeedbackStatus:CheckFeedbackstatus  = try! JSONDecoder().decode(CheckFeedbackstatus.self, from: self.receiveData.data(using: .utf8)!)
                        
                        if(checkFeedbackStatus.status == "SUCCESS"){
                            let device_settings: DeviceSettings = try! JSONDecoder().decode(DeviceSettings.self, from: self.receiveData.data(using: .utf8)!)
                            
                            for indexNodes in device_settings.result.devices[0].nodes{
                                
                                //  print(indexNodes.self.type)
                                if(indexNodes.self.type == "FRAME_BUFFER"){
                                    print(String(indexNodes.self.status.source_video.width) + " * " + String(indexNodes.self.status.source_video.height))
                                    
                                    self.label_resolution.text = String(indexNodes.self.status.source_video.width) + " * " + String(indexNodes.self.status.source_video.height)
                                    self.source_width = Int(indexNodes.self.status.source_video.width)
                                    self.source_height = Int(indexNodes.self.status.source_video.height)
                                }
                                
                            }
                        }else{
                            DispatchQueue.main.async {
                                self.view.makeToast("Request timeout")
                            }
                            
                        }
                        
                        
                    } catch {
                        
                        print("Error deserializing JSON: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            self.view.makeToast("Request timeout")
                        }
                    }
                    
                    
                }
                
                while(true){
                    if(self.isLockRead){
                        self.mSocket.readData(withTimeout: -1, tag: 0)
                    }else{
                        break
                    }
                }
            }
            
            
        }
        self.menu.show(from: self)
    }
    
    //popup H number
    @IBAction func showHNumber(sender: UIButton) {
        let popup = PopupDialog(title: nil, message: "Select Horizontal Cut", image: nil)
        // 1 buttons
        let buttonl = CancelButton(title: "1") {
            self.userSelectedHCut = 1
            self.bt_h.setTitle("1", for: .init())
            self.bt_number.setTitle("1", for: .init())
            self.userSelectedNumber = 1
        }
        
        // 2 buttons
        let button2 = CancelButton(title: "2") {
            self.userSelectedHCut = 2
            self.bt_h.setTitle("2", for: .init())
            self.bt_number.setTitle("1", for: .init())
            self.userSelectedNumber = 1
        }
        
        // 3 buttons
        let button3 = CancelButton(title: "3") {
            self.userSelectedHCut = 3
            self.bt_h.setTitle("3", for: .init())
            self.bt_number.setTitle("1", for: .init())
            self.userSelectedNumber = 1
        }
        
        // 4 buttons
        let button4 = CancelButton(title: "4") {
            self.userSelectedHCut = 4
            self.bt_h.setTitle("4", for: .init())
            self.bt_number.setTitle("1", for: .init())
            self.userSelectedNumber = 1
        }
        
        // Create buttons
        let buttonCancel = CancelButton(title: "Cancel") {
            
        }
        // Add buttons to dialog
        // Alternatively, you can use popup.addButton(buttonOne)
        // to add a single button
        popup.addButtons([buttonl, button2, button3, button4, buttonCancel])
        
        // Present dialog
        self.present(popup, animated: true, completion: nil)
    }
    
    //popup V number
    @IBAction func showVNumber(sender: UIButton) {
        let popup = PopupDialog(title: nil, message: "Select Vertical Cut", image: nil)
        // 1 buttons
        let buttonl = CancelButton(title: "1") {
            self.userSelectedVCut = 1
            self.bt_v.setTitle("1", for: .init())
            self.bt_number.setTitle("1", for: .init())
            self.userSelectedNumber = 1
        }
        
        // 2 buttons
        let button2 = CancelButton(title: "2") {
            self.userSelectedVCut = 2
            self.bt_v.setTitle("2", for: .init())
            self.bt_number.setTitle("1", for: .init())
            self.userSelectedNumber = 1
        }
        
        // 3 buttons
        let button3 = CancelButton(title: "3") {
            self.userSelectedVCut = 3
            self.bt_v.setTitle("3", for: .init())
            self.bt_number.setTitle("1", for: .init())
            self.userSelectedNumber = 1
        }
        
        // 4 buttons
        let button4 = CancelButton(title: "4") {
            self.userSelectedVCut = 4
            self.bt_v.setTitle("4", for: .init())
            self.bt_number.setTitle("1", for: .init())
            self.userSelectedNumber = 1
        }
        
        // Create buttons
        let buttonCancel = CancelButton(title: "Cancel") {
            
        }
        // Add buttons to dialog
        // Alternatively, you can use popup.addButton(buttonOne)
        // to add a single button
        popup.addButtons([buttonl, button2, button3, button4, buttonCancel])
        
        // Present dialog
        self.present(popup, animated: true, completion: nil)
    }
    
    
    
    //popup number number
    @IBAction func showNumber(sender: UIButton) {
        let popup = PopupDialog(title: nil, message: "Select which number of the display wall to show", image: nil)
        
        let total = self.userSelectedHCut * self.userSelectedVCut
        var buttonArray = [CancelButton]()
        for i in 1...total {
            let tempButton = CancelButton(title: String(i)) {
                self.userSelectedNumber = i
                self.bt_number.setTitle(String(i), for: .init())
            }
            buttonArray.append(tempButton)
        }
        
        popup.addButtons(buttonArray)
        
        // Present dialog
        self.present(popup, animated: true, completion: nil)
    }
    
    
    //popup number number
    @IBAction func sendCMD(sender: UIButton) {
        if(self.userSelectedDeviceIndex > -1){
            
            DispatchQueue.main.async(){
                self.showLoading()
            }
            
            var tempNumber: Int = self.userSelectedNumber - 1
            // print(String(self.userSelectedNumber) + "-" + String(self.userSelectedVCut) +  "-" + String(self.userSelectedHCut) + "-"  )
            let CutWidth = (self.source_width / self.userSelectedHCut)
            
            let CutHeight = (self.source_height / self.userSelectedVCut)
            
            let HStart = ((tempNumber % self.userSelectedHCut) * CutWidth)
            let VStart = ((tempNumber / self.userSelectedHCut) * CutHeight)
            
            var resolution: String = ""
            switch self.userSelectedHDMIType{
                
            case 0:
                resolution = "3840 2160"
                break
                
            case 1:
                resolution = "1920 1080"
                break
                
            case 2:
                resolution = "1280 720"
                break
                
            default:
                
                break
            }
            // let cmd = "set "+ 0016c04c4370+" video wall size "+  1920 1080+" fps 60 offset " +960+" "+540 +" keep "+ 960 540 +"\n"
            let cmd = "set " + self.deviceList[self.userSelectedDeviceIndex] + " video wall size " + resolution + " fps 60 offset "
                + String(HStart) + " " + String(VStart) + " keep " + String(CutWidth) + " " + String(CutHeight) + "\n"
            print(cmd)
            self.queueTCP.async  {
                self.currentCmdNumber = self._5_set_display_wall
                self.mSocket.write((cmd.data(using: String.Encoding.utf8))!, withTimeout: -1, tag: 0)
                self.mSocket.readData(withTimeout: 1, tag: 0)
            }
        }else{
            
        }
        
        
    }
    
    //show toast
    func ShowToast(message: String){
        DispatchQueue.main.async() {
            self.view.makeToast(message, duration: 2.0, position: .bottom)
        }
    }
    
    
}
