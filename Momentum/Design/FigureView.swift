import SwiftUI

// MARK: - Motion data

struct MotionProp: Decodable {
    let t: String
    let p: [Double]
}

/// A looping exercise animation: keyframed skeleton poses plus static props.
///
/// Each frame has 14 numbers:
/// `[hipX, hipY, torso, head, nearUpperArm, nearForearm, farUpperArm, farForearm,
///   nearThigh, nearShin, nearFoot, farThigh, farShin, farFoot]`.
/// World space is y-up with the floor at y = 0. Angles are degrees from "straight down":
/// 0 = down, 90 = toward +x, 180 = up.
struct Motion: Decodable {
    let view: String
    let dur: Double
    let held: String?
    let bounds: [Double]
    let props: [MotionProp]
    let frames: [[Double]]

    var isFront: Bool { view == "front" }

    /// A representative pose for static thumbnails: the "working" position.
    var restingPose: [Double] {
        guard !frames.isEmpty else { return [] }
        return frames[min(1, frames.count - 1)]
    }

    /// Smoothly interpolated pose at `time` seconds. Each keyframe lasts `dur` seconds.
    func pose(at time: TimeInterval) -> [Double] {
        let count = frames.count
        guard count > 1 else { return frames.first ?? [] }
        let position = max(0, time) / max(dur, 0.1)
        let index = Int(position.rounded(.down))
        let t = position - Double(index)
        let eased = t * t * (3 - 2 * t)
        return Motion.blend(frames[index % count], frames[(index + 1) % count], eased)
    }

    static func blend(_ a: [Double], _ b: [Double], _ t: Double) -> [Double] {
        var result = a
        for k in 0..<min(a.count, b.count) {
            if k < 2 {
                result[k] = a[k] + (b[k] - a[k]) * t
            } else {
                // Take the short way around the circle.
                var delta = (b[k] - a[k]).truncatingRemainder(dividingBy: 360)
                if delta > 180 { delta -= 360 } else if delta < -180 { delta += 360 }
                result[k] = a[k] + delta * t
            }
        }
        return result
    }
}

enum MotionLibrary {
    static let all: [String: Motion] = {
        guard let data = MotionData.json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: Motion].self, from: data) else { return [:] }
        return decoded
    }()

    static func motion(for exerciseID: String) -> Motion? { all[exerciseID] }
}

// MARK: - Skeleton

struct Pt {
    var x: Double
    var y: Double
}

enum Body {
    static let torso = 0.50
    static let neck = 0.16
    static let upperArm = 0.29
    static let foreArm = 0.27
    static let thigh = 0.44
    static let shin = 0.43
    static let foot = 0.14
    static let headRadius = 0.10
    static let shoulderHalf = 0.17
    static let hipHalf = 0.10
}

struct Joints {
    var hip: Pt, neck: Pt, head: Pt
    var shoulderNear: Pt, shoulderFar: Pt, hipNear: Pt, hipFar: Pt
    var elbowNear: Pt, wristNear: Pt, elbowFar: Pt, wristFar: Pt
    var kneeNear: Pt, ankleNear: Pt, toeNear: Pt
    var kneeFar: Pt, ankleFar: Pt, toeFar: Pt
}

enum Skeleton {
    static func advance(_ p: Pt, _ degrees: Double, _ length: Double) -> Pt {
        let r = degrees * .pi / 180
        return Pt(x: p.x + sin(r) * length, y: p.y - cos(r) * length)
    }

    static func joints(_ f: [Double], front: Bool) -> Joints {
        let hip = Pt(x: f[0], y: f[1])
        let neck = advance(hip, f[2], Body.torso)
        let head = advance(neck, f[3], Body.neck)

        let shoulderNear: Pt, shoulderFar: Pt, hipNear: Pt, hipFar: Pt
        if front {
            shoulderNear = Pt(x: neck.x + Body.shoulderHalf, y: neck.y)
            shoulderFar = Pt(x: neck.x - Body.shoulderHalf, y: neck.y)
            hipNear = Pt(x: hip.x + Body.hipHalf, y: hip.y)
            hipFar = Pt(x: hip.x - Body.hipHalf, y: hip.y)
        } else {
            shoulderNear = neck
            shoulderFar = neck
            hipNear = hip
            hipFar = hip
        }

        let elbowNear = advance(shoulderNear, f[4], Body.upperArm)
        let wristNear = advance(elbowNear, f[5], Body.foreArm)
        let elbowFar = advance(shoulderFar, f[6], Body.upperArm)
        let wristFar = advance(elbowFar, f[7], Body.foreArm)
        let kneeNear = advance(hipNear, f[8], Body.thigh)
        let ankleNear = advance(kneeNear, f[9], Body.shin)
        let toeNear = advance(ankleNear, f[10], Body.foot)
        let kneeFar = advance(hipFar, f[11], Body.thigh)
        let ankleFar = advance(kneeFar, f[12], Body.shin)
        let toeFar = advance(ankleFar, f[13], Body.foot)

        return Joints(
            hip: hip, neck: neck, head: head,
            shoulderNear: shoulderNear, shoulderFar: shoulderFar, hipNear: hipNear, hipFar: hipFar,
            elbowNear: elbowNear, wristNear: wristNear, elbowFar: elbowFar, wristFar: wristFar,
            kneeNear: kneeNear, ankleNear: ankleNear, toeNear: toeNear,
            kneeFar: kneeFar, ankleFar: ankleFar, toeFar: toeFar
        )
    }
}

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
