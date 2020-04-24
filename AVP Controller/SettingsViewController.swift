//
//  SettingsViewController.swift
//  AVP Controller
//
//  Created by 啟發電子 on 2020/4/23.
//  Copyright © 2020 gomax. All rights reserved.
//

import UIKit
var currentDeviceIP : String!

let key_server_ip = "avx_server_ip"

class SettingsViewController: UIViewController, UITextFieldDelegate{
    
    var networkStackView: UIStackView!
    let preferences = UserDefaults.standard
    var ip_text_1: UITextField!
    var ip_text_2: UITextField!
    var ip_text_3: UITextField!
    var ip_text_4: UITextField!
    
    @IBOutlet var uITextFieldDelegate: UITextField?
    @IBOutlet var textField: UITextField?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.ip_text_1 = self.view.viewWithTag(201) as? UITextField
        self.ip_text_2 = self.view.viewWithTag(202) as? UITextField
        self.ip_text_3 = self.view.viewWithTag(203) as? UITextField
        self.ip_text_4 = self.view.viewWithTag(204) as? UITextField
        self.networkStackView = self.view.viewWithTag(101) as? UIStackView
        self.networkStackView.addBackground(color: .black)
        //save server ip
        
        uITextFieldDelegate?.delegate = self
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        view.addGestureRecognizer(tap)
        textField?.smartInsertDeleteType = UITextSmartInsertDeleteType.no
        textField?.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        if(preferences.value(forKey: key_server_ip) != nil){
            var fullIP = preferences.value(forKey: key_server_ip) as! String
            print(fullIP)
            let fullIPArr = fullIP.components(separatedBy: ".")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.ip_text_1.text = fullIPArr[0]
                self.ip_text_2.text = fullIPArr[1]
                self.ip_text_3.text = fullIPArr[2]
                self.ip_text_4.text = fullIPArr[3]
            }
            
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        print("test fileld")
        let maxLength = 3
        let currentString: NSString = textField.text! as NSString
        let newString: NSString =
            currentString.replacingCharacters(in: range, with: string) as NSString
        return newString.length <= maxLength
    }
    
    @objc func dismissKeyboard() {
        //Causes the view (or one of its embedded text fields) to resign the first responder status.
        view.endEditing(true)
    }
    
    @IBAction func saveServerIP(sender: UIButton) {
        
        var ip1: String = self.ip_text_1.text!
        var ip2: String = self.ip_text_2.text!
        var ip3: String = self.ip_text_3.text!
        var ip4: String = self.ip_text_4.text!
        
        var new_server_ip = self.ip_text_1.text! + "." + self.ip_text_2.text! + "." + self.ip_text_3.text! + "." + self.ip_text_4.text!
        
        preferences.set(new_server_ip, forKey: key_server_ip)
    }
}

extension UIStackView {
    func addBackground(color: UIColor) {
        let subView = UIView(frame: bounds)
        subView.backgroundColor = color
        subView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(subView, at: 0)
    }
}
