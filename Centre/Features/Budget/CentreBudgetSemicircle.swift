import SwiftUI
import SwiftData
import Foundation
import CoreLocation
import UserNotifications

// MARK: - Budget semicircle

private struct CentreBudgetArc: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let amount = min(max(progress, 0), 1)
        let radius = min(rect.width / 2, rect.height)
        let centre = CGPoint(
            x: rect.midX,
            y: rect.maxY
        )

        var path = Path()

        path.addArc(
            center: centre,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(180 + 180 * amount),
            clockwise: false
        )

        return path
    }
}

struct CentreBudgetSemicircle: View {
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    let spentInCents: Int
    let budgetInCents: Int

    private var outline: Color {
        isOverBudget
            ? Color(
                red: 1.00,
                green: 0.54,
                blue: 0.64
            )
            : Color(
                red: 0.64,
                green: 0.87,
                blue: 0.38
            )
    }

    private var hasBudget: Bool {
        budgetInCents > 0
    }

    private var isOverBudget: Bool {
        hasBudget && spentInCents > budgetInCents
    }

    private var progress: Double {
        guard hasBudget else { return 0 }

        return min(
            max(
                Double(spentInCents)
                    / Double(budgetInCents),
                0
            ),
            1
        )
    }

    private var fillColor: Color {
        isOverBudget
            ? Color(
                red: 1.00,
                green: 0.18,
                blue: 0.34
            )
            : Color(
                red: 0.64,
                green: 0.94,
                blue: 0.05
            )
    }

    private var trackColor: Color {
        isOverBudget
            ? Color(
                red: 1.00,
                green: 0.91,
                blue: 0.93
            )
            : Color(
                red: 0.93,
                green: 0.98,
                blue: 0.85
            )
    }
    
    private var overspendColor: Color {
        Color(
            red: 0.70,
            green: 0.04,
            blue: 0.19
        )
    }

    private var budgetLimitPosition: Double {
        guard hasBudget else { return 0 }

        if isOverBudget {
            return Double(budgetInCents)
                / Double(spentInCents)
        }

        return progress
    }

    private var mainText: String {
        guard hasBudget else {
            return "Set budget"
        }

        return hkd(
            abs(budgetInCents - spentInCents)
        )
    }

    private var detailText: String {
        guard hasBudget else {
            return "Choose your monthly limit"
        }

        return isOverBudget
            ? "over budget"
            : "left this month"
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                GeometryReader { geometry in
                    let inset: CGFloat = 15
                    let arcWidth = max(
                        geometry.size.width - inset * 2,
                        0
                    )
                    let radius = arcWidth / 2
                    let angle = Double.pi
                        + budgetLimitPosition * Double.pi

                    let markerX = geometry.size.width / 2
                        + radius * CGFloat(cos(angle))

                    let markerY = inset + radius
                        + radius * CGFloat(sin(angle))

                    ZStack {
                        CentreBudgetArc(progress: 1)
                            .stroke(
                                outline,
                                style: StrokeStyle(
                                    lineWidth: 25,
                                    lineCap: .round
                                )
                            )

                        CentreBudgetArc(progress: 1)
                            .stroke(
                                trackColor,
                                style: StrokeStyle(
                                    lineWidth: 20,
                                    lineCap: .round
                                )
                            )

                        if progress > 0 {
                            CentreBudgetArc(
                                progress: progress
                            )
                            .stroke(
                                fillColor,
                                style: StrokeStyle(
                                    lineWidth: 20,
                                    lineCap: .round
                                )
                            )
                        }

                        if isOverBudget {
                            CentreBudgetArc(progress: 1)
                                .trim(
                                    from: CGFloat(budgetLimitPosition),
                                    to: 1
                                )
                                .stroke(
                                    overspendColor,
                                    style: StrokeStyle(
                                        lineWidth: 20,
                                        lineCap: .round
                                    )
                                )
                        }
                    } // Closes the ZStack containing the arcs
                    .frame(
                        width: arcWidth,
                        height: radius
                    )
                    .position(
                        x: geometry.size.width / 2,
                        y: inset + radius / 2
                    )

                    if hasBudget {
                        Circle()
                            .fill(
                                Color(
                                    .secondarySystemGroupedBackground
                                )
                            )
                            .overlay {
                                Circle()
                                    .stroke(
                                        outline,
                                        lineWidth: 3
                                    )
                            }
                            .frame(
                                width: 23,
                                height: 23
                            )
                            .position(
                                x: markerX,
                                y: markerY
                            )
                    }
                }

                VStack(spacing: 4) {
                    Text(mainText)
                        .font(
                            .system(
                                size: 27,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(
                            isOverBudget
                                ? Color.red
                                : Color.primary
                        )
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 3)
            }
            .frame(width: 260, height: 158)

            if hasBudget {
                Text(
                    "Monthly budget \(hkd(budgetInCents)) · Edit"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            } else {
                Text("Tap to set")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .animation(
            reduceMotion
                ? nil
                : .easeInOut(duration: 0.35),
            value: progress
        )
        .animation(
            reduceMotion
                ? nil
                : .easeInOut(duration: 0.35),
            value: budgetLimitPosition
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Monthly budget")
        .accessibilityValue(
            hasBudget
                ? "\(mainText) \(detailText). Limit \(hkd(budgetInCents))."
                : "Not set"
        )
    }
}
