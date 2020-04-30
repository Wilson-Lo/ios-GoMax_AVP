//
//  DeviceListViewController.swift
//  AVP Controller
//
//  Created by 啟發電子 on 2020/4/24.
//  Copyright © 2020 gomax. All rights reserved.
//

import UIKit
import CocoaAsyncSocket
import SwiftSocket
import RSSelectionMenu
import Toast_Swift
import PopupDialog


class DeviceListViewController: UIViewController, GCDAsyncSocketDelegate, UITableViewDataSource, UITableViewDelegate{
    
    var queueTCP: DispatchQueue!
    var mSocket:GCDAsyncSocket!
    let preferences = UserDefaults.standard
    var alert: UIAlertController!
    var isConnected = false
    var currentCmdNumber = 0
    let _1_cmd_mode_human = 1
    let _2_cmd_require_blueriver_api_2_19_0 = 2
    let _3_get_all_list = 3
    let _4_device_identity = 4
    var deviceList: Array<String> = []
    var receiveData: String = ""
    var isLockRead: Bool = false
    
    private var checkConnectStatusWork: DispatchWorkItem?
    @IBOutlet weak var tableDeviceList: UITableView!
    
    override func viewDidLoad() {
        print("DeviceListViewController-viewDidLoad")
        self.alert = UIAlertController(title: nil, message: "Please wait...", preferredStyle: .alert)
        self.tableDeviceList = self.view.viewWithTag(301) as? UITableView
        let nib = UINib(nibName: "CustomTableViewCellDevice", bundle: nil)
        self.tableDeviceList.register(nib, forCellReuseIdentifier: "CutomTableRowCell")
        self.tableDeviceList.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        print("DeviceListViewController-viewWillAppear")
        self.checkConnectStatusWork  = DispatchWorkItem(block: {
            if(!self.isConnected){
                self.closeLoading()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.view.makeToast("Request timeout !", duration: 2.0, position: .bottom)
                }
            }
        })
        self.isConnected = false
        self.deviceList.removeAll()
        self.tableDeviceList.reloadData()
        self.queueTCP = DispatchQueue(label: "com.gofanco.tcp", qos: DispatchQoS.userInitiated)
        if(preferences.value(forKey: key_server_ip) != nil){
            let fullIP = preferences.value(forKey: key_server_ip) as! String
            print("ip = " + fullIP)
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
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        print("DeviceListViewController-didAcceptNewSocket")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        print("DeviceListViewController-viewDidDisappear")
        queueTCP.async {
              self.checkConnectStatusWork?.cancel()
            if(self.mSocket != nil){
                self.receiveData = ""
                self.mSocket.disconnect()
                self.mSocket = nil
            }
        }
    }
    func socket(_ sock: GCDAsyncSocket, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        print("DeviceListViewController-didReceive")
    }
    
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("DeviceListViewController-didConnectToHost")
        self.isConnected = true
        self.queueTCP.asyncAfter(deadline: .now() + 0.5) {
            self.currentCmdNumber = self._1_cmd_mode_human
            self.mSocket.write((CmdHelper.cmd_human_mode.data(using: String.Encoding.utf8))!, withTimeout: -1, tag: 0)
            self.mSocket.readData(withTimeout: -1, tag: 0)
        }
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead : Data, withTag tag: Int) {
        print("DeviceListViewController-didRead")
        switch self.currentCmdNumber {
            
        case self._1_cmd_mode_human:
            print("_1_cmd_mode_human")
            do {
                _ = try JSONSerialization.jsonObject(with: didRead)
                let humanMode: HumanMode = try! JSONDecoder().decode(HumanMode.self, from: didRead)
                if(humanMode.status == "SUCCESS"){
                    self.queueTCP.async  {
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
                let blueriver_api: HumanMode = try! JSONDecoder().decode(HumanMode.self, from: didRead)
                if(blueriver_api.status == "SUCCESS"){
                    print("initial successful")
                    self.currentCmdNumber = self._3_get_all_list
                    self.deviceList.removeAll()
                    self.receiveData = ""
                    self.isLockRead = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.isLockRead = false
                        do {
                            _ = try JSONSerialization.jsonObject(with: self.receiveData.data(using: .utf8)!)
                            print("Valid Json")
                            print(self.receiveData)
                            let checkFeedbackStatus:CheckFeedbackstatus  = try! JSONDecoder().decode(CheckFeedbackstatus.self, from: self.receiveData.data(using: .utf8)!)
                            
                            if(checkFeedbackStatus.status == "SUCCESS"){
                                let get_all_list: GetAllList = try! JSONDecoder().decode(GetAllList.self, from: self.receiveData.data(using: .utf8)!)
                                if(get_all_list.result.devices.count > 0){
                                    for index in get_all_list.result.devices{
                                        self.deviceList.append(index.device_id)
                                    }
                                    
                                    DispatchQueue.main.async {
                                        self.closeLoading()
                                        self.tableDeviceList.reloadData()
                                    }
                                }
                            }else{
                                self.closeLoading()
                                self.ShowToast(message: "Request timeout")
                                
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
                    self.closeLoading()
                    self.ShowToast(message: "Request timeout")
                }
            }
            
            
            
            break
            
        case self._3_get_all_list:
            print("_3_get_all_list")
            if(self.isLockRead && didRead != nil){
                self.receiveData.append(String(decoding: didRead, as: UTF8.self))
            }
            break
            
        case self._4_device_identity:
            print("_4_device_identity")
            //print(didRead)
            if(self.isLockRead && didRead != nil){
                self.receiveData.append(String(decoding: didRead, as: UTF8.self))
            }
            break
            
        default:
            print("default")
            break
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
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CutomTableRowCell", for: indexPath) as! CustomTableViewCellDevice;
        cell.label_device_id.text = self.deviceList[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.deviceList.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print(indexPath.row)
        
        
        self.queueTCP.async  {
            self.currentCmdNumber = self._4_device_identity
            let cmd = "get " + self.deviceList[indexPath.row] + " identity\n" //get device identity cmd
            self.isLockRead = true //prepare to read server feedback
            self.receiveData = "" //server feedback data
            self.mSocket.write((cmd.data(using: String.Encoding.utf8))!, withTimeout: -1, tag: 0)//send cmd to server
            
            DispatchQueue.main.async(){
                self.showLoading()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.closeLoading()
                self.isLockRead = false
                var strDeviceInfo: String = ""
                print("1: "+self.receiveData)
                do {
                    _ = try JSONSerialization.jsonObject(with: self.receiveData.data(using: .utf8)!)
                    let checkFeedbackStatus:CheckFeedbackstatus  = try! JSONDecoder().decode(CheckFeedbackstatus.self, from: self.receiveData.data(using: .utf8)!)
                    
                    if(checkFeedbackStatus.status == "SUCCESS"){
                        print("2: "+self.receiveData)
                        let device_info: DeviceInfo = try! JSONDecoder().decode(DeviceInfo.self, from: self.receiveData.data(using: .utf8)!)
                        if(device_info.result.devices.count > 0){
                            strDeviceInfo.append(device_info.result.devices[0].identity.chipset_type + " (Chipset)\n")
                            strDeviceInfo.append(device_info.result.devices[0].identity.engine + " (Engine)\n")
                            strDeviceInfo.append(device_info.result.devices[0].identity.firmware_comment + "\n")
                            strDeviceInfo.append("VID - " + String(device_info.result.devices[0].identity.vendor_id) + " -- PID -" + String(device_info.result.devices[0].identity.product_id) + "\n")
                            
                            if(device_info.result.devices[0].nodes.count > 0){
                                strDeviceInfo.append(device_info.result.devices[0].nodes[0].status.ip.address)
                                
                            }
                            self.showPopDialog(deviceID: self.deviceList[indexPath.row], deviceInfo: strDeviceInfo)
                        }
                    }else{
                        self.ShowToast(message: "Request timeout")
                    }
                    
                } catch {
                    print("Error deserializing JSON: \(error.localizedDescription)")
                    self.ShowToast(message: "Request timeout")
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
    
    //show device info
    func showPopDialog(deviceID: String, deviceInfo: String){
        
        // Create the dialog
        let popup = PopupDialog(title: deviceID, message: deviceInfo, image: nil)
        
        // Create buttons
        let buttonCancel = CancelButton(title: "Cancel") {
            
        }
        // Add buttons to dialog
        // Alternatively, you can use popup.addButton(buttonOne)
        // to add a single button
        popup.addButtons([buttonCancel])
        
        // Present dialog
        self.present(popup, animated: true, completion: nil)
    }
    
    
    //show toast
    func ShowToast(message: String){
        DispatchQueue.main.async() {
            self.view.makeToast(message, duration: 2.0, position: .bottom)
        }
    }
    
    struct CheckFeedbackstatus: Decodable{
        let status: String!
    }
    
    struct HumanMode: Decodable {
        let  status: String!
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
    
    struct ChangeSource: Decodable{
        let status: String!
    }
    
    struct DeviceInfo: Decodable{
        struct ResultDeviceInfo: Decodable{
            let devices: [Devices]!
        }
        
        struct Devices: Decodable{
            let identity: Identity!
            let nodes: [Nodes]!
        }
        
        struct Nodes: Decodable {
            let status: Status!
        }
        
        struct Identity: Decodable{
            let chipset_type: String!
            let engine: String!
            let firmware_comment: String!
            let vendor_id: Int!
            let product_id: Int!
        }
        
        struct Status: Decodable{
            let ip: IP!
        }
        
        struct IP: Decodable{
            let address: String!
        }
        
        let status: String
        let result: ResultDeviceInfo
    }
    
}
