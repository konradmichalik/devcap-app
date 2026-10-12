import SwiftUI

/// Commits per day for the selected period. The latest day is highlighted.
struct ActivitySparkline: View {
    let activity: [DayActivity]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let maxHeight: CGFloat = 24

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            bars
            Text("commits per day")
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Commits per day")
        .accessibilityValue(activity.map { String($0.count) }.joined(separator: ", "))
    }

    private var bars: some View {
        let peak = max(activity.map(\.count).max() ?? 0, 1)

        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(activity.enumerated()), id: \.element.day) { index, entry in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(index == activity.count - 1 ? Color.brandMint : Color.secondary.opacity(0.7))
                    .frame(width: 7, height: max(3, maxHeight * CGFloat(entry.count) / CGFloat(peak)))
                    .help("\(weekday(entry.day)): \(ActivityMetrics.pluralized(entry.count, "commit"))")
            }
        }
        .frame(height: maxHeight, alignment: .bottom)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: activity)
    }

    private func weekday(_ day: Date) -> String {
        day.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "en_US")))
    }
}
