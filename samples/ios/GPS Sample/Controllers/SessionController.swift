/*
 Copyright (C) 2016 Bad Elf, LLC. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Controller for managing connected accessory and communicating with the accessory via NSInput & NSOutput streams.
 Swift 4.2
 */

import UIKit
import ExternalAccessory

class SessionController: NSObject, EAAccessoryDelegate, StreamDelegate {

    static let sharedController = SessionController()
    var _accessory: EAAccessory?
    var _session: EASession?
    var _protocolString: String?
    var _writeData: NSMutableData?
    var _readData: NSMutableData?
    var _dataAsString: NSString?

    // MARK: Controller Setup

    func setupController(forAccessory accessory: EAAccessory, withProtocolString protocolString: String) {
        _accessory = accessory
        _protocolString = protocolString
    }

    // MARK: Opening & Closing Sessions

    func openSession() -> Bool {
        _accessory?.delegate = self
        _session = EASession(accessory: _accessory!, forProtocol: _protocolString!)

        if _session != nil {
            _session?.inputStream?.delegate = self
            _session?.inputStream?.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default)
            _session?.inputStream?.open()

            _session?.outputStream?.delegate = self
            _session?.outputStream?.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default)
            _session?.outputStream?.open()
        } else {
            print("Failed to create session")
        }

        return _session != nil
    }

    func closeSession() {

        _session?.inputStream?.close()
        _session?.inputStream?.remove(from: RunLoop.current, forMode: RunLoop.Mode.default)
        _session?.inputStream?.delegate = nil

        _session?.outputStream?.close()
        _session?.outputStream?.remove(from: RunLoop.current, forMode: RunLoop.Mode.default)
        _session?.outputStream?.delegate = nil

        _session = nil
        _writeData = nil
        _readData = nil
    }

    // MARK: Write & Read Data

    func writeData(_ data: Data) {
        if _writeData == nil {
            _writeData = NSMutableData()
        }

        _writeData?.append(data)
        self.writeData()
    }

    func readData(_ bytesToRead: Int) -> Data {

        var data: Data?
        if (_readData?.length)! >= bytesToRead {
            let range = NSMakeRange(0, bytesToRead)
            data = _readData?.subdata(with: range)
            _readData?.replaceBytes(in: range, withBytes: nil, length: 0)
        }

        return data!
    }

    func readBytesAvailable() -> Int {
        return (_readData?.length)!
    }

    // MARK: - Helpers
    func updateReadData() {
        let bufferSize = 128
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while _session?.inputStream?.hasBytesAvailable == true {
            let bytesRead = _session?.inputStream?.read(&buffer, maxLength: bufferSize)
            if _readData == nil {
                _readData = NSMutableData()
            }
            _readData?.append(buffer, length: bytesRead!)
            _dataAsString = NSString(bytes: buffer, length: bytesRead!, encoding: String.Encoding.utf8.rawValue)
            NotificationCenter.default.post(name: Notification.Name(rawValue: "BESessionDataReceivedNotification"), object: nil)
        }
    }

    private func writeData() {
        if let stream = _session?.outputStream ,let writeData = _writeData {
            while (stream.hasSpaceAvailable) == true && writeData.length > 0 {
                var buffer = [UInt8](repeating: 0, count: _writeData!.length)
                _writeData?.getBytes(&buffer, length: (_writeData?.length)!)
                let bytesWritten = _session?.outputStream?.write(&buffer, maxLength: _writeData!.length)
                if bytesWritten == -1 {
                    print("Write Error")
                    return
                } else if bytesWritten! > 0 {
                    _writeData?.replaceBytes(in: NSMakeRange(0, bytesWritten!), withBytes: nil, length: 0)
                }
            }
        }
    }

    // MARK: - EAAcessoryDelegate

    func accessoryDidDisconnect(_ accessory: EAAccessory) {
        // Accessory diconnected from iOS, updating accordingly
    }

    // MARK: - NSStreamDelegateEventExtensions

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event():
            break
        case Stream.Event.openCompleted:
            break
        case Stream.Event.hasBytesAvailable:
            // Read Data
            updateReadData()
            break
        case Stream.Event.hasSpaceAvailable:
            // Write Data
            self.writeData()
            break
        case Stream.Event.errorOccurred:
            break
        case Stream.Event.endEncountered:
            break

        default:
            break
        }
    }
}
