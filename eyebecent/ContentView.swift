import UserNotifications
import Combine
import CoreLocation
import SwiftUI
import CoreHaptics
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
        
        // Request izin notifikasi lokal
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in
            if granted {
                // Izin diberikan, Anda dapat menjadwalkan notifikasi
            } else if let error = error {
                print("Error requesting notification authorization: \(error)")
            }
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
    
    func scheduleBackgroundNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        content.userInfo = ["background": true] // Tambahkan informasi latar belakang

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { (error) in
            if let error = error {
                print("Error scheduling background notification: \(error)")
            }
        }
    }

    
    func playSystemSoundForNear() {
        // ID nada dering "Hero"
        let systemSoundID: SystemSoundID = 1322
        
        // Mainkan nada dering
        AudioServicesPlaySystemSound(systemSoundID)
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
            let rssi = beacon.rssi
            let accuracy = calculateAccuracy(rssi)
            print("Distance in meters: \(accuracy) meters")
            update(distance: beacon.proximity)
        } else {
            update(distance: .unknown)
        }
    }
    
    // Fungsi untuk menghitung jarak berdasarkan RSSI
    func calculateAccuracy(_ rssi: Int) -> Double {
        let txPower = -59 // Nilai kekuatan transmisi dari beacon (biasanya -59)
        let ratio = Double(rssi - txPower) / Double(20)
        return pow(10.0, ratio)
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
            scheduleBackgroundNotification(title: "Beacon Detected", body: "You are RIGHT HERE")
            performHapticFeedbackForNear()
        case .near:
            scheduleBackgroundNotification(title: "Beacon Detected", body: "You are NEAR")
            performHapticFeedbackForNear()
            playSystemSoundForNear()
        case .far:
            scheduleBackgroundNotification(title: "Beacon Detected", body: "You are FAR")
            if farHapticTimer == nil {
                farHapticTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                    self?.performHapticFeedbackForFar()
                }
            }
        default:
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
    }
    
    // Fungsi untuk menjadwalkan notifikasi lokal
    func scheduleLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { (error) in
            if let error = error {
                print("Error scheduling local notification: \(error)")
            }
        }
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
    @State private var isScanning = false // Menambahkan state untuk melacak status pemindaian
    var body: some View {
        VStack {
            HStack {
                Button {
                    advertiser.stopLocalBeacon()
                    if (detector.authStatus == .authorizedWhenInUse) {
                        detector.startScanning()
                        isScanning = true // Setel status pemindaian menjadi true ketika mulai memindai
                    }
                } label: {
                    Text("Scan")
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    detector.stopScanning()
                    advertiser.startLocalBeacon()
                    isScanning = false // Setel status pemindaian menjadi false ketika berhenti memindai
                } label: {
                    Text("Advertise")
                }
                .buttonStyle(.borderedProminent)
                
                // Tombol Stop Scanning
                Button {
                    detector.stopScanning()
                    isScanning = false // Setel status pemindaian menjadi false saat tombol di tekan
                } label: {
                    Text("Stop Scanning")
                }
                .buttonStyle(.borderedProminent)
            }
            
            // Tampilkan status pemindaian
            Text(isScanning ? "Scanning" : "Not Scanning")
                .modifier(BigText())
            
            Text(advertiser.advStatus)
                .modifier(BigText())
            
            // Tampilkan status jarak deteksi beacon dalam meter
            Text(String(format: "Distance: %.2f meters", calculateDistance(detector.lastDistance)))
                .modifier(BigText())
                .background(distanceBackgroundColor(detector.lastDistance))
        }
    }
    
    // Fungsi untuk menghitung jarak berdasarkan CLProximity
    func calculateDistance(_ distance: CLProximity) -> Double {
        switch distance {
        case .immediate:
            return 0.1 // Gantilah dengan jarak deteksi yang sesuai dalam meter
        case .near:
            return 1.0 // Gantilah dengan jarak deteksi yang sesuai dalam meter
        case .far:
            return 10.0 // Gantilah dengan jarak deteksi yang sesuai dalam meter
        default:
            return -1.0 // Nilai negatif menunjukkan status tidak diketahui atau tidak ada deteksi.
        }
    }

    // Fungsi untuk memberikan latar belakang berdasarkan jarak deteksi
    func distanceBackgroundColor(_ distance: CLProximity) -> Color {
        switch distance {
        case .immediate:
            return .red
        case .near:
            return .orange
        case .far:
            return .blue
        default:
            return .gray
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
