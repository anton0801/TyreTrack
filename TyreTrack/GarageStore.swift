//
//  GarageStore.swift
//  TyreTrack
//
//  Single source of truth for vehicles + reminders.
//  Persists to UserDefaults as JSON with debounced autosave. Photos are
//  NOT part of that blob — they live on disk via PhotoStore and the
//  vehicle keeps only the file name.
//

import SwiftUI
import Combine

final class GarageStore: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    @Published var reminders: [TyreReminder] = []

    private let vehiclesKey = "tyretrack.state.v1"
    private let remindersKey = "tyretrack.reminders.v1"
    private var bag = Set<AnyCancellable>()

    init() {
        load()
        // Debounced autosave whenever anything published changes.
        $vehicles
            .dropFirst()
            .debounce(for: .seconds(0.4), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.saveVehicles() }
            .store(in: &bag)
        $reminders
            .dropFirst()
            .debounce(for: .seconds(0.4), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.saveReminders() }
            .store(in: &bag)
    }

    // MARK: - Persistence

    private func load() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: vehiclesKey),
           let decoded = try? JSONDecoder().decode([Vehicle].self, from: data) {
            vehicles = decoded
            migrateInlinePhotos(from: data)
        }
        if let data = d.data(forKey: remindersKey),
           let decoded = try? JSONDecoder().decode([TyreReminder].self, from: data) {
            reminders = decoded
        }
        PhotoStore.pruneOrphans(keeping: Set(vehicles.compactMap { $0.photoFile }))
    }

    /// One-time move of photos that used to be encoded straight into the
    /// defaults blob. After this runs the blob is rewritten without them.
    private func migrateInlinePhotos(from data: Data) {
        guard let legacy = try? JSONDecoder().decode([LegacyPhotoRecord].self, from: data) else { return }
        var migrated = false
        for record in legacy {
            guard let blob = record.photoData, !blob.isEmpty,
                  let idx = vehicles.firstIndex(where: { $0.id == record.id }),
                  vehicles[idx].photoFile == nil,
                  let file = PhotoStore.save(data: blob) else { continue }
            vehicles[idx].photoFile = file
            migrated = true
        }
        if migrated { saveVehicles() }
    }

    /// Decodes ONLY the legacy inline photo blob from a v1 payload so it can
    /// be moved to disk exactly once. This is the single place in the app
    /// that still knows the old key exists.
    private struct LegacyPhotoRecord: Decodable {
        let id: UUID
        let photoData: Data?
    }

    private func saveVehicles() {
        if let data = try? JSONEncoder().encode(vehicles) {
            UserDefaults.standard.set(data, forKey: vehiclesKey)
        }
    }

    private func saveReminders() {
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: remindersKey)
        }
    }

    /// Force an immediate write (used by explicit Save buttons).
    func flush() {
        saveVehicles()
        saveReminders()
    }

    // MARK: - Vehicle CRUD

    func add(_ vehicle: Vehicle) {
        vehicles.append(vehicle)
    }

    func update(_ vehicle: Vehicle) {
        guard let idx = vehicles.firstIndex(where: { $0.id == vehicle.id }) else { return }
        vehicles[idx] = vehicle
    }

    /// Replace a vehicle's photo, deleting the file it had before.
    func setPhoto(_ image: UIImage, for vehicleID: UUID) {
        guard let idx = vehicles.firstIndex(where: { $0.id == vehicleID }) else { return }
        guard let file = PhotoStore.save(image) else { return }
        PhotoStore.delete(vehicles[idx].photoFile)
        vehicles[idx].photoFile = file
        flush()
    }

    /// Deleting a vehicle takes its reminders (and their pending
    /// notifications) and its photo file with it.
    func delete(_ vehicle: Vehicle) {
        let orphaned = reminders.filter { $0.vehicleID == vehicle.id }
        for r in orphaned { NotificationManager.shared.cancel(r) }
        reminders.removeAll { $0.vehicleID == vehicle.id }
        PhotoStore.delete(vehicle.photoFile)
        vehicles.removeAll { $0.id == vehicle.id }
        flush()
    }

    /// How many reminders would go with this vehicle — used to name the
    /// consequences in the confirmation dialog.
    func reminderCount(for vehicle: Vehicle) -> Int {
        reminders.filter { $0.vehicleID == vehicle.id }.count
    }

    func duplicate(_ vehicle: Vehicle) {
        var copy = vehicle
        copy.id = UUID()
        copy.title = vehicle.displayTitle + " (copy)"
        copy.createdAt = Date()
        // The copy gets its own photo file so deleting either is safe.
        if let image = PhotoStore.image(named: vehicle.photoFile) {
            copy.photoFile = PhotoStore.save(image)
        } else {
            copy.photoFile = nil
        }
        vehicles.append(copy)
    }

    func vehicle(id: UUID?) -> Vehicle? {
        guard let id = id else { return nil }
        return vehicles.first { $0.id == id }
    }

    /// Convenience binding to mutate a vehicle in place from a detail screen.
    func binding(for vehicle: Vehicle) -> Binding<Vehicle> {
        Binding(
            get: { self.vehicles.first(where: { $0.id == vehicle.id }) ?? vehicle },
            set: { newValue in self.update(newValue) }
        )
    }

    // MARK: - Reminders

    func addReminder(_ r: TyreReminder) { reminders.append(r) }

    /// Always cancels the pending notification — a deleted reminder must
    /// never be able to fire.
    func deleteReminder(_ r: TyreReminder) {
        NotificationManager.shared.cancel(r)
        reminders.removeAll { $0.id == r.id }
        flush()
    }

    // MARK: - Bulk

    func clearAll() {
        for r in reminders { NotificationManager.shared.cancel(r) }
        NotificationManager.shared.cancelAll()
        for v in vehicles { PhotoStore.delete(v.photoFile) }
        vehicles.removeAll()
        reminders.removeAll()
        PhotoStore.pruneOrphans(keeping: [])
        flush()
    }
}
