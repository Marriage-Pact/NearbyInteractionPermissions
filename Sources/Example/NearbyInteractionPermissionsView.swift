//
//  ContentView.swift
//
//  Created by Ian Thomas on 6/27/25.
//

import SwiftUI
import NearbyInteractionPermissions

final class NearbyInteractionPermissionsViewModel: ObservableObject {
    
    @Published var status: PermissionStatus = .unknown
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc private func willEnterForeground(_ notification: Notification) {
        self.onAppear()
    }
    
    func onAppear() {
        NIPermissionChecker.checkPermissionIfUserHasAlreadyBeenPrompted { [weak self] status in
            guard let self else { return }
            self.updatePermissionStatus(status)}
    }
    
    func userTapped() {
        NIPermissionChecker.userTappedPermissionButton { [weak self] status in
            guard let self else { return }
            self.updatePermissionStatus(status)}
    }
    
    private func updatePermissionStatus(_ status: PermissionStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.status = status
            switch status {
            case .granted:
                print("NI permission granted")
            case .denied:
                print("NI permission directly denied by user")
            case .notSupported:
                print("NI not supported on this device")
            case .unknown:
                print("Could not determine NI permission status, user likely not prompted for permission yet ")
            }
        }
    }
}

struct NearbyInteractionPermissionsView: View {
    
    @ObservedObject var viewModel = NearbyInteractionPermissionsViewModel()
    
    var body: some View {
        VStack {
            Text("Nearby Interaction Permission Status:")
            Text(viewModel.status.displayString)
                .italic()
            Button {
                viewModel.userTapped()
            } label: {
                Text("Request NI Permission")
                    .padding()
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .padding()
    }
}

#Preview {
    NearbyInteractionPermissionsView()
}
