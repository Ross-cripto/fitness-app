import Foundation

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
