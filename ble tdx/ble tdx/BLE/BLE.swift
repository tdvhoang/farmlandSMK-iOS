//
//  BLE.swift
//  BIKE
//
//  Created by Ann on 1/13/16.
//  Copyright © 2016 Ann. All rights reserved.
//

import UIKit
import CoreBluetooth

protocol BLEDelegate {
    func disconnect()
    func connect()
    func showError(_ message : String)
    func showLoading(_ message : String)
    func hideLoading()

}

protocol BLELocationDelegate{
    func updateLocation(status : Bool, rssi_current : UInt8, rssi_turnOn : UInt8,  rssi_turnOff : UInt8, time : UInt8)
}

protocol BLEStatusDelegate{
    func updateStatus(_ cmd1: UInt8, cmd2: UInt8, cmd3: UInt8, cmd4: UInt8)
    func logonerror()
    
}

protocol BLEVersionDelegate{
    
    func updateVersion(version : String)
    
}

protocol BLERenameDelegate{
    
    func rename(_ newname : String)
    func error(_ message : String)
    
}

protocol BLEChangePassDelegate {
    func success()
    func error(_ message: String)
    
}

protocol BLEDiscoverPeripheral{
    func discover(_ peripheral : CBPeripheral, rssi: NSNumber)
}

class BLE: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    let UARTSERVICEUUIDSTRING = CBUUID(string:"6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    let UARTTXCHARACTERISTICUUIDSTRING =  CBUUID(string:"6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    let UARTRXCHARACTERISTICUUIDSTRING =  CBUUID(string:"6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    
    var centralManager : CBCentralManager!
    var dcvPeripherals : [CBPeripheral]!
    var bluetoothPeripheral : CBPeripheral!
    var scannedPeripheral : CBPeripheral!
    
    var bleProtocol : BLEProtocol!
    var uartRXCharacteristic : CBCharacteristic!
    var delegate : BLEDelegate!
    var delegateVersion : BLEVersionDelegate!
    var delegateStatus : BLEStatusDelegate!
    var delegateRename : BLERenameDelegate!
    var delegateLocation : BLELocationDelegate!
    var delegateChangePass : BLEChangePassDelegate!
    var delegaatePeripheral : BLEDiscoverPeripheral!
    
    var user : User!
    
    class var sharedInstance: BLE {
        struct Static {
            static let instance: BLE = BLE()
        }
        return Static.instance
    }
    
    // MARK: init
    override init (){
        super.init()
        
        bleProtocol = BLEProtocol()
        user = User()
        bleProtocol.pin = user.pin
        
        self.centralManager = CBCentralManager(delegate: self,queue: nil,options: nil)
        self.dcvPeripherals = [CBPeripheral]()
        
        if(user.uuid != nil){
            let knownPeripherals = self.centralManager.retrievePeripherals(withIdentifiers: [UUID(uuidString: user.uuid!)!])
            if(knownPeripherals.count > 0){
                scannedPeripheral = knownPeripherals[0]
            }
            print("aaa")
        }
        
        
    }
    func hasValue()  -> Bool {
        if(scannedPeripheral == nil){
            return false
        }else{
            return true
        }
    }
    
    // MARK:write characteristic
    
    func scanForPeripheral(_ enable : Bool){
        if enable {
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            centralManager.stopScan()
        }
    }
    
    // MARK:State
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if(central.state == .poweredOff){
            print("didUpdateState powser off" )
        }else if(central.state == .poweredOn){
            print("didUpdateState powwer on and ready" )
            if(scannedPeripheral != nil){
                connectToPeripheral(scannedPeripheral)
            }
        }else if(central.state == .unauthorized){
            print("didUpdateState unauthorize on" )
        }else if(central.state == .unknown){
            print("didUpdateState unknow on" )
        }else if(central.state == .unsupported){
            print("didUpdateState unsupport on" )
            delegate.showError("Unsupport")
        }else{
            print("didUpdateState unknow" )
        }
    }

    //MARK method for user
    func connectToPeripheral( _ peripheral : CBPeripheral){
        delegate.showLoading("Connecting")
        centralManager.connect(peripheral, options: nil)
        
    }

    func disconnect(){
        if(self.bluetoothPeripheral != nil){
            self.centralManager.cancelPeripheralConnection(self.bluetoothPeripheral)
        }
    }
    
    func isConnected() -> Bool {
        if(self.bluetoothPeripheral != nil){
            return true
        }else{
            return false
        }
    }
    
    func send(_ bytes : [UInt8]){
        
        if(self.bluetoothPeripheral == nil){
            delegate.showError("Không thể kết nối tới thiết bị")
        }else{
            let data = Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)
            self.bluetoothPeripheral.writeValue(data, for: self.uartRXCharacteristic, type: CBCharacteristicWriteType.withResponse)
        }
        
    }
    func configureRSSI(valueTurnOn : UInt8, valueTurnOff : UInt8)  {
        send(bleProtocol.configureRSSI(valueTurnOn: valueTurnOn, valueTurnOff: valueTurnOff))
    }
    
    func readRSSI(value : UInt8)  {
        send(bleProtocol.readRSSI(value: value))
    }
    func readStatus(){
        send(bleProtocol.readStatus())
    }
    func version() -> Void {
        send( bleProtocol.version() )
    }
    
    func sendCMD1(_ enable : Bool) -> Void {
        
        
    }
    
    func sendCMD2(_ enable : Bool) -> Void {
        
        
    }
    
    func sendCMD3(_ enable : Bool) -> Void {
        
        
    }

    func sendCMD4(_ enable : Bool) -> Void {
        
        
    }

    func setVibrate(_ enable : Bool) -> Void {
        if enable {
            send(bleProtocol.setVibeOn())
        } else {
            send(bleProtocol.setVibeOff())
        }

    }
    func logon() -> Void {
        send(bleProtocol.logon())
        
    }

    var newName : String!
    func rename(_ newName : String) -> Void {
        if(newName.characters.count <= 10){
            self.newName = newName
            send(bleProtocol.rename(newName))
        }else{
            delegateRename.error("Tên phải ít hơn 10 chữ")

        }
    }
    func changePass(_ newPass: String){
        send(bleProtocol.changepass(newPass))
    }

    //MARK:Scan
    func startScanningForUUID( _ uuidString : String){
        let uuid = CBUUID(string: uuidString)
        centralManager.scanForPeripherals(withServices: [uuid], options: nil)
    }
    func startScanning(){
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        
    }
    func stopScanning(){
        centralManager.stopScan()
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        dcvPeripherals.append(peripheral)
        if(delegaatePeripheral != nil){
            delegaatePeripheral.discover(peripheral,rssi : RSSI)
        }
    }
    
    
    // MARK:Discover / Connect
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to preripheral")
        delegate.showLoading("Connected")
        user.namedevice = peripheral.name!
        // if(delegateRename != nil){
        //     delegateRename.rename(peripheral.name!)
        // }
        bluetoothPeripheral = peripheral
        bluetoothPeripheral.delegate = self
        print("Discovering service")
        delegate.showLoading("Discovering")
        peripheral.discoverServices([UARTSERVICEUUIDSTRING])
        
        
        
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        bluetoothPeripheral.delegate = nil
        bluetoothPeripheral = nil
        delegate.disconnect()
        
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
        bluetoothPeripheral.delegate = nil
        bluetoothPeripheral = nil
        
    }
    
    //MARK:Restore
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
    }
    
    
    //MARK:peripheral delegate service
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if (error != nil){
            print("Error \(error)")
            
        }else{
            delegate.connect()
            for service in peripheral.services! {
                
                if(service.uuid.isEqual(UARTSERVICEUUIDSTRING)){
                    print("Nordic UART is found")
                    print("Discovering characteristic")
                    
                    bluetoothPeripheral.discoverCharacteristics(nil, for: service)
                    
                    return
                    
                    
                }
            }
            print("Uart should not founf")
            
        }
    }
    
    //MARK: peripheral characteristic
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        if (error != nil){
            print("Error \(error)")
            
        }else{
            print("Discovered Characteristic")
            
            var txChracteristic : CBCharacteristic!
            if(service.uuid.isEqual(UARTSERVICEUUIDSTRING)){
                
                for characteristic in service.characteristics!{
                    if(characteristic.uuid.isEqual(UARTTXCHARACTERISTICUUIDSTRING)){
                        txChracteristic = characteristic
                    }else if(characteristic.uuid.isEqual(UARTRXCHARACTERISTICUUIDSTRING)){
                        uartRXCharacteristic = characteristic
                    }
                    
                }
            }
            
            //Enable notification
            if(txChracteristic != nil && self.uartRXCharacteristic != nil){
                bluetoothPeripheral.setNotifyValue(true, for: txChracteristic)
                
            }else{
                print("Not support")
            }
            logon()
            
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if (error != nil){
            print("Enable notification Error \(error)")
            
        }else{
            
            if(characteristic.isNotifying){
                print("Notification enabled")
            }else{
                print("Notification disable")
            }
            
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        
        if (error != nil){
            print("Write Descriptor Characterisctic Error \(error)")
            
        }else{
            print("data write to %s", descriptor.uuid.uuidString)
            
        }
        
    }
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if (error != nil){
            print("Write Characterisctic Error \(error)")
            
        }else{
            print("data write to %s", characteristic.uuid.uuidString)
            
        }
        
    }
    
    func showNotifycation(_ message : String){
        let localNotify = UILocalNotification()
        localNotify.fireDate = Date(timeIntervalSinceNow: 1)
        localNotify.alertBody = message
        localNotify.soundName = UILocalNotificationDefaultSoundName
        UIApplication.shared.presentLocalNotificationNow(localNotify)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        if (error != nil){
            print("Update value Error \(error)")
            
        }else{
            // the number of elements:
            let data = characteristic.value
            let count = data!.count / MemoryLayout<UInt8>.size
            // create array of appropriate length:
            var array = [UInt8](repeating: 0, count: count)
            // copy bytes into array
            (data! as NSData).getBytes(&array, length:count * MemoryLayout<UInt8>.size)
            //parser data
            if(array[3] == 0x85){
                delegate.showError("Sai mật khẩu")
            }else if(array[1] == 0x84){
                if(delegateStatus != nil && array.count >= 10){
                    delegateStatus.updateStatus(array[7], cmd2: array[8], cmd3: array[9],cmd4: array[10])
                }
            }else if(array[1] == 0x85){
                if(array[3] == 0){
                    delegateChangePass.success()
                }else{
                    delegateChangePass.error("Đổi mật khẩu không thành công")
                    
                }

            }else if(array[1] == 0x86){
                if(array[3] == 0){
                    delegateRename.rename(newName)
                }else{
                    delegateRename.error("Đổi tên không thành công")
                    
                }
            }else if(array[1] == 0x88){
                showNotifycation("Cảnh báo chế độ rung")
                
            }else if(array[1] == 0x81){

                if(array[3] == 0){
                    print("Logon success")
                    readStatus()
                }else {
                    print("Fail to logon")
                    delegateStatus.logonerror()
                }

            }else if(array[1] == 0x8D){
                
                if( delegateLocation != nil &&  array.count == 12){
                    
                    let turnOn = array[7] == 1 ? true : false
                    delegateLocation.updateLocation(status: turnOn, rssi_current: array[8], rssi_turnOn: array[9], rssi_turnOff: array[10], time: 0x7F)
                }else if (delegateLocation != nil &&  array.count == 13){
                    let turnOn = array[7] == 1 ? true : false
                    delegateLocation.updateLocation(status: turnOn, rssi_current: array[8], rssi_turnOn: array[9], rssi_turnOff: array[10], time: array[11])
                
                }
                
            }else if(array[1] == 0x8F){
                
                if ( delegateVersion != nil &&  array.count > 5){
                    
                    var bytes : [UInt8] = [UInt8]()
                    for ii in 3..<count-1 {
                        bytes.append(array[ii])
                    }
                    let xmlStr:String = String(bytes: bytes, encoding: String.Encoding.utf8)!
                    delegateVersion.updateVersion(version: xmlStr)
                    
                }
                
                
                
                
                
            }
            
            print(array)
        }
        
    }
    
    
    
    

    
}
