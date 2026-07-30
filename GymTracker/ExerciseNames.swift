import Foundation

// MARK: - Noms d'exercices traduits, à la carte

/// Le dataset source est en anglais, et son jargon (« bench press », « curl »,
/// « squat », « shrug ») est précisément celui employé en salle en français comme
/// en espagnol : le traduire systématiquement nuirait à la reconnaissance du
/// mouvement. On ne localise donc que les exercices où la version traduite est
/// réellement plus claire — en commençant par ceux du programme pré-chargé.
///
/// La liste s'étoffe à chaque version : il suffit d'ajouter un `case` ici et les
/// trois traductions dans le String Catalog.
enum ExerciseNames {

    /// Nom traduit, ou nil si l'exercice n'est pas (encore) localisé.
    static func localized(id: String) -> String? {
        switch id {
        case "0047": String(localized: "exercise.name.0047")   // barbell incline bench press
        case "0175": String(localized: "exercise.name.0175")   // cable kneeling crunch
        case "0241": String(localized: "exercise.name.0241")   // cable triceps pushdown (v-bar)
        case "0314": String(localized: "exercise.name.0314")   // dumbbell incline bench press
        case "0447": String(localized: "exercise.name.0447")   // ez barbell curl
        case "0472": String(localized: "exercise.name.0472")   // hanging leg raise
        case "0577": String(localized: "exercise.name.0577")   // lever chest press
        case "0596": String(localized: "exercise.name.0596")   // lever seated fly
        case "0687": String(localized: "exercise.name.0687")   // russian twist
        case "0814": String(localized: "exercise.name.0814")   // triceps dip
        case "1326": String(localized: "exercise.name.1326")   // chin-up
        case "1648": String(localized: "exercise.name.1648")   // dumbbell alternate seated hammer curl
        case "2135": String(localized: "exercise.name.2135")   // weighted front plank
        default: nil
        }
    }

    /// Nom à écrire dans les données au moment du seed : jamais nil, repli sur
    /// le nom source du catalogue.
    ///
    /// Le seed ne s'exécutant qu'au premier lancement, la langue est figée à
    /// l'installation — c'est le comportement voulu : ces séances sont des
    /// données que l'utilisateur peut renommer, on ne doit pas les réécrire
    /// derrière lui à chaque changement de langue.
    static func seedName(_ id: String) -> String {
        localized(id: id) ?? ExerciseCatalog.find(id: id)?.name.capitalized ?? id
    }
}
