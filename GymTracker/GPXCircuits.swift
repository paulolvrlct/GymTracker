import Foundation
import CoreLocation

// MARK: - Circuit de course préenregistré

/// Parcours figé chargé depuis un fichier .gpx embarqué dans le bundle.
/// Pour ajouter un circuit : déposer un .gpx standard dans `GymTracker/Circuits/`.
struct RunCircuit: Identifiable {
    let id: String              // nom de fichier
    let name: String
    let coordinates: [CLLocationCoordinate2D]

    /// Longueur du tracé en km (somme des segments)
    var distanceKm: Double {
        guard coordinates.count > 1 else { return 0 }
        var total = 0.0
        for i in 1..<coordinates.count {
            let a = CLLocation(latitude: coordinates[i - 1].latitude, longitude: coordinates[i - 1].longitude)
            let b = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            total += b.distance(from: a)
        }
        return total / 1000
    }
}

extension RunCircuit: Hashable {
    static func == (lhs: RunCircuit, rhs: RunCircuit) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Bibliothèque des circuits du bundle

enum CircuitLibrary {
    static let all: [RunCircuit] = {
        let urls = Bundle.main.urls(forResourcesWithExtension: "gpx", subdirectory: nil) ?? []
        return urls
            .compactMap { GPXParser.parse(url: $0) }
            .sorted { $0.name < $1.name }
    }()
}

// MARK: - Parser GPX léger (XMLParser Foundation)

/// Extrait le premier <name> et tous les points <trkpt>/<rtept> (attributs lat/lon).
final class GPXParser: NSObject, XMLParserDelegate {
    private var coordinates: [CLLocationCoordinate2D] = []
    private var name: String?
    private var currentElement = ""

    static func parse(url: URL) -> RunCircuit? {
        guard let parser = XMLParser(contentsOf: url) else { return nil }
        let delegate = GPXParser()
        parser.delegate = delegate
        guard parser.parse(), delegate.coordinates.count > 1 else { return nil }
        return RunCircuit(
            id: url.lastPathComponent,
            name: delegate.name ?? url.deletingPathExtension().lastPathComponent,
            coordinates: delegate.coordinates
        )
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "trkpt" || elementName == "rtept",
           let lat = attributeDict["lat"].flatMap(Double.init),
           let lon = attributeDict["lon"].flatMap(Double.init) {
            coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard currentElement == "name", name == nil else { return }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { name = trimmed }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        currentElement = ""
    }
}
