//
//  ChangeSourceViewController.swift
//  AVP Controller
//
//  Created by 啟發電子 on 2020/4/22.
//  Copyright © 2020 gomax. All rights reserved.
//

import Foundation
import UIKit
import CocoaAsyncSocket
import RSSelectionMenu
import Toast_Swift
import DispatchIntrospection
class ChangeSourceViewController: UIViewController, GCDAsyncSocketDelegate, UITableViewDataSource, UITableViewDelegate{
    
    
    var mSocket:GCDAsyncSocket!
    var queueTCP: DispatchQueue!
    var currentCmdNumber = 0
    let _1_cmd_mode_human = 1
    let _2_cmd_require_blueriver_api_2_19_0 = 2
    let _3_get_all_list = 3
    let _4_change_source = 4
    var deviceList: Array<String> = []
    var menu: RSSelectionMenu<String>!
    var segmentedControlHDMI: UISegmentedControl!
    var segmentedControlResolution: UISegmentedControl!
    var lebalResolution: UILabel!
    var currentHDMITYpe = CmdHelper.hdmi_gerenal
    var currentResolutionType = CmdHelper.resolution_4k2k_60
    var alert: UIAlertController!
    var isConnected = false
    let preferences = UserDefaults.standard
    var receiveData: String = ""
    var isLockRead: Bool = false
    
    @IBOutlet weak var tableDeviceList: UITableView!
    private var checkConnectStatusWork: DispatchWorkItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.alert = UIAlertController(title: nil, message: "Please wait...", preferredStyle: .alert)
        self.segmentedControlHDMI = self.view.viewWithTag(102) as? UISegmentedControl
        self.segmentedControlResolution = self.view.viewWithTag(103) as? UISegmentedControl
        self.lebalResolution = self.view.viewWithTag(104) as? UILabel
        self.tableDeviceList = self.view.viewWithTag(101) as? UITableView
        let nib = UINib(nibName: "CustomTableViewCellDevice", bundle: nil)
        self.tableDeviceList.register(nib, forCellReuseIdentifier: "CutomTableRowCell")
        self.tableDeviceList.delegate = self
        self.segmentedControlHDMI.addTarget(self, action: #selector(HDMIChanged(_:)), for: .valueChanged)
        self.segmentedControlResolution.addTarget(self, action: #selector(ResolutionChanged(_:)), for: .valueChanged)
        self.segmentedControlResolution.isHidden = true
        self.lebalResolution.isHidden = true
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        print("ChangeSourceViewController-viewDidAppear")
        self.checkConnectStatusWork  = DispatchWorkItem(block: {
            if(!self.isConnected){
                self.closeLoading()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.view.makeToast("Request timeout !", duration: 2.0, position: .bottom)
                }
            }
        })
        self.isConnected = false
        self.queueTCP = DispatchQueue(label: "com.gofanco.tcp", qos: DispatchQoS.userInitiated)
        self.deviceList.removeAll()
        self.tableDeviceList.reloadData()
        self.receiveData = ""
        if(preferences.value(forKey: key_server_ip) != nil){
            var fullIP = preferences.value(forKey: key_server_ip) as! String
            queueTCP.async {
                DispatchQueue.main.async {
                    self.showLoading()
                }
                
                
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
        print("ChangeSourceViewController-viewDidDisappear")
        self.checkConnectStatusWork?.cancel()
        queueTCP.async {
            if(self.mSocket != nil){
                self.mSocket.disconnect()
                self.mSocket = nil
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print("ChangeSourceViewController-socketDidDisconnect")
        self.isConnected = false
        
    }
    
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("ChangeSourceViewController-didConnectToHost")
        self.isConnected = true
        self.queueTCP.asyncAfter(deadline: .now() + 0.5) {
            self.currentCmdNumber = self._1_cmd_mode_human
            self.mSocket.write((CmdHelper.cmd_human_mode.data(using: String.Encoding.utf8))!, withTimeout: -1, tag: 0)
            self.mSocket.readData(withTimeout: -1, tag: 0)
        }
    }
    
    public func socket(_ sock: GCDAsyncSocket, didRead: Data, withTag tag:CLong){
        print("ChangeSourceViewController-didRead")
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
                    self.isLockRead = true
                    self.currentCmdNumber = self._3_get_all_list
                    self.deviceList.removeAll()
                    self.receiveData = ""
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.isLockRead = false
                        do {
                            _ = try JSONSerialization.jsonObject(with: self.receiveData.data(using: .utf8)!)
                            print("Valid Json")
                            let get_all_list: GetAllList = try! JSONDecoder().decode(GetAllList.self, from: self.receiveData.data(using: .utf8)!)
                            if(get_all_list.result.devices.count > 0){
                                for index in get_all_list.result.devices{
                                    self.deviceList.append(index.device_id)
                                    print(index.device_id)
                                }
                                
                                DispatchQueue.main.async {
                                    self.closeLoading()
                                    self.tableDeviceList.reloadData()
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
            
        case self._4_change_source:
            print("_4_change_source")
            
            do {
                _ = try JSONSerialization.jsonObject(with: didRead)
                let changeSource: ChangeSource = try! JSONDecoder().decode(ChangeSource.self, from: didRead)
                if(changeSource.status == "PROCESSING"){
                    DispatchQueue.main.async {
                        self.view.makeToast("Send successful ", duration: 3.0, position: .bottom)
                    }
                }else if(changeSource.status == "SUCCESS"){
                    
                    let error_message : Error = try! JSONDecoder().decode(Error.self, from: didRead)
                    print("change error " + String(error_message.result.error.count))
                    DispatchQueue.main.async {
                        self.view.makeToast("Send failed: " + error_message.result.error[0].message, duration: 3.0, position: .bottom)
                    }
                }else{
                    DispatchQueue.main.async {
                        self.view.makeToast("Send failed")
                    }
                }
            } catch {
                print("Error deserializing JSON: \(error.localizedDescription)")
                
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
        print("click")
        print(indexPath.row)
        DispatchQueue.main.async {
            let selectedNames: [String] = []
            // create menu with data source -> here [String]
            
            self.menu = RSSelectionMenu(dataSource: self.deviceList) { (cell, name, indexPath) in
                cell.textLabel?.text = name
            }
            
            
            // provide selected items
            self.menu.setSelectedItems(items: selectedNames) { (name, index, selected, selectedItems) in
                
                self.currentCmdNumber = self._4_change_source
                var cmd: String!
                
                switch self.currentHDMITYpe{
                    
                case CmdHelper.hdmi_gerenal:
                    cmd = "join " + self.deviceList[index]  + ":HDMI:0 " + self.deviceList[indexPath.row] + ":HDMI:0\n"
                    break
                case CmdHelper.hdmi_genlock:
                    cmd = "join " + self.deviceList[index]  + ":HDMI:0 " + self.deviceList[indexPath.row] + ":HDMI:0 genlock\n"
                    break
                    
                case CmdHelper.hdmi_fastswitch:
                    switch self.currentResolutionType{
                        
                    case CmdHelper.resolution_4k2k_60:
                        cmd = "join " + self.deviceList[index]  + ":HDMI:0 " + self.deviceList[indexPath.row] + ":HDMI:0 fastswitch size 3840 2160 fps 60\n"
                        break
                    case CmdHelper.resolution_1080p_60:
                        cmd = "join " + self.deviceList[index]  + ":HDMI:0 " + self.deviceList[indexPath.row] + ":HDMI:0 fastswitch size 1920 1080 fps 60\n"
                        break
                        
                    case CmdHelper.resolution_720p_60:
                        cmd = "join " + self.deviceList[index]  + ":HDMI:0 " + self.deviceList[indexPath.row] + ":HDMI:0 fastswitch size 1280 720 fps 60\n"
                        break
                        
                    default:
                        break
                    }
                    break
                    
                default:
                    break
                }
                self.mSocket.write((cmd.data(using: String.Encoding.utf8))!, withTimeout: -1, tag: 0)
                self.mSocket.readData(withTimeout: 2, tag: 0)
                
                
            }
            
            self.menu.show(from: self)
        }
    }
    
    @objc func HDMIChanged(_ sender: UISegmentedControl){
        print(sender.selectedSegmentIndex)
        
        switch sender.selectedSegmentIndex{
            
        case CmdHelper.hdmi_gerenal:
            self.segmentedControlResolution.isHidden = true
            self.lebalResolution.isHidden = true
            self.currentHDMITYpe = CmdHelper.hdmi_gerenal
            break
        case CmdHelper.hdmi_genlock:
            self.segmentedControlResolution.isHidden = true
            self.lebalResolution.isHidden = true
            self.currentHDMITYpe = CmdHelper.hdmi_genlock
            break
            
        case CmdHelper.hdmi_fastswitch:
            self.segmentedControlResolution.isHidden = false
            self.lebalResolution.isHidden = false
            self.currentHDMITYpe = CmdHelper.hdmi_fastswitch
            break
            
        default:
            break
        }
    }
    
    
    @objc func ResolutionChanged(_ sender: UISegmentedControl){
        print(sender.selectedSegmentIndex)
        switch sender.selectedSegmentIndex{
            
        case CmdHelper.resolution_4k2k_60:
            self.currentResolutionType = CmdHelper.resolution_4k2k_60
            break
        case CmdHelper.resolution_1080p_60:
            self.currentResolutionType = CmdHelper.resolution_1080p_60
            break
            
        case CmdHelper.resolution_720p_60:
            self.currentResolutionType = CmdHelper.resolution_720p_60
            break
            
        default:
            break
        }
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
    
    struct ChangeSource: Decodable{
        let status: String!
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
    
    //show toast
    func ShowToast(message: String){
        DispatchQueue.main.async() {
            self.view.makeToast(message, duration: 2.0, position: .bottom)
        }
    }
}


