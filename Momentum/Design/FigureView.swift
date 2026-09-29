import SwiftUI

// MARK: - Rendering

enum FigureRenderer {
    static func draw(
        _ motion: Motion,
        pose: [Double],
        in context: inout GraphicsContext,
        size: CGSize,
        figure: Color,
        accent: Color,
        showGround: Bool
    ) {
        guard motion.bounds.count == 4, pose.count >= 14, size.width > 0, size.height > 0 else { return }

        let x0 = motion.bounds[0], x1 = motion.bounds[1]
        let y0 = motion.bounds[2], y1 = motion.bounds[3]
        let scale = min(size.width / CGFloat(x1 - x0), size.height / CGFloat(y1 - y0))
        let originX = (size.width - CGFloat(x1 - x0) * scale) / 2 - CGFloat(x0) * scale
        let originY = (size.height + CGFloat(y1 - y0) * scale) / 2 + CGFloat(y0) * scale

        func point(_ p: Pt) -> CGPoint {
            CGPoint(x: originX + CGFloat(p.x) * scale, y: originY - CGFloat(p.y) * scale)
        }
        func stroke(_ points: [Pt], _ color: Color, _ width: CGFloat) {
            guard let first = points.first else { return }
            var path = Path()
            path.move(to: point(first))
            for p in points.dropFirst() { path.addLine(to: point(p)) }
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
            )
        }

        func plate(at p: Pt) {
            let c = point(p)
            let r = 0.105 * scale
            let outer = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: outer), with: .color(accent))
            let inner = outer.insetBy(dx: r * 0.62, dy: r * 0.62)
            context.fill(Path(ellipseIn: inner), with: .color(figure.opacity(0.9)))
        }

        let j = Skeleton.joints(pose, front: motion.isFront)
        let limb = max(2.5, 0.055 * scale)

        // Floor.
        if showGround {
            var floor = Path()
            floor.move(to: point(Pt(x: x0, y: 0)))
            floor.addLine(to: point(Pt(x: x1, y: 0)))
            context.stroke(floor, with: .color(figure.opacity(0.22)),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 5]))
        }

        // Props (benches, walls, bars, cables).
        for prop in motion.props {
            let p = prop.p
            switch prop.t {
            case "line" where p.count == 4:
                stroke([Pt(x: p[0], y: p[1]), Pt(x: p[2], y: p[3])], figure.opacity(0.35), limb * 0.7)
            case "rect" where p.count == 4:
                let origin = point(Pt(x: p[0], y: p[1] + p[3]))
                let rect = CGRect(x: origin.x, y: origin.y, width: CGFloat(p[2]) * scale, height: CGFloat(p[3]) * scale)
                context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(figure.opacity(0.2)))
            case "cable" where p.count == 2:
                stroke([Pt(x: p[0], y: p[1]), j.wristNear], figure.opacity(0.55), 1.5)
            default:
                break
            }
        }

        let farColor = figure.opacity(0.5)

        // Far limbs, torso, then near limbs so the near side reads in front.
        stroke([j.shoulderFar, j.elbowFar, j.wristFar], farColor, limb)
        stroke([j.hipFar, j.kneeFar, j.ankleFar, j.toeFar], farColor, limb)
        if motion.isFront {
            stroke([j.shoulderNear, j.shoulderFar], figure, limb)
            stroke([j.hipNear, j.hipFar], figure, limb)
        }
        stroke([j.hip, j.neck], figure, limb * 1.35)
        stroke([j.shoulderNear, j.elbowNear, j.wristNear], figure, limb)
        stroke([j.hipNear, j.kneeNear, j.ankleNear, j.toeNear], figure, limb)

        // Equipment in hand.
        switch motion.held {
        case "dumbbell":
            for (wrist, angle) in [(j.wristNear, pose[5]), (j.wristFar, pose[7])] {
                let r = angle * .pi / 180
                let half = 0.075
                let a = Pt(x: wrist.x - cos(r) * half, y: wrist.y - sin(r) * half)
                let b = Pt(x: wrist.x + cos(r) * half, y: wrist.y + sin(r) * half)
                stroke([a, b], accent, limb * 1.25)
            }
        case "barbell":
            plate(at: j.wristNear)
        case "barbell_back":
            plate(at: Pt(x: j.neck.x - 0.02, y: j.neck.y))
        default:
            break
        }

        // Head.
        let center = point(j.head)
        let radius = CGFloat(Body.headRadius) * scale
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
            with: .color(figure)
        )
    }
}

/// Animated stick-figure demonstration of an exercise. Runs entirely from bundled data.
struct FigureView: View {
    let exerciseID: String
    var figure: Color = .white
    var accent: Color = Theme.pink
    var animated = true
    var showGround = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let motion = MotionLibrary.motion(for: exerciseID) {
            if animated && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    canvas(motion, pose: motion.pose(at: timeline.date.timeIntervalSinceReferenceDate))
                }
            } else {
                canvas(motion, pose: motion.restingPose)
            }
        } else {
            Image(systemName: "figure.strengthtraining.traditional")
                .foregroundStyle(figure.opacity(0.6))
        }
    }

    private func canvas(_ motion: Motion, pose: [Double]) -> some View {
        Canvas { context, size in
            FigureRenderer.draw(
                motion, pose: pose, in: &context, size: size,
                figure: figure, accent: accent, showGround: showGround
            )
        }
        .accessibilityHidden(true)
    }
}

/// Figure on the exercise's themed gradient, used as a hero image.
struct FigureCard: View {
    let exercise: Exercise
    var animated = true

    var body: some View {
        ZStack {
            LinearGradient(colors: exercise.muscle.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            FigureView(exerciseID: exercise.id, animated: animated)
                .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(exercise.name) demonstration")
    }
}

/// Small thumbnail for lists.
struct FigureThumb: View {
    let exercise: Exercise
    var animated = false
    var cornerRadius: CGFloat = 8

    var body: some View {
        ZStack {
            LinearGradient(colors: exercise.muscle.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            FigureView(exerciseID: exercise.id, animated: animated, showGround: false)
                .padding(4)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
