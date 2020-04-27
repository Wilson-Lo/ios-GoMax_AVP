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

class HDMIAudioViewContorller: UIViewController, GCDAsyncSocketDelegate, UITableViewDataSource, UITableViewDelegate{
    
    var mSocket:GCDAsyncSocket!
    var queueTCP: DispatchQueue!
    var currentCmdNumber = 0
    let _1_cmd_mode_human = 1
    let _2_cmd_require_blueriver_api_2_19_0 = 2
    let _3_get_all_list = 3
    var deviceList: Array<String> = []
    var menu: RSSelectionMenu<String>!
    var segmentedControlHDMI: UISegmentedControl!
    var segmentedControlResolution: UISegmentedControl!
    var lebalResolution: UILabel!
    var alert: UIAlertController!
    var isConnected = false
    let preferences = UserDefaults.standard
    var receiveData: String = ""
    var isLockRead: Bool = false
    
    @IBOutlet weak var tableDeviceList: UITableView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.alert = UIAlertController(title: nil, message: "Please wait...", preferredStyle: .alert)
        self.tableDeviceList = self.view.viewWithTag(401) as? UITableView
        let nib = UINib(nibName: "CustomTableViewCellDevice", bundle: nil)
        self.tableDeviceList.register(nib, forCellReuseIdentifier: "CutomTableRowCell")
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        print("HDMIAudioViewContorller-viewDidAppear")
        self.isConnected = false
        self.queueTCP = DispatchQueue(label: "com.gofanco.tcp", qos: DispatchQoS.userInitiated)
        self.deviceList.removeAll()
        // self.tableDeviceList.reloadData()
        if(preferences.value(forKey: key_server_ip) != nil){
            var fullIP = preferences.value(forKey: key_server_ip) as! String
            queueTCP.async {
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
        queueTCP.async  {
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
                }
            }
            break
            
        case self._2_cmd_require_blueriver_api_2_19_0:
            print("_2_cmd_require_blueriver_api_2_19_0")
            let blueriver_api: HumanMode = try! JSONDecoder().decode(HumanMode.self, from: didRead)
            if(blueriver_api.status == "SUCCESS"){
                print("initial successful")
                self.isLockRead = true
                self.currentCmdNumber = self._3_get_all_list
                self.deviceList.removeAll()
                self.receiveData = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
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
                                self.tableDeviceList.reloadData()
                            }
                        }
                    } catch {
                        print("Error deserializing JSON: \(error.localizedDescription)")
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
                }
            }
            break
            
        case self._3_get_all_list:
            print("_3_get_all_list")
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
        print("click")
        
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
}
