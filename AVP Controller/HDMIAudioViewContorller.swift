//
//  HDMIAudioViewContorller.swift
//  AVP Controller
//
//  Created by 啟發電子 on 2020/4/24.
//  Copyright © 2020 gomax. All rights reserved.
//

import UIKit
import CocoaAsyncSocket
import RSSelectionMenu
import Toast_Swift

class HDMIAudioViewContorller: UIViewController, GCDAsyncSocketDelegate{
    
    var mSocket:GCDAsyncSocket!
    var queueTCP: DispatchQueue!
    var currentCmdNumber = 0// current send cnmd number
    let _1_cmd_mode_human = 1
    let _2_cmd_require_blueriver_api_2_19_0 = 2
    let _3_get_all_list = 3
    let _4_get_device_settings = 4
    let _5_set_device_hdmi_audio = 5
    let _6_change_hdmi_audio_source = 6
    let _7_start_hdmi_audio_source = 7
    let _8_stop_hdmi_audio_source = 8
    let _9_leave_hdmi_audio_source = 9
    var deviceList: Array<String> = []
    var menu: RSSelectionMenu<String>!
    var lebalResolution: UILabel!
    var alert: UIAlertController!
    var isConnected = false//check is connecting or not
    let preferences = UserDefaults.standard
    var receiveData: String = ""//server feedback
    var isLockRead: Bool = false//is reading server feedback
    var bt_hdmi_output: UIButton!
    var bt_hdmi_audio_source: UIButton!
    var bt_device_id: UIButton!
    var userSelectedDeviceIndex = -1//recoed user select which device id
    var userSelectedHDMIAudioOutputIndex = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.alert = UIAlertController(title: nil, message: "Please wait...", preferredStyle: .alert)
        self.bt_device_id = self.view.viewWithTag(401) as? UIButton
        self.bt_hdmi_audio_source = self.view.viewWithTag(403) as? UIButton
        self.bt_hdmi_output = self.view.viewWithTag(402) as? UIButton
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        print("HDMIAudioViewContorller-viewDidAppear")
        self.bt_hdmi_output.setTitle(CmdHelper.hdmi_audio_array[0], for: .init())
        self.userSelectedDeviceIndex = -1
        self.userSelectedHDMIAudioOutputIndex = 0
        self.currentCmdNumber = 0
        self.bt_device_id.setTitle("Select Device", for: .init())
        self.bt_hdmi_audio_source.setTitle("Select Device", for: .init())
        self.isConnected = false
        self.queueTCP = DispatchQueue(label: "com.gofanco.tcp", qos: DispatchQoS.userInitiated)
        self.deviceList.removeAll()
        // self.tableDeviceList.reloadData()
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
    
    override func viewDidDisappear(_ animated: Bool) {
        print("HDMIAudioViewContorller-viewDidDisappear")
        queueTCP.async {
            if( self.mSocket != nil){
                
                self.mSocket.disconnect()
                self.mSocket = nil
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        print("HDMIAudioViewContorller-didAcceptNewSocket")
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print("HDMIAudioViewContorller-socketDidDisconnect")
        self.isConnected = false
    }
    
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("HDMIAudioViewContorller-didConnectToHost")
        self.isConnected = true
        self.queueTCP.asyncAfter(deadline: .now() + 0.5){
            print("send command")
            self.currentCmdNumber = self._1_cmd_mode_human
            self.mSocket.write((CmdHelper.cmd_human_mode.data(using: String.Encoding.utf8))!, withTimeout: -1, tag: 0)
            self.mSocket.readData(withTimeout: -1, tag: 0)
        }
    }
    
    public func socket(_ sock: GCDAsyncSocket, didRead: Data, withTag tag:CLong){
        print("HDMIAudioViewContorller-didRead")
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
                let blueriver_api: HumanMode = try! JSONDecoder().decode(HumanMode.self, from: didRead)
                if(blueriver_api.status == "SUCCESS"){
                    print("initial successful")
                    self.isLockRead = true
                    self.currentCmdNumber = self._3_get_all_list
                    self.deviceList.removeAll()
                    self.receiveData = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.isLockRead = false
                        
                        do {
                            _ = try JSONSerialization.jsonObject(with: self.receiveData.data(using: .utf8)!)
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
            
        case self._5_set_device_hdmi_audio:
            print("_5_set_device_hdmi_audio")
            print(String(decoding: didRead, as: UTF8.self))
            
            DispatchQueue.main.async(){
                self.closeLoading()
            }
            feedBackUser(didRead: didRead)
            
            break;
            
        case self._6_change_hdmi_audio_source:
            print("_6_change_hdmi_audio_source")
            print(String(decoding: didRead, as: UTF8.self))
            
            DispatchQueue.main.async(){
                self.closeLoading()
            }
            feedBackUser(didRead: didRead)
            
            break;
            
        case self._7_start_hdmi_audio_source:
            print("_7_start_hdmi_audio_source")
            print(String(decoding: didRead, as: UTF8.self))
            
            DispatchQueue.main.async(){
                self.closeLoading()
            }
            feedBackUser(didRead: didRead)
            
            
            break;
            
        case self._8_stop_hdmi_audio_source:
            print("_8_stop_hdmi_audio_source")
            print(String(decoding: didRead, as: UTF8.self))
            
            DispatchQueue.main.async(){
                self.closeLoading()
            }
            feedBackUser(didRead: didRead)
            
            break;
            
            
        case self._9_leave_hdmi_audio_source:
            print("_9_leave_hdmi_audio_source")
            print(String(decoding: didRead, as: UTF8.self))
            
            DispatchQueue.main.async(){
                self.closeLoading()
            }
            feedBackUser(didRead: didRead)
            
            break;
        default:
            print("default")
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
                    
                    do {
                        _ = try JSONSerialization.jsonObject(with: self.receiveData.data(using: .utf8)!)
                        
                        let device_settings: DeviceSettings = try! JSONDecoder().decode(DeviceSettings.self, from: self.receiveData.data(using: .utf8)!)
                        for indexNodes in device_settings.result.devices[0].nodes{
                            
                            print(indexNodes.self.type)
                            if(indexNodes.self.type == "HDMI_ENCODER"){
                                print("inputs cout " + String(indexNodes.self.inputs.count))
                                for indexInputs in indexNodes.self.inputs{
                                    print(indexInputs.name)
                                    if(indexInputs.name == "audio"){
                                        print(indexInputs.configuration.source.value)
                                        switch indexInputs.configuration.source.value{
                                            
                                        case 2:
                                            self.userSelectedHDMIAudioOutputIndex = 0
                                            self.bt_hdmi_output.setTitle(CmdHelper.hdmi_audio_array[0], for: .init())
                                            break
                                            
                                        case 6:
                                            self.userSelectedHDMIAudioOutputIndex = 1
                                            self.bt_hdmi_output.setTitle(CmdHelper.hdmi_audio_array[1], for: .init())
                                            break
                                            
                                        case 7:
                                            self.userSelectedHDMIAudioOutputIndex = 2
                                            self.bt_hdmi_output.setTitle(CmdHelper.hdmi_audio_array[2], for: .init())
                                            break
                                            
                                        case 8:
                                            self.userSelectedHDMIAudioOutputIndex = 3
                                            self.bt_hdmi_output.setTitle(CmdHelper.hdmi_audio_array[3], for: .init())
                                            break
                                            
                                        case 9:
                                            self.userSelectedHDMIAudioOutputIndex = 4
                                            self.bt_hdmi_output.setTitle(CmdHelper.hdmi_audio_array[4], for: .init())
                                            break
                                            
                                        default:
                                            break
                                        }
                                    }
                                }
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
    
    //show toast
    func ShowToast(message: String){
        DispatchQueue.main.async() {
            self.view.makeToast(message, duration: 2.0, position: .bottom)
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
                
                self.bt_hdmi_audio_source.setTitle(self.deviceList[index], for: .init())
                
                var cmd:String = ""
                
                switch self.userSelectedHDMIAudioOutputIndex{
                    
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
                        ":HDMI_AUDIO:0 " + self.deviceList[self.userSelectedDeviceIndex] + ":0\n"
                    break
                    
                case 3:
                    cmd = "join " + self.deviceList[index] +
                        ":I2S_AUDIO:0 "  + self.deviceList[self.userSelectedDeviceIndex] + ":0\n"
                    break
                    
                case 4:
                    cmd = "join " + self.deviceList[index] +
                        ":I2S_AUDIO:0 "  + self.deviceList[self.userSelectedDeviceIndex] + ":0\n"
                    break
                    
                default:
                    
                    break
                    
                    
                    
                }
                print(cmd)
                self.currentCmdNumber = self._6_change_hdmi_audio_source
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
    
    //popup HDMI Audio type
    @IBAction func showHDMIAudioOutputList(sender: UIButton) {
        
        if(self.userSelectedDeviceIndex > -1){
            DispatchQueue.main.async(){
                self.showLoading()
            }
            self.menu = RSSelectionMenu(dataSource: CmdHelper.hdmi_audio_array) { (cell, name, indexPath) in
                cell.textLabel?.text = name
            }
            
            let selectedNames: [String] = []
            // provide selected items
            self.menu.setSelectedItems(items: selectedNames) { (name, index, selected, selectedItems) in
                
                self.bt_hdmi_output.setTitle(CmdHelper.hdmi_audio_array[index], for: .init())
                
                var cmd:String = ""
                
                switch index{
                    
                case 0:
                    self.userSelectedHDMIAudioOutputIndex = 0
                    cmd = "set " + self.deviceList[self.userSelectedDeviceIndex] + " property nodes[HDMI_ENCODER:0].inputs[audio:0].configuration.source.value 2\n"
                    break
                    
                case 1:
                    self.userSelectedHDMIAudioOutputIndex = 1
                    cmd = "set " + self.deviceList[self.userSelectedDeviceIndex] + " property nodes[HDMI_ENCODER:0].inputs[audio:0].configuration.source.value 6\n"
                    break
                    
                    
                case 2:
                    self.userSelectedHDMIAudioOutputIndex = 2
                    cmd = "set " + self.deviceList[self.userSelectedDeviceIndex] + " property nodes[HDMI_ENCODER:0].inputs[audio:0].configuration.source.value 7\n"
                    break
                    
                case 3:
                    self.userSelectedHDMIAudioOutputIndex = 3
                    cmd = "set " + self.deviceList[self.userSelectedDeviceIndex] + " property nodes[HDMI_ENCODER:0].inputs[audio:0].configuration.source.value 8\n"
                    break
                    
                case 4:
                    self.userSelectedHDMIAudioOutputIndex = 4
                    cmd = "set " + self.deviceList[self.userSelectedDeviceIndex] + " property nodes[HDMI_ENCODER:0].inputs[audio:0].configuration.source.value 9\n"
                    break
                    
                default:
                    
                    break
                }
                
                self.currentCmdNumber = self._5_set_device_hdmi_audio
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
    
    //sned start HDMI Audio
    @IBAction func sendStartHDMIAudio(sender: UIButton) {
        if(self.userSelectedDeviceIndex > -1){
            DispatchQueue.main.async(){
                self.showLoading()
            }
            var cmd:String = "start " + self.deviceList[self.userSelectedDeviceIndex] + ":HDMI_AUDIO:0\n"
            self.currentCmdNumber = self._7_start_hdmi_audio_source
            self.mSocket.write((cmd.data(using: String.Encoding.utf8))!, withTimeout: -1, tag: 0)//send cmd to server
            self.mSocket.readData(withTimeout: -1, tag: 0)
        }else{
             DispatchQueue.main.async(){
                          self.ShowToast(message:"Please select Device first !")
                      }
        }
    }
    
    //sned stop HDMI Audio
    @IBAction func sendStopHDMIAudio(sender: UIButton) {
        if(self.userSelectedDeviceIndex > -1){
            DispatchQueue.main.async(){
                self.showLoading()
            }
            var cmd:String = "stop " + self.deviceList[self.userSelectedDeviceIndex] + ":HDMI_AUDIO:0\n"
            self.currentCmdNumber = self._8_stop_hdmi_audio_source
            self.mSocket.write((cmd.data(using: String.Encoding.utf8))!, withTimeout: -1, tag: 0)//send cmd to server
            self.mSocket.readData(withTimeout: -1, tag: 0)
        }else{
              DispatchQueue.main.async(){
                          self.ShowToast(message:"Please select Device first !")
                      }
        }
    }
    
    //sned leave HDMI Audio
    @IBAction func sendLeaveHDMIAudio(sender: UIButton) {
        if(self.userSelectedDeviceIndex > -1){
            DispatchQueue.main.async(){
                self.showLoading()
            }
            var cmd:String = "leave " + self.deviceList[self.userSelectedDeviceIndex] + ":HDMI_AUDIO:0\n"
            self.currentCmdNumber = self._9_leave_hdmi_audio_source
            self.mSocket.write((cmd.data(using: String.Encoding.utf8))!, withTimeout: -1, tag: 0)//send cmd to server
            self.mSocket.readData(withTimeout: -1, tag: 0)
        }else{
              DispatchQueue.main.async(){
                          self.ShowToast(message:"Please select Device first !")
                      }
        }
    }
}
