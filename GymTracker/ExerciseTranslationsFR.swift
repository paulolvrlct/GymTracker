import Foundation

/// Traductions françaises des instructions d'exercices.
/// Le dataset source (hasaneyldrm/exercises-dataset) n'existe pas en français :
/// on fournit ici une traduction manuelle pour les exercices du programme.
/// Clé = ID catalogue. Pour en ajouter, il suffit d'insérer une entrée.
enum ExerciseTranslationsFR {

    static let steps: [String: [String]] = [

        // Développé incliné barre
        "0047": [
            "Règle un banc incliné à environ 30-45°.",
            "Allonge-toi, pieds bien à plat au sol.",
            "Saisis la barre en pronation, un peu plus large que la largeur d'épaules.",
            "Déracke la barre et descends-la lentement vers le haut des pecs, coudes à ~45°.",
            "Marque un temps d'arrêt en bas, puis repousse la barre jusqu'à l'extension.",
            "Répète pour le nombre de répétitions voulu.",
        ],

        // Développé incliné haltères
        "0314": [
            "Règle un banc incliné à environ 30-45°.",
            "Assieds-toi, pieds à plat, dos bien plaqué contre le dossier.",
            "Un haltère dans chaque main, paumes vers l'avant, monte-les à hauteur d'épaules.",
            "Descends lentement les haltères sur les côtés de la poitrine, coudes à ~90°.",
            "Repousse les haltères vers le haut jusqu'à l'extension complète des bras.",
            "Répète pour le nombre de répétitions voulu.",
        ],

        // Chest press (machine)
        "0577": [
            "Règle la hauteur du siège, dos bien plaqué contre le dossier.",
            "Saisis les poignées en pronation, coudes à ~90°.",
            "Pousse les poignées vers l'avant jusqu'à l'extension des bras, en expirant.",
            "Marque une pause en fin de mouvement, puis reviens lentement en inspirant.",
            "Répète pour le nombre de répétitions voulu.",
        ],

        // Papillon / pec deck
        "0596": [
            "Règle la hauteur du siège, dos contre le dossier.",
            "Saisis les poignées, coudes légèrement fléchis.",
            "Expire et ramène les poignées l'une vers l'autre devant la poitrine.",
            "Marque un temps d'arrêt en contractant les pectoraux.",
            "Inspire et reviens lentement en laissant les pecs s'étirer.",
            "Répète pour le nombre de répétitions voulu.",
        ],

        // Tractions supination (chin-up)
        "1326": [
            "Suspends-toi à la barre, paumes vers toi, mains largeur d'épaules.",
            "Gaine le tronc et tire le corps vers la barre en menant avec la poitrine.",
            "Continue jusqu'à passer le menton au-dessus de la barre.",
            "Marque une pause en haut, puis redescends lentement en contrôle.",
            "Répète pour le nombre de répétitions voulu.",
        ],

        // Curl barre EZ
        "0447": [
            "Debout, pieds largeur d'épaules, saisis la barre EZ en supination.",
            "Garde les coudes près du buste et les bras immobiles pendant tout le mouvement.",
            "Expire en enroulant la barre vers les épaules, contraction des biceps.",
            "Pause en haut, puis inspire en redescendant lentement.",
            "Répète pour le nombre de répétitions voulu.",
        ],

        // Curl marteau haltères (alterné)
        "1648": [
            "Assis, un haltère dans chaque main, paumes face au buste, bras tendus.",
            "Dos droit, coudes près du corps.",
            "Expire et enroule l'haltère droit vers l'épaule, bras immobile.",
            "Monte jusqu'à contraction complète du biceps.",
            "Pause brève, puis inspire en redescendant lentement.",
            "Répète avec le bras gauche, en alternant.",
        ],

        // Dips triceps
        "0814": [
            "Buste vertical, mains en appui sur les barres (ou le banc).",
            "Descends en fléchissant les coudes, sans partir en avant.",
            "Arrête-toi coudes à ~90°, en gardant le buste droit pour cibler les triceps.",
            "Pause en bas, puis repousse jusqu'à l'extension.",
            "Répète pour le nombre de répétitions voulu.",
        ],

        // Extensions triceps poulie
        "0241": [
            "Fixe une barre en V à la poulie haute.",
            "Debout face à la machine, pieds largeur d'épaules.",
            "Saisis la barre en pronation, coudes collés au corps et immobiles.",
            "Expire en poussant vers le bas jusqu'à l'extension complète des bras.",
            "Pause en bas en contractant les triceps.",
            "Inspire en remontant lentement, sous contrôle.",
        ],

        // Crunch poulie haute
        "0175": [
            "Fixe une corde à la poulie haute et mets-toi à genoux, dos à la machine.",
            "Tiens la corde derrière la tête, coudes vers l'extérieur.",
            "Hanches fixes, enroule le buste vers les cuisses en soufflant.",
            "Pause en bas, puis reviens lentement.",
            "Répète pour le nombre de répétitions voulu.",
        ],

        // Relevés de jambes suspendu
        "0472": [
            "Suspends-toi à la barre, bras tendus.",
            "Gaine le tronc et lève les jambes devant toi, tendues (ou genoux pliés).",
            "Monte jusqu'à l'horizontale, ou aussi haut que possible sans balancier.",
            "Pause en haut, puis redescends lentement.",
            "Répète pour le nombre de répétitions voulu.",
        ],

        // Gainage planche (lestée)
        "2135": [
            "Place les avant-bras au sol, coudes sous les épaules.",
            "Jambes tendues derrière, appui sur la pointe des pieds.",
            "Gaine et décolle le corps : appui avant-bras + pointes de pieds.",
            "Garde le corps aligné de la tête aux talons (bassin rétroversé, pas de dos creusé).",
            "Tiens la position le temps voulu (note les secondes dans le champ reps).",
        ],

        // Rotations russes
        "0687": [
            "Assis au sol, genoux fléchis, pieds à plat.",
            "Incline légèrement le buste en arrière, dos droit, tronc gaîné.",
            "Mains jointes devant la poitrine (ou un disque léger).",
            "Décolle les pieds, en équilibre sur les ischions.",
            "Fais pivoter le buste à droite, puis à gauche, sous contrôle.",
            "Continue en alternant les côtés.",
        ],
    ]

    /// Renvoie les étapes FR si disponibles, sinon nil (fallback EN dans l'UI).
    static func steps(for catalogID: String?) -> [String]? {
        guard let catalogID else { return nil }
        return steps[catalogID]
    }
}
