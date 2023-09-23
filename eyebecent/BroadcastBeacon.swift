//
//  BroadcastBeacon.swift
//  eyebecent
//
//  Created by Farid Azhari on 12/09/23.
//

import CoreBluetooth
import CoreLocation
import Foundation

class BroadcastBeacon:NSObject,ObservableObject, CBPeripheralManagerDelegate{
    var localBeacon: CLBeaconRegion?
        var beaconPeripheralData: NSDictionary?
        var peripheralManager: CBPeripheralManager?
    @Published var advStatus = "None"
    
    func initLocalBeacon() {
           if localBeacon != nil {
               stopLocalBeacon()
           }
        
        let localBeaconUUID = "5A4BCFCE-174E-4BAC-A814-092E77F6B7E5"
        let localBeaconMajor: CLBeaconMajorValue = 123
        let localBeaconMinor: CLBeaconMinorValue = 456

        let uuid = UUID(uuidString: localBeaconUUID)!
        localBeacon = CLBeaconRegion(uuid: uuid, major: localBeaconMajor, minor: localBeaconMinor, identifier: "MyBeacon")

        beaconPeripheralData = localBeacon?.peripheralData(withMeasuredPower: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: nil)
       }

    func startLocalBeacon(){
        advStatus = "Advertising"
        if localBeacon != nil {
            stopLocalBeacon()
        }
     
     let localBeaconUUID = "5A4BCFCE-174E-4BAC-A814-092E77F6B7E5"
     let localBeaconMajor: CLBeaconMajorValue = 123
     let localBeaconMinor: CLBeaconMinorValue = 456

     let uuid = UUID(uuidString: localBeaconUUID)!
     localBeacon = CLBeaconRegion(uuid: uuid, major: localBeaconMajor, minor: localBeaconMinor, identifier: "MyBeacon")

     beaconPeripheralData = localBeacon?.peripheralData(withMeasuredPower: nil)
     peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: nil)
        peripheralManager?.startAdvertising(beaconPeripheralData as? [String: Any])
    }
    
       func stopLocalBeacon() {
           peripheralManager?.stopAdvertising()
           peripheralManager = nil
           beaconPeripheralData = nil
           localBeacon = nil
           advStatus = "Stop Advertising"
       }

       func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
           if peripheral.state == .poweredOn {
               advStatus = "Advertising"
               peripheralManager?.startAdvertising(beaconPeripheralData as? [String: Any])
           } else if peripheral.state == .poweredOff {
               advStatus = "Stop Advertising"
               peripheralManager?.stopAdvertising()
           }
       }
}
