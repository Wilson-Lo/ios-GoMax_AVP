//
//  I2SAudioViewController.swift
//  AVP Controller
//
//  Created by 啟發電子 on 2020/4/24.
//  Copyright © 2020 gomax. All rights reserved.
//

import UIKit
import CocoaAsyncSocket
import RSSelectionMenu
import Toast_Swift
import RSSelectionMenu

class I2SAudioViewController: UIViewController, GCDAsyncSocketDelegate{
    
    var mSocket:GCDAsyncSocket!
    var queueTCP: DispatchQueue!
    var alert: UIAlertController!
    let preferences = UserDefaults.standard
    var isConnected = false
    let _1_cmd_mode_human = 1
    let _2_cmd_require_blueriver_api_2_19_0 = 2
    let _3_get_all_list = 3
    let _4_get_device_settings = 4
    let _5_set_I2S_output = 5
    let _6_start_I2S_output = 6
    let _7_stop_I2S_output = 7
    let _8_leave_I2S_output = 8
    let _9_change_source = 9
    var currentCmdNumber = 0// current send cnmd number
    var deviceList: Array<String> = []
    var receiveData: String = ""
    var isLockRead: Bool = false
    var bt_device_id: UIButton!
    var bt_i2s_output: UIButton!
    var bt_i2s_change_source: UIButton!
    var menu: RSSelectionMenu<String>!
    var userSelectedDeviceIndex = -1//recoed user select which device id
    var userSelectedI2SAudioOutputIndex = 0
    private var checkConnectStatusWork: DispatchWorkItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.alert = UIAlertController(title: nil, message: "Please wait...", preferredStyle: .alert)
        self.bt_device_id = self.view.viewWithTag(501) as? UIButton
        self.bt_i2s_output = self.view.viewWithTag(502) as? UIButton
        self.bt_i2s_change_source = self.view.viewWithTag(503) as? UIButton
        
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        print("I2SAudioViewController-viewDidAppear")
        self.checkConnectStatusWork  = DispatchWorkItem(block: {
            if(!self.isConnected){
                self.closeLoading()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.view.makeToast("Request timeout !", duration: 2.0, position: .bottom)
                }
            }
        })
        self.userSelectedDeviceIndex = -1
        self.userSelectedI2SAudioOutputIndex = 0
        self.bt_device_id.setTitle("Select Device", for: .init())
        self.bt_i2s_change_source.setTitle("Select Device", for: .init())
        self.bt_i2s_output.setTitle(CmdHelper.i2s_audio_array[0], for: .init())
        self.queueTCP = DispatchQueue(label: "com.gofanco.tcp", qos: DispatchQoS.userInitiated)
        if(preferences.value(forKey: key_server_ip) != nil){
            let fullIP = preferences.value(forKey: key_server_ip) as! String
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: self.checkConnectStatusWork!)
                    
                } catch let error {
                    print("error to connect device")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: self.checkConnectStatusWork!)
                }
                
                
            }
        }
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        print("I2SAudioViewController-viewDidDisappear")
        
        queueTCP.async {
              self.checkConnectStatusWork?.cancel()
            self.receiveData = ""
            if(self.mSocket != nil){
                self.mSocket.disconnect()
                self.mSocket = nil
            }
        }
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print("I2SAudioViewController-socketDidDisconnect")
        self.isConnected = false
    }
    
    
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("I2SAudioViewController-didConnectToHost")
        self.isConnected = true
        self.queueTCP.asyncAfter(deadline: .now() + 0.5) {
            print("send command")
            self.currentCmdNumber = self._1_cmd_mode_human
            self.mSocket.write((CmdHelper.cmd_human_mode.data(using: String.Encoding.utf8))!, withTimeout: -1, tag: 0)
            self.mSocket.readData(withTimeout: -1, tag: 0)
        }
    }
    
    public func socket(_ sock: GCDAsyncSocket, didRead: Data, withTag tag:CLong){
        print("I2SAudioViewController-didRead")
        
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
            
        case self._5_set_I2S_output:
            print("_5_set_I2S_output")
            DispatchQueue.main.async(){
                self.closeLoading()
            }
            feedBackUser(didRead: didRead)
            break
            
        case self._6_start_I2S_output:
            print("_6_start_I2S_output")
            DispatchQueue.main.async(){
                self.closeLoading()
            }
            feedBackUser(didRead: didRead)
            break
            
        case self._7_stop_I2S_output:
            print("_7_stop_I2S_output")
            DispatchQueue.main.async(){
                self.closeLoading()
            }
            feedBackUser(didRead: didRead)
            break
            
        case self._8_leave_I2S_output:
            print("_8_leave_I2S_output")
            DispatchQueue.main.async(){
                self.closeLoading()
            }
            feedBackUser(didRead: didRead)
            break
            
        case self._9_change_source:
            print("_9_change_source")
            DispatchQueue.main.async(){
                self.closeLoading()
            }
            feedBackUser(didRead: didRead)
            break
            
            
        default:
            
            break
        }
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
        let inputs:[Inputs]
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
    
    //popup device list
    @IBAction func showDeviceList(sender: UIButton) {
        print("showDeviceList")
        self.menu = RSSelectionMenu(dataSource: self.deviceList) { (cell, name, indexPath) in
            cell.textLabel?.text = name
        }
        
        let selectedNames: [String] = []
        // provide selected items
        self.menu.setSelectedItems(items: selectedNames) { (name, index, selected, selectedItems) in
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
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.closeLoading()
                    self.isLockRead = false
                    // print(self.receiveData)
                    
                    do {
                        _ = try JSONSerialization.jsonObject(with: self.receiveData.data(using: .utf8)!)
                        
                        let checkFeedbackStatus:CheckFeedbackstatus  = try! JSONDecoder().decode(CheckFeedbackstatus.self, from: self.receiveData.data(using: .utf8)!)
                        
                        if(checkFeedbackStatus.status == "SUCCESS"){
                            let device_settings: DeviceSettings = try! JSONDecoder().decode(DeviceSettings.self, from: self.receiveData.data(using: .utf8)!)
                            
                            if(device_settings.result.devices.count > 0){
                                for indexNodes in device_settings.result.devices[0].nodes{
                                    
                                    if(indexNodes.self.type == "I2S_AUDIO_OUTPUT"){
                                        
                                        for indexInputs in indexNodes.self.inputs{
                                            
                                            if(indexInputs.name == "main"){
                                                print(indexInputs.configuration.source.value)
                                                switch indexInputs.configuration.source.value{
                                                case 6:
                                                    self.userSelectedI2SAudioOutputIndex = 0
                                                    self.bt_i2s_output.setTitle(CmdHelper.i2s_audio_array[0], for: .init())
                                                    break
                                                    
                                                case 7:
                                                    self.userSelectedI2SAudioOutputIndex = 1
                                                    self.bt_i2s_output.setTitle(CmdHelper.i2s_audio_array[1], for: .init())
                                                    break
                                                    
                                                case 8:
                                                    self.userSelectedI2SAudioOutputIndex = 2
                                                    self.bt_i2s_output.setTitle(CmdHelper.i2s_audio_array[2], for: .init())
                                                    break
                                                default:
                                                    break
                                                }
                                            }
                                        }
                                    }
                                }
                            }else{
                                DispatchQueue.main.async {
                                    self.view.makeToast("Request timeout")
                                }
                            }
                            
                        }else{
                            DispatchQueue.main.async(){
                                self.ShowToast(message:"Please select Device first !")
                            }
                        }
                        
                    } catch {
                        
                        print("Error deserializing JSON: \(error.localizedDescription)")
                        DispatchQueue.main.async(){
                            self.ShowToast(message:"Please select Device first !")
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
    
    //popup device list
    @IBAction func showI2SAudioOuptList(sender: UIButton) {
        
        
        if(self.userSelectedDeviceIndex > -1){
            self.menu = RSSelectionMenu(dataSource: CmdHelper.i2s_audio_array) { (cell, name, indexPath) in
                cell.textLabel?.text = name
            }
            
            let selectedNames: [String] = []
            // provide selected items
            self.menu.setSelectedItems(items: selectedNames) { (name, index, selected, selectedItems) in
                
                self.bt_i2s_output.setTitle(CmdHelper.i2s_audio_array[index], for: .init())
                self.currentCmdNumber = self._5_set_I2S_output
                var cmd = "" //get device identity cmd
                self.isLockRead = true //prepare to read server feedback
                self.receiveData = "" //server feedback data
                
                
                switch index{
                    
                case 0:
                    self.userSelectedI2SAudioOutputIndex = 0
                    cmd = "set " + self.deviceList[self.userSelectedDeviceIndex] + " property nodes[I2S_AUDIO_OUTPUT:0].inputs[main:0].configuration.source.value 6\n"
                    break
                    
                case 1:
                    self.userSelectedI2SAudioOutputIndex = 1
                    cmd = "set " + self.deviceList[self.userSelectedDeviceIndex] + " property nodes[I2S_AUDIO_OUTPUT:0].inputs[main:0].configuration.source.value 7\n"
                    break
                    
                case 2:
                    self.userSelectedI2SAudioOutputIndex = 2
                    cmd = "set " + self.deviceList[self.userSelectedDeviceIndex] + " property nodes[I2S_AUDIO_OUTPUT:0].inputs[main:0].configuration.source.value 8\n"
                    break
                    
                default:
                    
                    break
                }
                self.queueTCP.async  {
                    self.mSocket.write((cmd.data(using: String.Encoding.utf8))!, withTimeout: -1, tag: 0)//send cmd to server
                    self.mSocket.readData(withTimeout: -1, tag: 0)
                }
                
            }
            self.menu.show(from: self)
        }else{
            DispatchQueue.main.async(){
                self.ShowToast(message:"Please select Device first !")
            }
            
        }
        
    }
    
    
    //popup HDMI Audio source
    @IBAction func showSourceList(sender: UIButton) {
        
        if(self.userSelectedDeviceIndex > -1){
            DispatchQueue.main.async(){
                self.showLoading()
            }
            self.menu = RSSelectionMenu(dataSource: self.deviceList) { (cell, name, indexPath) in
                cell.textLabel?.text = name
            }
            
            let selectedNames: [String] = []
            // provide selected items
            self.menu.setSelectedItems(items: selectedNames) { (name, index, selected, selectedItems) in
                
                self.bt_i2s_change_source.setTitle(self.deviceList[index], for: .init())
                
                var cmd = ""
                
                switch self.userSelectedI2SAudioOutputIndex {
                    
                case 0:
                    cmd = "join " + self.deviceList[index] +
                        ":HDMI_AUDIO:0 " + self.deviceList[self.userSelectedDeviceIndex] + ":0\n"
                    break
                    
                case 1:
                    cmd = "join " + self.deviceList[index] +
                        ":HDMI_AUDIO:0 " + self.deviceList[self.userSelectedDeviceIndex] + ":0\n"
                    break
                    
                case 2:
                    cmd = "join " + self.deviceList[index] +
                        ":I2S_AUDIO:0 "  + self.deviceList[self.userSelectedDeviceIndex] + ":0\n"
                    break
                    
                default:
                    
                    break
                    
                }
                self.currentCmdNumber = self._9_change_source
                self.mSocket.write((cmd.data(using: String.Encoding.utf8))!, withTimeout: -1, tag: 0)//send cmd to server
                self.mSocket.readData(withTimeout: -1, tag: 0)
            }
            self.menu.show(from: self)
        }else{
            DispatchQueue.main.async(){
                self.ShowToast(message:"Please select Device first !")
            }
        }
        
    }
    
    
    //show toast
    func ShowToast(message: String){
        DispatchQueue.main.async() {
            self.view.makeToast(message, duration: 2.0, position: .bottom)
        }
    }
    
    
    //sned start I2S Audio
    @IBAction func sendStartHDMIAudio(sender: UIButton) {
        if(self.userSelectedDeviceIndex > -1){
            DispatchQueue.main.async(){
                self.showLoading()
            }
            let cmd:String = "start " + self.deviceList[self.userSelectedDeviceIndex] + ":I2S_AUDIO:0\n"
            self.currentCmdNumber = self._6_start_I2S_output
            self.mSocket.write((cmd.data(using: String.Encoding.utf8))!, withTimeout: -1, tag: 0)//send cmd to server
            self.mSocket.readData(withTimeout: -1, tag: 0)
        }else{
            ShowToast(message:"Please select Device first !")
        }
    }
    
    //sned stop I2S Audio
    @IBAction func sendStopHDMIAudio(sender: UIButton) {
        if(self.userSelectedDeviceIndex > -1){
            DispatchQueue.main.async(){
                self.showLoading()
            }
            let cmd:String = "stop " + self.deviceList[self.userSelectedDeviceIndex] + ":I2S_AUDIO:0\n"
            self.currentCmdNumber = self._7_stop_I2S_output
            self.mSocket.write((cmd.data(using: String.Encoding.utf8))!, withTimeout: -1, tag: 0)//send cmd to server
            self.mSocket.readData(withTimeout: -1, tag: 0)
        }else{
            ShowToast(message:"Please select Device first !")
        }
    }
    
    //sned leave I2S Audio
    @IBAction func sendLeaveHDMIAudio(sender: UIButton) {
        if(self.userSelectedDeviceIndex > -1){
            DispatchQueue.main.async(){
                self.showLoading()
            }
            let cmd:String = "leave " + self.deviceList[self.userSelectedDeviceIndex] + ":I2S_AUDIO:0\n"
            self.currentCmdNumber = self._8_leave_I2S_output
            self.mSocket.write((cmd.data(using: String.Encoding.utf8))!, withTimeout: -1, tag: 0)//send cmd to server
            self.mSocket.readData(withTimeout: -1, tag: 0)
        }else{
            ShowToast(message:"Please select Device first !")
        }
    }
}
