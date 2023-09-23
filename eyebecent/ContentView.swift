import UserNotifications
import Combine
import CoreLocation
import SwiftUI
import CoreHaptics
import UserNotifications
import AVFoundation

class BeaconDetector: NSObject, ObservableObject, CLLocationManagerDelegate {
    var audioPlayer: AVAudioPlayer?
    var didChange = PassthroughSubject<Void, Never>()
    var locationManager: CLLocationManager?
    @Published var authStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastDistance = CLProximity.unknown
    @Published var scanStatus = "None"
    
    // Buat instance Core Haptics
    var hapticEngine: CHHapticEngine?
    
    // Buat Timer untuk getaran "far" berulang setiap 5 detik
    var farHapticTimer: Timer?
    
    override init() {
        super.init()
        
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.requestWhenInUseAuthorization()
        
        // Inisialisasi Core Haptics
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Error initializing Core Haptics: \(error)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authStatus = status
    }
    
    func startScanning() {
        if authStatus == .authorizedWhenInUse {
            self.scanStatus = "Initializing"
            if CLLocationManager.isMonitoringAvailable(for: CLBeaconRegion.self) {
                self.scanStatus = "Monitoring Available"
                if CLLocationManager.isRangingAvailable() {
                    self.scanStatus = "Scanning"
                    let uuid = UUID(uuidString: "2D7A9F0C-E0E8-4CC9-A71B-A21DB2D034A1")
                    let constraint = CLBeaconIdentityConstraint(uuid: uuid!, major: 5, minor: 88)
                    let beaconRegion = CLBeaconRegion(beaconIdentityConstraint: constraint, identifier: "MyBeacon")
                    
                    locationManager?.startMonitoring(for: beaconRegion)
                    locationManager?.startRangingBeacons(satisfying: constraint)
                } else {
                    self.scanStatus = "Can't Scan"
                }
            }
        }
    }
    func playSoundForNear() {
        guard let soundURL = Bundle.main.url(forResource: "Qiu_Qiu", withExtension: "m4a") else {
            print("Sound file not found")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.play()
        } catch {
            print("Error playing sound: \(error)")
        }
    }

    func stopScanning() {
        let uuid = UUID(uuidString: "2D7A9F0C-E0E8-4CC9-A71B-A21DB2D034A1")
        let constraint = CLBeaconIdentityConstraint(uuid: uuid!, major: 5, minor: 88)
        let beaconRegion = CLBeaconRegion(beaconIdentityConstraint: constraint, identifier: "MyBeacon")
        locationManager?.stopRangingBeacons(satisfying: constraint)
        locationManager?.stopMonitoring(for: beaconRegion)
        
        // Hentikan Timer jika ada
        farHapticTimer?.invalidate()
    }
    
    func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying beaconConstraint: CLBeaconIdentityConstraint) {
        if let beacon = beacons.first {
            update(distance: beacon.proximity)
        } else {
            update(distance: .unknown)
        }
    }
    
    // Fungsi untuk melakukan getaran "far" menggunakan Core Haptics
    func performHapticFeedbackForFar() {
        guard let hapticEngine = hapticEngine else { return }
        
        do {
            let pattern = try createFarHapticPattern()
            let player = try hapticEngine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Error playing haptic feedback for 'far': \(error)")
        }
    }

    // Fungsi untuk melakukan getaran "near" menggunakan Core Haptics
    func performHapticFeedbackForNear() {
        guard let hapticEngine = hapticEngine else { return }
        
        do {
            let pattern = try createNearHapticPattern()
            let player = try hapticEngine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Error playing haptic feedback for 'near': \(error)")
        }
    }

    
    func update(distance: CLProximity) {
        lastDistance = distance
        didChange.send(())
        
       switch distance {
       case .immediate:
           showNotification(title: "Beacon Detected", body: "You are RIGHT HERE")
           performHapticFeedbackForNear()
       case .near:
           showNotification(title: "Beacon Detected", body: "You are NEAR")
           performHapticFeedbackForNear()
           playSoundForNear() // Play the sound when near

       case .far:
           showNotification(title: "Beacon Detected", body: "You are FAR")
           // Memulai Timer untuk getaran "far" setiap 5 detik
           if farHapticTimer == nil {
               farHapticTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                   self?.performHapticFeedbackForFar()
               }
           }
       default:
           // Hapus notifikasi jika beacon tidak terdeteksi dalam jarak tertentu
           UNUserNotificationCenter.current().removeAllDeliveredNotifications()
       }
   }
   
   func createNearHapticPattern() throws -> CHHapticPattern {
       let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
       let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
       
       let event1 = try CHHapticEvent(eventType: .hapticTransient, parameters: [sharpness, intensity], relativeTime: 0)
       let event2 = try CHHapticEvent(eventType: .hapticTransient, parameters: [sharpness, intensity], relativeTime: 0.05)
       
       let pattern = try CHHapticPattern(events: [event1, event2], parameters: [])
       return pattern
   }
   
   func createFarHapticPattern() throws -> CHHapticPattern {
       let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
       let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
       
       let event1 = try CHHapticEvent(eventType: .hapticTransient, parameters: [sharpness, intensity], relativeTime: 0)
       let event2 = try CHHapticEvent(eventType: .hapticTransient, parameters: [sharpness, intensity], relativeTime: 0.1)
       
       let pattern = try CHHapticPattern(events: [event1, event2], parameters: [])
       return pattern
   }
}

struct BigText: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Font.system(size: 64, design: .rounded))
    }
}

struct ContentView: View {
    @ObservedObject var detector = BeaconDetector()
    var advertiser = BroadcastBeacon()
    var body: some View {
        VStack{
            HStack{
                Button{
                    advertiser.stopLocalBeacon()
                    if (detector.authStatus == .authorizedWhenInUse){
                        detector.startScanning()
                    }
                } label: {
                    Text("Scan")
                }
                .buttonStyle(.borderedProminent)
                
                Button{
                    detector.stopScanning()
                    advertiser.startLocalBeacon()
                } label: {
                    Text("Advertise")
                }
                .buttonStyle(.borderedProminent)
            }
            Text(detector.scanStatus)
                .modifier(BigText())
            Text(advertiser.advStatus)
                .modifier(BigText())
            if detector.lastDistance == .immediate {
                Text("RIGHT HERE")
                    .modifier(BigText())
                    .background(.red)
            } else if detector.lastDistance == .near {
                Text("NEAR")
                    .modifier(BigText())
                    .background(.orange)
            }
            else if detector.lastDistance == .far {
                Text("FAR")
                    .modifier(BigText())
                    .background(.blue)
            } else {
                Text("UNKNOWN")
                    .modifier(BigText())
                    .background(.gray)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
