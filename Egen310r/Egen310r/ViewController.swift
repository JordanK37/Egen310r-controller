//
//  ViewController.swift
//  Egen310r
//
//  Created by Jordan Kelly on 3/8/20.
//  Copyright © 2020 Jordan Kelly. All rights reserved.
//
import Foundation
import CoreBluetooth
import UIKit

let kBLEService_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
let kBLE_Characteristic_uuid_Tx = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
let kBLE_Characteristic_uuid_Rx = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
let MaxCharacters = 20

var txCharacteristic : CBCharacteristic?
var rxCharacteristic : CBCharacteristic?
var blePeripheral : CBPeripheral?
var characteristicASCIIValue = NSString()

let BLEService_UUID = CBUUID(string: kBLEService_UUID)
let BLE_Characteristic_uuid_Tx = CBUUID(string: kBLE_Characteristic_uuid_Tx)//(Property = Write without response)
let BLE_Characteristic_uuid_Rx = CBUUID(string: kBLE_Characteristic_uuid_Rx)// (Property = Read/Notify)


class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager : CBCentralManager!
    var RSSIs = [NSNumber]()
    var data = NSMutableData()
    var writeData: String = ""
    var peripherals: [CBPeripheral] = []
    var characteristicValue = [CBUUID: NSData]()
    var timer = Timer()
    var characteristics = [String : CBCharacteristic]()
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view
        centralManager =  CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            // We will just handle it the easy way here: if Bluetooth is on, proceed...start scan!
            print("Bluetooth Enabled")
            startScan()
       
        } else {
            //If Bluetooth is off, display a UI alert message saying "Bluetooth is not enable" and "Make sure that your bluetooth is turned on"
            print("Bluetooth Disabled- Make sure your Bluetooth is turned on")
            
            let alertVC = UIAlertController(title: "Bluetooth is not enabled", message: "Make sure that your bluetooth is turned on", preferredStyle: UIAlertController.Style.alert)
            let action = UIAlertAction(title: "ok", style: UIAlertAction.Style.default, handler: { (action: UIAlertAction) -> Void in
                self.dismiss(animated: true, completion: nil)
            })
            alertVC.addAction(action)
            self.present(alertVC, animated: true, completion: nil)
        }
    }
    
    func startScan() {
           peripherals = []
           print("Now Scanning...")
           self.timer.invalidate()
           centralManager?.scanForPeripherals(withServices: [BLEService_UUID] , options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
           Timer.scheduledTimer(withTimeInterval: 17, repeats: false) {_ in
               self.cancelScan()
               
            self.connectToDevice()
           }
       }
    func cancelScan() {
        self.centralManager?.stopScan()
        print("Scan Stopped")
        print("Number of Peripherals Found: \(peripherals.count)")
    }
    
    func disconnectFromDevice () {
        if blePeripheral != nil {
            // We have a connection to the device but we are not subscribed to the Transfer Characteristic for some reason.
            // Therefore, we will just disconnect from the peripheral
            centralManager?.cancelPeripheralConnection(blePeripheral!)
        }
    }
    
    func restoreCentralManager() {
        //Restores Central Manager delegate if something went wrong
        centralManager?.delegate = self as? CBCentralManagerDelegate
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        blePeripheral = peripheral
        self.peripherals.append(peripheral)
        self.RSSIs.append(RSSI)
        peripheral.delegate = self as? CBPeripheralDelegate
        if blePeripheral == nil {
            print("Found new pheripheral devices with services")
            print("Peripheral name: \(String(describing: peripheral.name))")
            print("**********************************")
            print ("Advertisement Data : \(advertisementData)")
            print ("Connecting to device")
            
            
        }
    }
    
    func connectToDevice () {
           centralManager?.connect(blePeripheral!, options: nil)
       }
    
    /*
     Invoked when a connection is successfully created with a peripheral.
     This method is invoked when a call to connect(_:options:) is successful. You typically implement this method to set the peripheral’s delegate and to discover its services.
     */
    //-Connected
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("*****************************")
        print("Connection complete")
        print("Peripheral info: \(String(describing: blePeripheral))")
        
        //Stop Scan- We don't need to scan once we've connected to a peripheral. We got what we came for.
        centralManager?.stopScan()
        print("Scan Stopped")
        
        //Erase data that we might have
        data.length = 0
        
        //Discovery callback
        peripheral.delegate = self as? CBPeripheralDelegate
        //Only look for services that matches transmit uuid
        peripheral.discoverServices([BLEService_UUID])
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("*******************************************************")
        
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            return
        }
        //We need to discover the all characteristic
        for service in services {
            
            peripheral.discoverCharacteristics(nil, for: service)
            // bleService = service
        }
        print("Discovered Services: \(services)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
           
           print("*******************************************************")
           
           if ((error) != nil) {
               print("Error discovering services: \(error!.localizedDescription)")
               return
           }
           
           guard let characteristics = service.characteristics else {
               return
           }
           
           print("Found \(characteristics.count) characteristics!")
           
           for characteristic in characteristics {
               //looks for the right characteristic
               
               if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Rx)  {
                   rxCharacteristic = characteristic
                   
                   //Once found, subscribe to the this particular characteristic...
                   peripheral.setNotifyValue(true, for: rxCharacteristic!)
                   // We can return after calling CBPeripheral.setNotifyValue because CBPeripheralDelegate's
                   // didUpdateNotificationStateForCharacteristic method will be called automatically
                   peripheral.readValue(for: characteristic)
                   print("Rx Characteristic: \(characteristic.uuid)")
               }
               if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Tx){
                   txCharacteristic = characteristic
                   print("Tx Characteristic: \(characteristic.uuid)")
               }
               peripheral.discoverDescriptors(for: characteristic)
           }
       }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        print("*******************************************************")
        
        if error != nil {
            print("\(error.debugDescription)")
            return
        }
        if ((characteristic.descriptors) != nil) {
            
            for x in characteristic.descriptors!{
                let descript = x as CBDescriptor
                print("function name: DidDiscoverDescriptorForChar \(String(describing: descript.description))")
                print("Rx Value \(String(describing: rxCharacteristic?.value))")
                print("Tx Value \(String(describing: txCharacteristic?.value))")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
           print("*******************************************************")
           
           if (error != nil) {
               print("Error changing notification state:\(String(describing: error?.localizedDescription))")
               
           } else {
               print("Characteristic's value subscribed")
           }
           
           if (characteristic.isNotifying) {
               print ("Subscribed. Notification has begun for: \(characteristic.uuid)")
           }
       }
       
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error discovering services: error")
            return
        }
        print("Message sent")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        guard error == nil else {
            print("Error discovering services: error")
            return
        }
        print("Succeeded!")
    }
    
    // Write functions
    func writeValue(data: String){
      let valueString = (data as NSString).data(using: String.Encoding.utf8.rawValue)
        if let blePeripheral = blePeripheral{
           if let txCharacteristic = txCharacteristic {
              blePeripheral.writeValue(valueString!, for: txCharacteristic, type: CBCharacteristicWriteType.withResponse)
            }
        }
    }
    
    @IBAction func ForwardButton(_ sender: Any) {/*connects the forward button to send flag 1 when pressed*/
        print("Forward")
        writeValue(data: "1")
    }
    
    @IBAction func ReverseButton(_ sender: Any) {/*connects the reverse button to send flag 2 when pressed*/
        print("Reverse")
        writeValue(data: "2")
    }
    
    @IBAction func LeftButton(_ sender: Any) {/*connects the left button to send flag 3 when pressed*/
        print("Left")
        writeValue(data: "3")
    }

    @IBAction func RightButton(_ sender: Any) {/*connects the right button to send flag 4 when pressed*/
        print("Right")
        writeValue(data: "4")
    }
    @IBOutlet weak var lbl: UILabel!/*variable that changes when slider moves*/
    
    @IBAction func SpeedController(_ sender: UISlider) {/*sends changed variable when slider is changed and moved*/
        lbl.text = String(Int(sender.value))
        writeValue(data: String(Int(sender.value)))
    }
    
    
}

