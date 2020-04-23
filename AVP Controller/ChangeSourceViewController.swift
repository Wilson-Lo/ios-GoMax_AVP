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
import SwiftSocket
import RSSelectionMenu

class ChangeSourceViewController: UIViewController, GCDAsyncSocketDelegate, UITableViewDataSource, UITableViewDelegate{
    
    
    var mSocket:GCDAsyncSocket!
    var queueTCP: DispatchQueue!
    var client: TCPClient!
    var inputStream: InputStream!
    var outputStream: OutputStream!
    var currentCmdNumber = 0
    let _1_cmd_mode_human = 1
    let _2_cmd_require_blueriver_api_2_19_0 = 2
    let _3_get_all_list = 3
    let _4_change_source = 4
    var deviceList: Array<String> = []
    var menu: RSSelectionMenu<String>!


    @IBOutlet weak var tableDeviceList: UITableView!


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.tableDeviceList = self.view.viewWithTag(101) as? UITableView
        let nib = UINib(nibName: "CustomTableViewCellDevice", bundle: nil)
        self.tableDeviceList.register(nib, forCellReuseIdentifier: "CutomTableRowCell")
        self.tableDeviceList.delegate = self

    }

    override func viewDidAppear(_ animated: Bool) {
        print("EDIDViewController-viewDidAppear")
        self.queueTCP = DispatchQueue(label: "com.gofanco.tcp", qos: DispatchQoS.userInitiated)
        queueTCP.async {
            //            DispatchQueue.main.async {
            //                self.showLoading()
            //            }
            // if(currentDeviceIP != nil){

            self.mSocket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
            do {

                try self.mSocket.connect(toHost: "192.168.1.166", onPort: 6970)


                print("connect to device success")
                //                    DispatchQueue.main.async {
                //                        self.closeLoading()
                //                    }

            } catch let error {
                print("error to connect device")
            }


        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        print("EDIDViewController-viewDidDisappear")
        queueTCP.async {
            self.mSocket.disconnect()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        print("didAcceptNewSocket")
    }

    func socketDidSecure(_ sock: GCDAsyncSocket) {
        print("socketDidSecure")
    }

    func socketDidCloseReadStream(_ sock: GCDAsyncSocket) {
        print("socketDidCloseReadStream")
    }

    func socket(_ sock: GCDAsyncSocket, didConnectTo url: URL) {
        print("didConnectTo")
    }


    func socket(_ sock: GCDAsyncSocket, didWritePartialDataOfLength partialLength: UInt, tag: Int) {
        print("didWritePartialDataOfLength")
    }


    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        print("didWriteDataWithTag")
    }

    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print("socketDidDisconnect")
    }

    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("didConnectToHost")
        queueTCP.async  {
            self.currentCmdNumber = self._1_cmd_mode_human
            self.mSocket.write((CmdHelper.cmd_human_mode.data(using: String.Encoding.utf8))!, withTimeout: -1, tag: 0)
            self.mSocket.readData(withTimeout: -1, tag: 0)
        }
    }

    func socket(_ sock: GCDAsyncSocket, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        print("didReceive")
    }

    func socket(_ sock: GCDAsyncSocket, didReadPartialDataOfLength partialLength: UInt, tag: Int) {
        print("didReadPartialDataOfLength")
    }

    public func socket(_ sock: GCDAsyncSocket, didRead: Data, withTag tag:CLong){
        print("server feedback")
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
            }
            break

        case self._2_cmd_require_blueriver_api_2_19_0:
            print("_2_cmd_require_blueriver_api_2_19_0")
            let blueriver_api: HumanMode = try! JSONDecoder().decode(HumanMode.self, from: didRead)
            if(blueriver_api.status == "SUCCESS"){
                print("initial successful")
                self.currentCmdNumber = self._3_get_all_list
                self.mSocket.write((CmdHelper.cmd_get_all_list.data(using: String.Encoding.utf8))!, withTimeout: -1, tag: 0)
                self.mSocket.readData(withTimeout: 2, tag: 0)
            }
            break

        case self._3_get_all_list:
            print("_3_get_all_list")
            print(String(decoding: didRead, as: UTF8.self))
            let get_all_list: GetAllList = try! JSONDecoder().decode(GetAllList.self, from: didRead)
            print(get_all_list.result.devices.count)
            if(get_all_list.result.devices.count > 0){
                for index in get_all_list.result.devices{
                    self.deviceList.append(index.device_id)
                    print(index.device_id)
                }

                DispatchQueue.main.async {
                    self.tableDeviceList.reloadData()
                    print("refresh")
                }
            }

            break

        default:
            print("default")
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

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CutomTableRowCell", for: indexPath) as! CustomTableViewCellDevice;
        cell.label_device_id.text = self.deviceList[indexPath.row]
        print("create")
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.deviceList.count
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("click")
        print(indexPath.row)
        DispatchQueue.main.async {
            var selectedNames: [String] = []
            // create menu with data source -> here [String]

            self.menu = RSSelectionMenu(dataSource: self.deviceList) { (cell, name, indexPath) in
                cell.textLabel?.text = name
            }


            // provide selected items
            self.menu.setSelectedItems(items: selectedNames) { (name, index, selected, selectedItems) in
                //  selectedNames = selectedItems
                print(selectedItems[0])
                print(self.deviceList[index])

            }

            self.menu.show(from: self)
        }
    }
}


