import SwiftUI

/// First-launch walkthrough of what Alcove does. Also reachable from Settings.
struct IntroTourView: View {
    var finishTitle = "Get started"
    var onFinish: () -> Void

    @State private var index = 0
    private let pages = TourPage.all

    private var isLast: Bool { index == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: onFinish)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .opacity(isLast ? 0 : 1)
                    .disabled(isLast)
                    .accessibilityIdentifier("tour.skip")
            }
            .padding(.horizontal, 24)
            .frame(height: 44)

            TabView(selection: $index) {
                ForEach(pages.indices, id: \.self) { i in
                    TourPageView(page: pages[i], isActive: i == index)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            PageDots(count: pages.count, current: index, tint: pages[index].tint)
                .padding(.bottom, 24)

            Button {
                if isLast {
                    onFinish()
                } else {
                    withAnimation(.snappy) { index += 1 }
                }
            } label: {
                Text(isLast ? finishTitle : "Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(pages[index].tint)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .accessibilityIdentifier("tour.next")
        }
        .background {
            LinearGradient(
                colors: [pages[index].tint.opacity(0.16), Color(.systemBackground)],
                startPoint: .top, endPoint: .center
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: index)
        }
        .sensoryFeedback(.selection, trigger: index)
    }
}

struct TourPage {
    struct Chip {
        var symbol: String
        var text: String
        var tint: Color
        /// Position relative to the illustration's centre.
        var offset: CGSize
    }

    var symbol: String
    var tint: Color
    var title: String
    var message: String
    var chips: [Chip]
    var usesLogo = false

    static let all: [TourPage] = [
        TourPage(
            symbol: "house.fill", tint: .accentColor,
            title: "Welcome to Alcove",
            message: "Know what food is in your home, from the pantry to the garage, without writing a single list.",
            chips: [
                .init(symbol: "cabinet", text: "Pantry 12", tint: .accentColor, offset: .init(width: -95, height: -105)),
                .init(symbol: "snowflake", text: "Freezer 6", tint: .teal, offset: .init(width: 105, height: -40)),
                .init(symbol: "door.garage.closed", text: "Garage 4", tint: .brown, offset: .init(width: -70, height: 110)),
            ],
            usesLogo: true
        ),
        TourPage(
            symbol: "barcode.viewfinder", tint: .accentColor,
            title: "Scan in, scan out",
            message: "Scan the barcode when you put food away, and again when you finish it. Alcove keeps the count for you.",
            chips: [
                .init(symbol: "arrow.down.to.line", text: "+1 Atta", tint: .accentColor, offset: .init(width: 100, height: -95)),
                .init(symbol: "arrow.up.right", text: "−1 Toor Dal", tint: .orange, offset: .init(width: -95, height: 100)),
            ]
        ),
        TourPage(
            symbol: "square.grid.2x2.fill", tint: .teal,
            title: "Every spot in your home",
            message: "Pantry, fridge, freezer, garage: see exactly what's where, so nothing gets forgotten at the back of a shelf.",
            chips: [
                .init(symbol: "refrigerator", text: "Fridge", tint: .teal, offset: .init(width: -100, height: -90)),
                .init(symbol: "snowflake", text: "Freezer", tint: .cyan, offset: .init(width: 100, height: -20)),
                .init(symbol: "cabinet", text: "Pantry", tint: .accentColor, offset: .init(width: -85, height: 105)),
            ]
        ),
        TourPage(
            symbol: "magnifyingglass", tint: .indigo,
            title: "Do I have this?",
            message: "Standing in the store? Search, or scan a barcode, to see what's already at home before you buy it again.",
            chips: [
                .init(symbol: "checkmark.circle.fill", text: "Rice: have 2", tint: .green, offset: .init(width: 95, height: -95)),
                .init(symbol: "cart.fill", text: "Ghee: buy", tint: .red, offset: .init(width: -90, height: 100)),
            ]
        ),
        TourPage(
            symbol: "receipt", tint: .orange,
            title: "Snap the receipt",
            message: "Back from a big shopping trip? Take a photo of the receipt instead of scanning every bag.",
            chips: [
                .init(symbol: "text.viewfinder", text: "7 items found", tint: .orange, offset: .init(width: 95, height: -90)),
                .init(symbol: "link", text: "Aash Atta → Atta", tint: .accentColor, offset: .init(width: -80, height: 105)),
            ]
        ),
        TourPage(
            symbol: "bell.badge.fill", tint: .red,
            title: "A heads-up before you run out",
            message: "Alcove tells you when you're down to the last bag, reminds you before food expires, and learns how fast your family uses things.",
            chips: [
                .init(symbol: "exclamationmark.circle.fill", text: "Last bag of dal", tint: .orange, offset: .init(width: -95, height: -100)),
                .init(symbol: "clock.fill", text: "Paneer: 1 day left", tint: .red, offset: .init(width: 105, height: 10)),
                .init(symbol: "arrow.clockwise", text: "Restock rice soon", tint: .accentColor, offset: .init(width: -60, height: 110)),
            ]
        ),
        TourPage(
            symbol: "person.3.fill", tint: .pink,
            title: "One home for the family",
            message: "Set up your home and its spaces now. Sharing it so everyone sees the same inventory is coming soon.",
            chips: [
                .init(symbol: "house.fill", text: "Your home", tint: .accentColor, offset: .init(width: -95, height: -95)),
                .init(symbol: "sparkles", text: "Sharing soon", tint: .pink, offset: .init(width: 90, height: 100)),
            ]
        ),
    ]
}

private struct TourPageView: View {
    let page: TourPage
    let isActive: Bool

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            illustration
                .frame(height: 300)
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(page.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            Spacer(minLength: 0)
        }
    }

    private var illustration: some View {
        ZStack {
            Circle()
                .fill(page.tint.opacity(0.10))
                .frame(width: 260, height: 260)
            Circle()
                .fill(page.tint.opacity(0.14))
                .frame(width: 190, height: 190)

            if page.usesLogo {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128, height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .shadow(color: page.tint.opacity(0.35), radius: 18, y: 8)
            } else {
                Image(systemName: page.symbol)
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 128, height: 128)
                    .background(page.tint.gradient, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .shadow(color: page.tint.opacity(0.35), radius: 18, y: 8)
                    .symbolEffect(.bounce, value: isActive)
            }

            ForEach(page.chips.indices, id: \.self) { i in
                let chip = page.chips[i]
                Label(chip.text, systemImage: chip.symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(chip.tint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.background, in: Capsule())
                    .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
                    .fixedSize()
                    .offset(chip.offset)
                    .scaleEffect(isActive ? 1 : 0.6)
                    .opacity(isActive ? 1 : 0)
                    .animation(.spring(duration: 0.5, bounce: 0.35).delay(0.08 * Double(i) + 0.1), value: isActive)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? tint : Color.secondary.opacity(0.3))
                    .frame(width: i == current ? 22 : 7, height: 7)
            }
        }
        .animation(.snappy, value: current)
        .accessibilityElement()
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}
