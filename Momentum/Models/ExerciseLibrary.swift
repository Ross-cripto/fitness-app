import Foundation

/// The built-in exercise catalogue. Everything ships with the app, so the
/// whole product works offline and never talks to a server.
enum ExerciseLibrary {
    static func exercise(_ id: String) -> Exercise {
        byID[id] ?? all[0]
    }

    /// Optional hand-picked video per exercise id, e.g. `"pushup": "https://www.youtube.com/watch?v=..."`.
    /// Exercises without an entry link to a YouTube search for proper form instead.
    static let curatedVideos: [String: String] = [:]

    static let byID: [String: Exercise] = {
        var map: [String: Exercise] = [:]
        for exercise in all { map[exercise.id] = exercise }
        return map
    }()

    private static func ex(
        _ id: String,
        _ name: String,
        _ muscle: MuscleGroup,
        _ equipment: Equipment,
        _ level: FitnessLevel,
        kind: ExerciseKind = .reps,
        met: Double,
        load: Double? = nil,
        symbol: String? = nil,
        _ steps: [String]
    ) -> Exercise {
        Exercise(
            id: id,
            name: name,
            muscle: muscle,
            equipment: equipment,
            level: level,
            kind: kind,
            met: met,
            loadRatio: load,
            symbol: symbol ?? muscle.symbol,
            steps: steps
        )
    }

    static let all: [Exercise] = [legs, chest, back, shoulders, arms, core, cardio, fullBody, mobility].flatMap { $0 }

    // MARK: Legs

    private static let legs: [Exercise] = [
        ex("bw_squat", "Bodyweight Squat", .legs, .bodyweight, .beginner, met: 5.0, [
            "Stand with feet shoulder-width apart, toes slightly out.",
            "Sit your hips back and down until thighs are parallel to the floor.",
            "Drive through your heels to stand tall."
        ]),
        ex("reverse_lunge", "Reverse Lunge", .legs, .bodyweight, .beginner, met: 5.0, [
            "Stand tall with hands on your hips.",
            "Step one foot back and lower until both knees are at 90°.",
            "Push through the front heel to return. Alternate sides."
        ]),
        ex("glute_bridge", "Glute Bridge", .legs, .bodyweight, .beginner, met: 3.5, [
            "Lie on your back, knees bent, feet flat.",
            "Squeeze your glutes and lift your hips until your body is a straight line.",
            "Pause at the top, then lower with control."
        ]),
        ex("calf_raise", "Calf Raise", .legs, .bodyweight, .beginner, met: 3.5, [
            "Stand tall, feet hip-width apart. Hold a wall for balance if needed.",
            "Rise onto the balls of your feet as high as you can.",
            "Lower slowly."
        ]),
        ex("wall_sit", "Wall Sit", .legs, .bodyweight, .beginner, kind: .timed, met: 4.0, [
            "Lean your back against a wall and slide down until thighs are parallel to the floor.",
            "Keep knees over ankles and press your back into the wall.",
            "Hold, breathing steadily."
        ]),
        ex("jump_squat", "Jump Squat", .legs, .bodyweight, .intermediate, met: 8.0, [
            "Lower into a squat with chest up.",
            "Explode upward, leaving the ground.",
            "Land softly back into the next squat."
        ]),
        ex("split_squat", "Bulgarian Split Squat", .legs, .bodyweight, .advanced, met: 5.5, [
            "Rest your back foot on a chair or bench behind you.",
            "Lower straight down until the front thigh is parallel to the floor.",
            "Drive up through the front heel. Complete all reps, then switch legs."
        ]),
        ex("goblet_squat", "Goblet Squat", .legs, .dumbbells, .beginner, met: 5.0, load: 0.25, [
            "Hold one dumbbell vertically against your chest.",
            "Squat deep, keeping elbows inside your knees.",
            "Stand up tall, squeezing your glutes."
        ]),
        ex("db_rdl", "Dumbbell Romanian Deadlift", .legs, .dumbbells, .beginner, met: 5.0, load: 0.2, [
            "Hold dumbbells in front of your thighs, soft knees.",
            "Push your hips back, sliding the weights down your legs with a flat back.",
            "Feel the hamstring stretch, then squeeze glutes to stand."
        ]),
        ex("db_lunge", "Dumbbell Walking Lunge", .legs, .dumbbells, .intermediate, met: 6.0, load: 0.15, [
            "Hold a dumbbell in each hand at your sides.",
            "Step forward and lower until both knees are at 90°.",
            "Push off the back foot into the next step."
        ]),
        ex("leg_press", "Leg Press", .legs, .fullGym, .beginner, met: 5.0, load: 1.2, [
            "Sit with your back flat and feet shoulder-width on the platform.",
            "Lower the sled until knees reach about 90°.",
            "Press away without locking your knees."
        ]),
        ex("back_squat", "Barbell Back Squat", .legs, .fullGym, .intermediate, met: 6.0, load: 0.9, [
            "Set the bar on your upper back, brace your core.",
            "Sit down and back until thighs are parallel or lower.",
            "Drive up, keeping your chest tall."
        ]),
        ex("deadlift", "Barbell Deadlift", .legs, .fullGym, .intermediate, met: 6.0, load: 1.1, [
            "Stand with the bar over mid-foot, grip just outside your legs.",
            "Brace, keep your back flat and push the floor away.",
            "Lock out with hips and knees together, then lower under control."
        ])
    ]

    // MARK: Chest

    private static let chest: [Exercise] = [
        ex("wall_pushup", "Wall Push-Up", .chest, .bodyweight, .beginner, met: 3.5, [
            "Place hands on a wall at chest height, slightly wider than shoulders.",
            "Bend your elbows to bring your chest toward the wall.",
            "Press back to the start."
        ]),
        ex("knee_pushup", "Knee Push-Up", .chest, .bodyweight, .beginner, met: 3.8, [
            "Start on hands and knees, body straight from knees to head.",
            "Lower your chest to the floor with elbows about 45° from your body.",
            "Press back up."
        ]),
        ex("pushup", "Push-Up", .chest, .bodyweight, .intermediate, met: 6.0, [
            "Hands under shoulders, body in a straight line.",
            "Lower until your chest nearly touches the floor.",
            "Press back up without sagging your hips."
        ]),
        ex("decline_pushup", "Decline Push-Up", .chest, .bodyweight, .advanced, met: 6.5, [
            "Place your feet on a chair or bench, hands on the floor.",
            "Lower your chest toward the floor, core tight.",
            "Press up powerfully."
        ]),
        ex("db_bench", "Dumbbell Bench Press", .chest, .dumbbells, .beginner, met: 5.0, load: 0.25, [
            "Lie on a bench (or the floor) holding dumbbells over your chest.",
            "Lower until elbows are just below the bench line.",
            "Press up and slightly inward."
        ]),
        ex("db_incline_press", "Incline Dumbbell Press", .chest, .dumbbells, .intermediate, met: 5.0, load: 0.22, [
            "Set a bench to about 30°–45° and lie back with dumbbells at shoulder height.",
            "Press the weights up until arms are straight.",
            "Lower slowly to the start."
        ]),
        ex("db_fly", "Dumbbell Fly", .chest, .dumbbells, .intermediate, met: 4.0, load: 0.1, [
            "Lie back with dumbbells above your chest, palms facing in.",
            "Open your arms wide with a slight elbow bend until you feel a stretch.",
            "Squeeze the weights back together."
        ]),
        ex("machine_chest_press", "Machine Chest Press", .chest, .fullGym, .beginner, met: 5.0, load: 0.6, [
            "Adjust the seat so handles line up with mid-chest.",
            "Press forward until arms are nearly straight.",
            "Return slowly, keeping shoulders back."
        ]),
        ex("bench_press", "Barbell Bench Press", .chest, .fullGym, .intermediate, met: 6.0, load: 0.8, [
            "Lie on the bench with eyes under the bar, feet planted.",
            "Lower the bar to your mid-chest with control.",
            "Press it back up over your shoulders."
        ])
    ]

    // MARK: Back

    private static let back: [Exercise] = [
        ex("superman", "Superman", .back, .bodyweight, .beginner, met: 3.0, [
            "Lie face down with arms extended in front.",
            "Lift arms, chest and legs off the floor together.",
            "Hold a moment, then lower."
        ]),
        ex("reverse_snow_angel", "Reverse Snow Angel", .back, .bodyweight, .beginner, met: 3.0, [
            "Lie face down with arms by your sides, lifting chest slightly.",
            "Sweep your arms in an arc overhead and back to your sides.",
            "Keep your neck long."
        ]),
        ex("inverted_row", "Table Inverted Row", .back, .bodyweight, .intermediate, met: 5.0, [
            "Lie under a sturdy table and grip its edge.",
            "Keep your body straight and pull your chest to the table.",
            "Lower slowly."
        ]),
        ex("db_row", "One-Arm Dumbbell Row", .back, .dumbbells, .beginner, met: 5.0, load: 0.25, [
            "Place one hand and knee on a bench or chair, dumbbell in the other hand.",
            "Pull the weight toward your hip, elbow close to your body.",
            "Lower with control, then switch sides."
        ]),
        ex("db_bent_row", "Bent-Over Dumbbell Row", .back, .dumbbells, .intermediate, met: 5.0, load: 0.2, [
            "Hinge at the hips with a flat back, dumbbells hanging.",
            "Row both weights to your ribs.",
            "Squeeze your shoulder blades, then lower."
        ]),
        ex("lat_pulldown", "Lat Pulldown", .back, .fullGym, .beginner, met: 4.5, load: 0.7, [
            "Grip the bar wider than shoulders and sit with thighs secured.",
            "Pull the bar to your upper chest, driving elbows down.",
            "Return slowly to full stretch."
        ]),
        ex("seated_row", "Seated Cable Row", .back, .fullGym, .beginner, met: 4.5, load: 0.6, [
            "Sit tall with a slight knee bend, gripping the handle.",
            "Pull to your stomach, squeezing your shoulder blades.",
            "Extend arms slowly."
        ]),
        ex("barbell_row", "Barbell Row", .back, .fullGym, .intermediate, met: 5.5, load: 0.7, [
            "Hinge forward with a flat back, bar hanging at knee height.",
            "Row the bar to your lower ribs.",
            "Lower under control."
        ]),
        ex("pullup", "Pull-Up", .back, .fullGym, .advanced, met: 6.0, [
            "Hang from a bar with an overhand grip, shoulders active.",
            "Pull until your chin clears the bar.",
            "Lower to a full hang."
        ])
    ]

    // MARK: Shoulders

    private static let shoulders: [Exercise] = [
        ex("plank_tap", "Plank Shoulder Tap", .shoulders, .bodyweight, .beginner, met: 4.0, [
            "Start in a high plank, feet wide for balance.",
            "Tap one shoulder with the opposite hand without rocking your hips.",
            "Alternate sides."
        ]),
        ex("pike_pushup", "Pike Push-Up", .shoulders, .bodyweight, .intermediate, met: 5.0, [
            "From a downward-dog position, hips high.",
            "Bend elbows to lower the top of your head toward the floor.",
            "Press back up."
        ]),
        ex("elevated_pike", "Elevated Pike Push-Up", .shoulders, .bodyweight, .advanced, met: 5.5, [
            "Place your feet on a chair with hips high.",
            "Lower your head between your hands.",
            "Press up strongly."
        ]),
        ex("db_shoulder_press", "Dumbbell Shoulder Press", .shoulders, .dumbbells, .beginner, met: 4.5, load: 0.15, [
            "Hold dumbbells at shoulder height, core braced.",
            "Press overhead until arms are straight.",
            "Lower to your shoulders."
        ]),
        ex("lateral_raise", "Lateral Raise", .shoulders, .dumbbells, .beginner, met: 3.5, load: 0.06, [
            "Stand holding light dumbbells at your sides.",
            "Raise arms out to shoulder height with a soft elbow bend.",
            "Lower slowly."
        ]),
        ex("arnold_press", "Arnold Press", .shoulders, .dumbbells, .intermediate, met: 4.5, load: 0.13, [
            "Start with dumbbells in front of your chest, palms facing you.",
            "Rotate your palms outward as you press overhead.",
            "Reverse the motion to return."
        ]),
        ex("face_pull", "Cable Face Pull", .shoulders, .fullGym, .beginner, met: 4.0, load: 0.25, [
            "Set a rope at face height and pull it toward your forehead.",
            "Flare elbows high and squeeze your rear delts.",
            "Return with control."
        ]),
        ex("overhead_press", "Barbell Overhead Press", .shoulders, .fullGym, .intermediate, met: 5.5, load: 0.5, [
            "Hold the bar at your collarbone, glutes and core tight.",
            "Press it overhead, moving your head through at the top.",
            "Lower back to your collarbone."
        ])
    ]

    // MARK: Arms

    private static let arms: [Exercise] = [
        ex("chair_dip", "Chair Dip", .arms, .bodyweight, .beginner, met: 4.0, [
            "Sit on the edge of a sturdy chair, hands beside your hips.",
            "Slide forward and lower your body by bending your elbows to 90°.",
            "Press back up."
        ]),
        ex("close_pushup", "Close-Grip Push-Up", .arms, .bodyweight, .intermediate, met: 5.5, [
            "Place your hands under your chest, elbows tucked.",
            "Lower down keeping elbows close to your ribs.",
            "Press back up."
        ]),
        ex("diamond_pushup", "Diamond Push-Up", .arms, .bodyweight, .advanced, met: 6.0, [
            "Form a diamond with your thumbs and index fingers under your chest.",
            "Lower your chest to your hands.",
            "Press up."
        ]),
        ex("db_curl", "Dumbbell Curl", .arms, .dumbbells, .beginner, met: 3.5, load: 0.1, [
            "Stand tall holding dumbbells at your sides, palms forward.",
            "Curl to your shoulders without swinging.",
            "Lower slowly."
        ]),
        ex("hammer_curl", "Hammer Curl", .arms, .dumbbells, .beginner, met: 3.5, load: 0.1, [
            "Hold dumbbells with palms facing each other.",
            "Curl up keeping your elbows pinned.",
            "Lower with control."
        ]),
        ex("db_tricep_ext", "Overhead Triceps Extension", .arms, .dumbbells, .beginner, met: 3.5, load: 0.12, [
            "Hold one dumbbell overhead with both hands.",
            "Bend your elbows to lower it behind your head.",
            "Extend back up."
        ]),
        ex("tricep_pushdown", "Cable Triceps Pushdown", .arms, .fullGym, .beginner, met: 3.5, load: 0.3, [
            "Grip the bar at chest height, elbows at your sides.",
            "Push down until arms are straight.",
            "Let it rise slowly."
        ]),
        ex("barbell_curl", "Barbell Curl", .arms, .fullGym, .beginner, met: 3.5, load: 0.3, [
            "Hold the bar with an underhand grip, shoulder-width.",
            "Curl to your chest without leaning back.",
            "Lower under control."
        ])
    ]

    // MARK: Core

    private static let core: [Exercise] = [
        ex("plank", "Plank", .core, .bodyweight, .beginner, kind: .timed, met: 3.5, [
            "Forearms on the floor, elbows under shoulders.",
            "Make a straight line from head to heels.",
            "Squeeze abs and glutes, breathe steadily."
        ]),
        ex("dead_bug", "Dead Bug", .core, .bodyweight, .beginner, met: 3.0, [
            "Lie on your back, arms up, knees bent over hips.",
            "Lower the opposite arm and leg while keeping your back flat.",
            "Return and switch sides."
        ]),
        ex("crunch", "Crunch", .core, .bodyweight, .beginner, met: 3.5, [
            "Lie with knees bent, hands by your temples.",
            "Curl your shoulders off the floor using your abs.",
            "Lower slowly."
        ]),
        ex("bicycle_crunch", "Bicycle Crunch", .core, .bodyweight, .beginner, met: 4.0, [
            "Lie back with hands by your head, legs lifted.",
            "Bring one elbow to the opposite knee while extending the other leg.",
            "Alternate in a pedalling motion."
        ]),
        ex("leg_raise", "Lying Leg Raise", .core, .bodyweight, .intermediate, met: 4.0, [
            "Lie on your back, legs straight, hands under your hips.",
            "Raise your legs to vertical.",
            "Lower without letting your back arch."
        ]),
        ex("russian_twist", "Russian Twist", .core, .bodyweight, .intermediate, met: 4.0, [
            "Sit leaning back with feet slightly raised.",
            "Rotate your torso side to side, touching the floor by your hips.",
            "Keep your chest lifted."
        ]),
        ex("side_plank", "Side Plank", .core, .bodyweight, .intermediate, kind: .timed, met: 3.5, [
            "Lie on one side, forearm under your shoulder.",
            "Lift your hips into a straight line.",
            "Hold, then switch sides."
        ]),
        ex("hollow_hold", "Hollow Hold", .core, .bodyweight, .advanced, kind: .timed, met: 4.0, [
            "Lie on your back, press your lower back into the floor.",
            "Lift shoulders and straight legs a few inches off the ground.",
            "Hold the shallow banana shape."
        ]),
        ex("v_up", "V-Up", .core, .bodyweight, .advanced, met: 4.5, [
            "Lie flat with arms overhead.",
            "Lift your legs and torso to meet in a V.",
            "Lower with control."
        ])
    ]

    // MARK: Cardio

    private static let cardio: [Exercise] = [
        ex("jumping_jacks", "Jumping Jacks", .cardio, .bodyweight, .beginner, kind: .timed, met: 7.5, [
            "Start with feet together, arms at your sides.",
            "Jump feet wide while raising arms overhead.",
            "Jump back and repeat at a steady pace."
        ]),
        ex("high_knees", "High Knees", .cardio, .bodyweight, .beginner, kind: .timed, met: 8.0, [
            "Run in place, driving knees to hip height.",
            "Pump your arms.",
            "Stay light on your feet."
        ]),
        ex("shadow_boxing", "Shadow Boxing", .cardio, .bodyweight, .beginner, kind: .timed, met: 6.0, [
            "Stand in a staggered stance, hands up.",
            "Throw jabs, crosses and hooks with light bounce.",
            "Keep moving."
        ]),
        ex("burpee", "Burpee", .cardio, .bodyweight, .intermediate, met: 8.0, [
            "Squat, place hands down and jump feet back to a plank.",
            "Do a push-up (optional), jump feet forward.",
            "Explode upward with a jump."
        ]),
        ex("mountain_climber", "Mountain Climber", .cardio, .bodyweight, .intermediate, kind: .timed, met: 8.0, [
            "Start in a high plank.",
            "Drive your knees toward your chest alternately, fast.",
            "Keep hips level."
        ]),
        ex("skater_hops", "Skater Hops", .cardio, .bodyweight, .intermediate, kind: .timed, met: 7.0, [
            "Leap sideways from one foot to the other.",
            "Land softly, sweeping the back leg behind you.",
            "Swing your arms for balance."
        ])
    ]

    // MARK: Full body

    private static let fullBody: [Exercise] = [
        ex("inchworm", "Inchworm", .fullBody, .bodyweight, .beginner, met: 4.0, [
            "Stand tall, then fold forward and place your hands on the floor.",
            "Walk your hands out to a plank.",
            "Walk your hands back and stand up."
        ]),
        ex("bear_crawl", "Bear Crawl", .fullBody, .bodyweight, .intermediate, kind: .timed, met: 6.0, [
            "On hands and toes with knees hovering just off the floor.",
            "Crawl forward using opposite hand and foot.",
            "Keep your back flat."
        ]),
        ex("db_thruster", "Dumbbell Thruster", .fullBody, .dumbbells, .intermediate, met: 7.0, load: 0.12, [
            "Hold dumbbells at your shoulders and squat deep.",
            "Drive up and press the weights overhead in one motion.",
            "Lower to your shoulders and repeat."
        ]),
        ex("man_maker", "Dumbbell Man Maker", .fullBody, .dumbbells, .advanced, met: 8.0, load: 0.1, [
            "From a plank on dumbbells, do a push-up and a row on each side.",
            "Jump your feet in, stand and press overhead.",
            "Lower and return to plank."
        ])
    ]

    // MARK: Mobility

    private static let mobility: [Exercise] = [
        ex("cat_cow", "Cat-Cow", .mobility, .bodyweight, .beginner, kind: .timed, met: 2.3, [
            "On hands and knees, arch your back and look up.",
            "Round your spine and tuck your chin.",
            "Flow with your breath."
        ]),
        ex("childs_pose", "Child's Pose", .mobility, .bodyweight, .beginner, kind: .timed, met: 2.0, [
            "Sit back on your heels with arms stretched forward.",
            "Rest your forehead down.",
            "Breathe deeply."
        ]),
        ex("hip_flexor_stretch", "Hip Flexor Stretch", .mobility, .bodyweight, .beginner, kind: .timed, met: 2.3, [
            "Kneel on one knee with the other foot forward.",
            "Tuck your pelvis and shift your weight forward.",
            "Hold, then switch sides."
        ]),
        ex("hamstring_stretch", "Hamstring Stretch", .mobility, .bodyweight, .beginner, kind: .timed, met: 2.3, [
            "Sit with one leg extended, the other bent.",
            "Hinge forward from your hips with a long spine.",
            "Hold, then switch sides."
        ]),
        ex("thoracic_rotation", "Thoracic Rotation", .mobility, .bodyweight, .beginner, kind: .timed, met: 2.5, [
            "On hands and knees, place one hand behind your head.",
            "Rotate your elbow toward the ceiling.",
            "Alternate sides."
        ]),
        ex("worlds_greatest", "World's Greatest Stretch", .mobility, .bodyweight, .beginner, kind: .timed, met: 3.0, [
            "Step into a deep lunge with both hands inside your front foot.",
            "Rotate your chest and reach one arm up.",
            "Switch sides."
        ]),
        ex("cobra_stretch", "Cobra Stretch", .mobility, .bodyweight, .beginner, kind: .timed, met: 2.3, [
            "Lie face down with hands under your shoulders.",
            "Press up, opening your chest while hips stay down.",
            "Hold and breathe."
        ]),
        ex("shoulder_circles", "Arm Circles", .mobility, .bodyweight, .beginner, kind: .timed, met: 2.5, [
            "Extend arms out to the sides.",
            "Make slow controlled circles, then reverse.",
            "Keep shoulders relaxed."
        ])
    ]
}
