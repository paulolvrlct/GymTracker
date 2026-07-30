import Foundation

// MARK: - Vocabulaire du dataset d'exercices, traduit

/// Le dataset source (`exercises_catalog.json`) est en anglais : ses valeurs de
/// `category`, `equipment`, `target` et `secondary` forment un vocabulaire fermé.
/// On le traduit ici via le String Catalog.
///
/// Les clés sont des identifiants stables (`exercise.category.back`) et non le
/// texte affiché : cela évite toute collision avec les libellés d'interface
/// (« Barre » le réglage de barre n'est pas « Barre » le matériel), et le
/// français y est fourni explicitement, comme les autres langues.
///
/// Repli : si un terme inconnu apparaît dans une future version du dataset, on
/// affiche le terme source capitalisé plutôt que rien.
enum ExerciseTaxonomy {

    static func category(_ raw: String) -> String {
        switch raw {
        case "back": String(localized: "exercise.category.back")
        case "cardio": String(localized: "exercise.category.cardio")
        case "chest": String(localized: "exercise.category.chest")
        case "lower arms": String(localized: "exercise.category.lower_arms")
        case "lower legs": String(localized: "exercise.category.lower_legs")
        case "neck": String(localized: "exercise.category.neck")
        case "shoulders": String(localized: "exercise.category.shoulders")
        case "upper arms": String(localized: "exercise.category.upper_arms")
        case "upper legs": String(localized: "exercise.category.upper_legs")
        case "waist": String(localized: "exercise.category.waist")
        default: raw.capitalized
        }
    }

    static func equipment(_ raw: String) -> String {
        switch raw {
        case "assisted": String(localized: "exercise.equipment.assisted")
        case "band": String(localized: "exercise.equipment.band")
        case "barbell": String(localized: "exercise.equipment.barbell")
        case "body weight": String(localized: "exercise.equipment.body_weight")
        case "bosu ball": String(localized: "exercise.equipment.bosu_ball")
        case "cable": String(localized: "exercise.equipment.cable")
        case "dumbbell": String(localized: "exercise.equipment.dumbbell")
        case "elliptical machine": String(localized: "exercise.equipment.elliptical_machine")
        case "ez barbell": String(localized: "exercise.equipment.ez_barbell")
        case "hammer": String(localized: "exercise.equipment.hammer")
        case "kettlebell": String(localized: "exercise.equipment.kettlebell")
        case "leverage machine": String(localized: "exercise.equipment.leverage_machine")
        case "medicine ball": String(localized: "exercise.equipment.medicine_ball")
        case "olympic barbell": String(localized: "exercise.equipment.olympic_barbell")
        case "resistance band": String(localized: "exercise.equipment.resistance_band")
        case "roller": String(localized: "exercise.equipment.roller")
        case "rope": String(localized: "exercise.equipment.rope")
        case "skierg machine": String(localized: "exercise.equipment.skierg_machine")
        case "sled machine": String(localized: "exercise.equipment.sled_machine")
        case "smith machine": String(localized: "exercise.equipment.smith_machine")
        case "stability ball": String(localized: "exercise.equipment.stability_ball")
        case "stationary bike": String(localized: "exercise.equipment.stationary_bike")
        case "stepmill machine": String(localized: "exercise.equipment.stepmill_machine")
        case "tire": String(localized: "exercise.equipment.tire")
        case "trap bar": String(localized: "exercise.equipment.trap_bar")
        case "upper body ergometer": String(localized: "exercise.equipment.upper_body_ergometer")
        case "weighted": String(localized: "exercise.equipment.weighted")
        case "wheel roller": String(localized: "exercise.equipment.wheel_roller")
        default: raw.capitalized
        }
    }

    static func muscle(_ raw: String) -> String {
        switch raw {
        case "abdominals": String(localized: "exercise.muscle.abdominals")
        case "abductors": String(localized: "exercise.muscle.abductors")
        case "abs": String(localized: "exercise.muscle.abs")
        case "adductors": String(localized: "exercise.muscle.adductors")
        case "ankle stabilizers": String(localized: "exercise.muscle.ankle_stabilizers")
        case "ankles": String(localized: "exercise.muscle.ankles")
        case "back": String(localized: "exercise.muscle.back")
        case "biceps": String(localized: "exercise.muscle.biceps")
        case "brachialis": String(localized: "exercise.muscle.brachialis")
        case "calves": String(localized: "exercise.muscle.calves")
        case "cardiovascular system": String(localized: "exercise.muscle.cardiovascular_system")
        case "chest": String(localized: "exercise.muscle.chest")
        case "core": String(localized: "exercise.muscle.core")
        case "deltoids": String(localized: "exercise.muscle.deltoids")
        case "delts": String(localized: "exercise.muscle.delts")
        case "feet": String(localized: "exercise.muscle.feet")
        case "forearms": String(localized: "exercise.muscle.forearms")
        case "glutes": String(localized: "exercise.muscle.glutes")
        case "grip muscles": String(localized: "exercise.muscle.grip_muscles")
        case "groin": String(localized: "exercise.muscle.groin")
        case "hamstrings": String(localized: "exercise.muscle.hamstrings")
        case "hands": String(localized: "exercise.muscle.hands")
        case "hip flexors": String(localized: "exercise.muscle.hip_flexors")
        case "inner thighs": String(localized: "exercise.muscle.inner_thighs")
        case "latissimus dorsi": String(localized: "exercise.muscle.latissimus_dorsi")
        case "lats": String(localized: "exercise.muscle.lats")
        case "levator scapulae": String(localized: "exercise.muscle.levator_scapulae")
        case "lower abs": String(localized: "exercise.muscle.lower_abs")
        case "lower back": String(localized: "exercise.muscle.lower_back")
        case "obliques": String(localized: "exercise.muscle.obliques")
        case "pectorals": String(localized: "exercise.muscle.pectorals")
        case "quadriceps": String(localized: "exercise.muscle.quadriceps")
        case "quads": String(localized: "exercise.muscle.quads")
        case "rear deltoids": String(localized: "exercise.muscle.rear_deltoids")
        case "rhomboids": String(localized: "exercise.muscle.rhomboids")
        case "rotator cuff": String(localized: "exercise.muscle.rotator_cuff")
        case "serratus anterior": String(localized: "exercise.muscle.serratus_anterior")
        case "shins": String(localized: "exercise.muscle.shins")
        case "shoulders": String(localized: "exercise.muscle.shoulders")
        case "soleus": String(localized: "exercise.muscle.soleus")
        case "spine": String(localized: "exercise.muscle.spine")
        case "sternocleidomastoid": String(localized: "exercise.muscle.sternocleidomastoid")
        case "trapezius": String(localized: "exercise.muscle.trapezius")
        case "traps": String(localized: "exercise.muscle.traps")
        case "triceps": String(localized: "exercise.muscle.triceps")
        case "upper back": String(localized: "exercise.muscle.upper_back")
        case "upper chest": String(localized: "exercise.muscle.upper_chest")
        case "wrist extensors": String(localized: "exercise.muscle.wrist_extensors")
        case "wrist flexors": String(localized: "exercise.muscle.wrist_flexors")
        case "wrists": String(localized: "exercise.muscle.wrists")
        default: raw.capitalized
        }
    }

    /// Liste de muscles secondaires, traduite et prête à l'affichage.
    static func muscles(_ raw: [String]) -> String {
        raw.map(muscle).joined(separator: ", ")
    }
}
