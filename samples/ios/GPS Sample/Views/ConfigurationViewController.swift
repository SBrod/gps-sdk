/*
 Copyright (C) 2016 Bad Elf, LLC. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View controller that allows configuration of the protocol strings to the Bad Elf accessory.
 Swift 4.2
 */

import UIKit
import ExternalAccessory

extension Notification.Name {
    static let BESessionDataReceivedNotification = Notification.Name(
        rawValue: "BESessionDataReceivedNotification")
}

class ConfigurationViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    var sessionController: SessionController!
    var accessory: EAAccessory?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.title = "Accessory"
    }
    override func viewWillAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(self, selector: #selector(sessionDataReceived), name: .BESessionDataReceivedNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(accessoryDidDisconnect), name: .EAAccessoryDidDisconnect, object: nil)


        sessionController = SessionController.sharedController
        if sessionController.openSession(){
            accessory = sessionController._accessory
        }

        super.viewWillAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {

        NotificationCenter.default.removeObserver(self, name: .BESessionDataReceivedNotification , object: nil)
        NotificationCenter.default.removeObserver(self, name: .EAAccessoryDidDisconnect, object: nil)

        sessionController.closeSession()

        super.viewWillDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Interface Actions

    @IBAction func segmentedControlForBasicDataDidChange(_ sender: UISegmentedControl) {
        var configString: String!
        switch sender.selectedSegmentIndex {
        case 0:
            // 1Hz Updates  24be001105010205310132043301640d0a
            configString = "24be001105010205310132043301640d0a"
            break
        case 1:
            // 2 Hz Updates 24be001104010206310232043301630d0a
            configString = "24be001104010206310232043301630d0a"
            break
        case 2:
            // 4 Hz Updates 24be001104010206310432043301610d0a
            configString = "24be001104010206310432043301610d0a"
            break
        case 3:
            // 5 Hz Updates 24be001106010204310532043301600d0a
            configString = "24be001106010204310532043301600d0a"
            break
        case 4:
            // 10 Hz Updates 24be001108010202310a320433015b0d0a
            configString =  "24be001108010202310a320433015b0d0a"
            break
        default:
            break
        }

        configureAccessoryWithString(configString: configString)
    }

    @IBAction func segmentedControlForSatDataDidChange(_ sender: UISegmentedControl) {
        var configString: String!
        switch sender.selectedSegmentIndex {
        case 0:
            // 1Hz Updates
            // extended     24be00110b0102ff310132043302630d0a
            configString = "24be00110b0102ff310132043302630d0a"
            break
        case 1:
            // 2 Hz Updates
            // extended     24be0011100102fa310232043302620d0a
            configString = "24be0011100102fa310232043302620d0a"
            break
        case 2:
            // 4 Hz Updates
            // extended     24be0011120102f8310432043302600d0a
            configString = "24be0011120102f8310432043302600d0a"
            break
        case 3:
            // 5 Hz Updates
            // extended     24be0011130102f73105320433025f0d0a
            configString = "24be0011130102f73105320433025f0d0a"
            break
        case 4:
            // 10 Hz Updates
            // extended     24be0011160102f4310a320433025a0d0a
            configString = "24be0011160102f4310a320433025a0d0a"
            break
        default:
            break
        }

        configureAccessoryWithString(configString: configString)
    }

    // MARK: - Session Updates

    @objc func sessionDataReceived(notification: NSNotification) {

        if sessionController._dataAsString != nil {
            textView.textStorage.beginEditing()
            textView.textStorage.mutableString.appendFormat(sessionController._dataAsString!)
            //print(sessionController._dataAsString ?? "No String")
            processGPxxx(input: sessionController._dataAsString! as String)
            textView.textStorage.endEditing()
            textView.scrollRangeToVisible(NSMakeRange(textView.textStorage.length, 0))
        }
    }

    func processGPxxx(input:String) {
        let arr = input.split(separator: ",")
        switch arr[0] {
        // breaks out GPGGA data to debug console
        case "$GPGGA":
            let inFormatter = DateFormatter()
            inFormatter.timeZone = TimeZone(identifier: "UTC")
            inFormatter.dateFormat = "HHmmss.SSS"
            let outFormatter = DateFormatter()
            outFormatter.locale = Locale(identifier: "en_US_POSIX")
            outFormatter.dateFormat = "hh:mm:ss"
            let date = inFormatter.date(from: String(arr[1]))!
            print("Time :",outFormatter.string(from: date))
            let lat = arr[2]+arr[3]
            let lon = arr[4]+arr[5]
            print("Coord :",lat,lon)
            let satNum = arr[7]
            let elev = arr[9]+arr[10]
            print("Elevation :",elev,"  Satelites = ",satNum)
        default: // "$GPGSV","$GLGSV","$GPRMC","$GNGSA","$GPGGA"
            print("Not GPGGA")
        }
    }

    // MARK: - EAAccessory Disconnection

    @objc func accessoryDidDisconnect(notification: NSNotification) {
        if navigationController?.topViewController == self {
            let disconnectedAccessory = notification.userInfo![EAAccessoryKey] as? EAAccessory
            if disconnectedAccessory?.connectionID == accessory?.connectionID {
                dismiss(animated: true, completion: nil)
            }
        }
    }

    func configureAccessoryWithString(configString: String) {

        if let data = configString.dataFromHexadecimalString(){
            sessionController.writeData(data)
        }
    }

}

extension String {
    func dataFromHexadecimalString() -> Data? {
        let trimmedString = self.trimmingCharacters(in: CharacterSet(charactersIn: "<>".replacingOccurrences(of: " ", with: "")))

        let regex = try! NSRegularExpression(pattern: "^[0-9a-f]*$", options: .caseInsensitive)

        let found = regex.firstMatch(in: trimmedString, options: [], range: NSMakeRange(0, trimmedString.count))
        if found == nil || found?.range.location == NSNotFound || trimmedString.count % 2 != 0 {
            return nil
        }

        // everything ok, so now let's build NSData

        var data = Data(capacity: trimmedString.count / 2)
        var index = trimmedString.startIndex
        while index < trimmedString.endIndex {
            let byteString = trimmedString[index ..< trimmedString.index(index, offsetBy: 2)]
            let num = UInt8(byteString.withCString { strtoul($0, nil, 16) })
            data.append(num)
            index = trimmedString.index(index, offsetBy: 2)
        }
        return data
    }
}
