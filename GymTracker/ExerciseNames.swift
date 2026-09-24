import Foundation

// MARK: - Noms d'exercices traduits

/// Deux niveaux de traduction pour les noms du dataset, qui est en anglais :
/// - une liste curée d'exercices courants, soignée en français, anglais et
///   espagnol dans le String Catalog ;
/// - en interface française, la traduction de tout le catalogue
///   (`ExerciseTranslationsFR`), qui prend le relais hors liste curée.
/// En anglais et en espagnol, un exercice hors liste garde son nom source.
///
/// La liste curée s'étoffe à chaque version : il suffit d'ajouter un `case` ici
/// et les trois traductions dans le String Catalog.
enum ExerciseNames {

    /// Nom traduit, ou nil si l'exercice n'est pas localisé dans la langue courante.
    static func localized(id: String) -> String? {
        curated(id: id) ?? ExerciseTranslationsFR.name(for: id)
    }

    /// Nom de la liste curée, ou nil. Figurer dans cette liste signale aussi un
    /// exercice courant, ce que le remplacement d'exercice prend en compte.
    static func curated(id: String) -> String? {
        switch id {
        case "0003": String(localized: "exercise.name.0003")   // air bike
        case "0017": String(localized: "exercise.name.0017")   // assisted pull-up
        case "0025": String(localized: "exercise.name.0025")   // barbell bench press
        case "0027": String(localized: "exercise.name.0027")   // barbell bent over row
        case "0030": String(localized: "exercise.name.0030")   // barbell close-grip bench press
        case "0031": String(localized: "exercise.name.0031")   // barbell curl
        case "0032": String(localized: "exercise.name.0032")   // barbell deadlift
        case "0033": String(localized: "exercise.name.0033")   // barbell decline bench press
        case "0042": String(localized: "exercise.name.0042")   // barbell front squat
        case "0043": String(localized: "exercise.name.0043")   // barbell full squat
        case "0044": String(localized: "exercise.name.0044")   // barbell good morning
        case "0047": String(localized: "exercise.name.0047")   // barbell incline bench press
        case "0054": String(localized: "exercise.name.0054")   // barbell lunge
        case "0060": String(localized: "exercise.name.0060")   // barbell lying triceps extension skull crusher
        case "0085": String(localized: "exercise.name.0085")   // barbell romanian deadlift
        case "0091": String(localized: "exercise.name.0091")   // barbell seated overhead press
        case "0095": String(localized: "exercise.name.0095")   // barbell shrug
        case "0117": String(localized: "exercise.name.0117")   // barbell sumo deadlift
        case "0120": String(localized: "exercise.name.0120")   // barbell upright row
        case "0150": String(localized: "exercise.name.0150")   // cable bar lateral pulldown
        case "0175": String(localized: "exercise.name.0175")   // cable kneeling crunch
        case "0194": String(localized: "exercise.name.0194")   // cable overhead triceps extension (rope attachment)
        case "0198": String(localized: "exercise.name.0198")   // cable pulldown
        case "0200": String(localized: "exercise.name.0200")   // cable pushdown (with rope attachment)
        case "0201": String(localized: "exercise.name.0201")   // cable pushdown
        case "0212": String(localized: "exercise.name.0212")   // cable seated crunch
        case "0227": String(localized: "exercise.name.0227")   // cable standing fly
        case "0241": String(localized: "exercise.name.0241")   // cable triceps pushdown (v-bar)
        case "0251": String(localized: "exercise.name.0251")   // chest dip
        case "0274": String(localized: "exercise.name.0274")   // crunch floor
        case "0289": String(localized: "exercise.name.0289")   // dumbbell bench press
        case "0292": String(localized: "exercise.name.0292")   // dumbbell one arm bent-over row
        case "0293": String(localized: "exercise.name.0293")   // dumbbell bent over row
        case "0294": String(localized: "exercise.name.0294")   // dumbbell biceps curl
        case "0297": String(localized: "exercise.name.0297")   // dumbbell concentration curl
        case "0308": String(localized: "exercise.name.0308")   // dumbbell fly
        case "0310": String(localized: "exercise.name.0310")   // dumbbell front raise
        case "0313": String(localized: "exercise.name.0313")   // dumbbell hammer curl
        case "0314": String(localized: "exercise.name.0314")   // dumbbell incline bench press
        case "0318": String(localized: "exercise.name.0318")   // dumbbell incline curl
        case "0319": String(localized: "exercise.name.0319")   // dumbbell incline fly
        case "0333": String(localized: "exercise.name.0333")   // dumbbell kickback
        case "0334": String(localized: "exercise.name.0334")   // dumbbell lateral raise
        case "0336": String(localized: "exercise.name.0336")   // dumbbell lunge
        case "0372": String(localized: "exercise.name.0372")   // dumbbell preacher curl
        case "0375": String(localized: "exercise.name.0375")   // dumbbell pullover
        case "0405": String(localized: "exercise.name.0405")   // dumbbell seated shoulder press
        case "0406": String(localized: "exercise.name.0406")   // dumbbell shrug
        case "0431": String(localized: "exercise.name.0431")   // dumbbell step-up
        case "0432": String(localized: "exercise.name.0432")   // dumbbell stiff leg deadlift
        case "0447": String(localized: "exercise.name.0447")   // ez barbell curl
        case "0472": String(localized: "exercise.name.0472")   // hanging leg raise
        case "0489": String(localized: "exercise.name.0489")   // hyperextension
        case "0499": String(localized: "exercise.name.0499")   // inverted row
        case "0514": String(localized: "exercise.name.0514")   // jump squat
        case "0534": String(localized: "exercise.name.0534")   // kettlebell goblet squat
        case "0549": String(localized: "exercise.name.0549")   // kettlebell swing
        case "0577": String(localized: "exercise.name.0577")   // lever chest press
        case "0585": String(localized: "exercise.name.0585")   // lever leg extension
        case "0586": String(localized: "exercise.name.0586")   // lever lying leg curl
        case "0596": String(localized: "exercise.name.0596")   // lever seated fly
        case "0597": String(localized: "exercise.name.0597")   // lever seated hip abduction
        case "0598": String(localized: "exercise.name.0598")   // lever seated hip adduction
        case "0599": String(localized: "exercise.name.0599")   // lever seated leg curl
        case "0603": String(localized: "exercise.name.0603")   // lever shoulder press
        case "0605": String(localized: "exercise.name.0605")   // lever standing calf raise
        case "0606": String(localized: "exercise.name.0606")   // lever t bar row
        case "0630": String(localized: "exercise.name.0630")   // mountain climber
        case "0652": String(localized: "exercise.name.0652")   // pull-up
        case "0662": String(localized: "exercise.name.0662")   // push-up
        case "0687": String(localized: "exercise.name.0687")   // russian twist
        case "0739": String(localized: "exercise.name.0739")   // sled 45° leg press
        case "0743": String(localized: "exercise.name.0743")   // sled hack squat
        case "0770": String(localized: "exercise.name.0770")   // smith squat
        case "0814": String(localized: "exercise.name.0814")   // triceps dip
        case "0861": String(localized: "exercise.name.0861")   // cable seated row
        case "0868": String(localized: "exercise.name.0868")   // cable curl
        case "0872": String(localized: "exercise.name.0872")   // reverse crunch
        case "1160": String(localized: "exercise.name.1160")   // burpee
        case "1326": String(localized: "exercise.name.1326")   // chin-up
        case "1350": String(localized: "exercise.name.1350")   // lever seated row
        case "1372": String(localized: "exercise.name.1372")   // barbell standing calf raise
        case "1409": String(localized: "exercise.name.1409")   // barbell glute bridge
        case "1429": String(localized: "exercise.name.1429")   // wide grip pull-up
        case "1459": String(localized: "exercise.name.1459")   // dumbbell romanian deadlift
        case "1648": String(localized: "exercise.name.1648")   // dumbbell alternate seated hammer curl
        case "1760": String(localized: "exercise.name.1760")   // dumbbell goblet squat
        case "2133": String(localized: "exercise.name.2133")   // farmers walk
        case "2135": String(localized: "exercise.name.2135")   // weighted front plank
        case "2137": String(localized: "exercise.name.2137")   // dumbbell arnold press
        case "2292": String(localized: "exercise.name.2292")   // dumbbell rear delt raise
        case "2368": String(localized: "exercise.name.2368")   // split squats
        case "2612": String(localized: "exercise.name.2612")   // jump rope
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
