import SwiftUI
import SwiftData
import Foundation
import CoreLocation
import UserNotifications

// MARK: - Transaction row

struct ExpenseRow: View {
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    
    let expense: CentreExpense
    var animateArrival: Bool = false
    
    @State private var arrivalVisible = false
    @State private var showingArrivalHighlight = false
    
    private var needsDetails: Bool {
        expense.category == "Needs details"
    }
    
    private var waitingForEntrance: Bool {
        animateArrival && !arrivalVisible
    }
    
    var body: some View {
        rowContent
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        Color.blue.opacity(
                            showingArrivalHighlight ? 0.12 : 0
                        )
                    )
                    .padding(.horizontal, -6)
            }
            .opacity(waitingForEntrance ? 0 : 1)
            .scaleEffect(
                waitingForEntrance && !reduceMotion ? 0.96 : 1
            )
            .offset(
                y: waitingForEntrance && !reduceMotion ? -10 : 0
            )
            .task(id: animateArrival) {
                guard animateArrival else {
                    arrivalVisible = false
                    showingArrivalHighlight = false
                    return
                }
                
                arrivalVisible = false
                showingArrivalHighlight = true
                
                do {
                    try await Task.sleep(
                        for: .milliseconds(30)
                    )
                } catch {
                    return
                }
                
                let entranceAnimation: Animation =
                reduceMotion
                ? .easeOut(duration: 0.2)
                : .spring(
                    response: 0.4,
                    dampingFraction: 0.8
                )
                
                withAnimation(entranceAnimation) {
                    arrivalVisible = true
                }
                
                do {
                    try await Task.sleep(
                        for: .milliseconds(450)
                    )
                } catch {
                    return
                }
                
                withAnimation(.easeOut(duration: 0.35)) {
                    showingArrivalHighlight = false
                }
            }
    }
    
    private var rowContent: some View {
        HStack(alignment: .center, spacing: 12) {
            categoryIcon

            VStack(alignment: .leading, spacing: 5) {
                Text(expense.merchant)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Text("\(expense.category) · \(expense.paymentMethod)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(
                    expense.date,
                    format: .dateTime
                        .day()
                        .month(.abbreviated)
                        .year()
                        .hour()
                        .minute()
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(hkd(expense.amountInCents))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .fixedSize(
                    horizontal: true,
                    vertical: false
                )

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(
                    needsDetails
                        ? Color.blue
                        : Color.secondary.opacity(0.5)
                )
                .accessibilityHidden(true)
        }
    }
    
    private var categoryIcon: some View {
        Image(
            systemName: categorySymbol(expense.category)
        )
        .foregroundStyle(.indigo)
        .frame(width: 40, height: 40)
        .background(
            Color.indigo.opacity(0.1),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(alignment: .topLeading) {
            if needsDetails {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 14, height: 14)
                    .overlay {
                        Circle()
                            .stroke(
                                Color(.secondarySystemGroupedBackground),
                                lineWidth: 2
                            )
                    }
                    .offset(x: -5, y: -5)
            }
        }
        .accessibilityHidden(true)
    }
}
