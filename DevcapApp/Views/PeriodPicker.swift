import SwiftUI

/// Full-width segmented control. The native one sizes itself to its labels and
/// cannot be stretched to the popover width.
struct PeriodPicker: View {
    @Binding var selection: String
    private let options = [("today", "Today"), ("yesterday", "Yesterday"), ("week", "Week"), ("7d", "7 Days")]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { value, title in
                let isSelected = selection == value
                Button {
                    selection = value
                } label: {
                    Text(title)
                        .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(nsColor: .windowBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(Color.primary.opacity(0.1))
                                    )
                                    .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Period")
    }
}
