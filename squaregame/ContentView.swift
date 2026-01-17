import SwiftUI
import UIKit
import Combine

// MARK: - Game Modes
enum GameMode: String, CaseIterable, Identifiable, Codable {
    case easy, moderate, hard
    var id: String { rawValue }

    var gridSize: Int {
        switch self {
        case .easy: return 3
        case .moderate: return 5
        case .hard: return 7
        }
    }

    // Easy: 15s, Moderate: 25s, Hard: 35s
    var roundTime: Int {
        switch self {
        case .easy: return 15
        case .moderate: return 25
        case .hard: return 35
        }
    }

    var title: String { rawValue.capitalized }
    var subtitle: String {
        switch self {
        case .easy: return "3 × 3 Grid"
        case .moderate: return "5 × 5 Grid"
        case .hard: return "7 × 7 Grid"
        }
    }
}

// MARK: - Shape Mode
enum TileShape: String, CaseIterable, Codable, Hashable {
    case circle, diamond, triangle, star

    @ViewBuilder
    func view(color: Color) -> some View {
        switch self {
        case .circle:
            Circle().fill(color)
        case .diamond:
            DiamondShape().fill(color)
        case .triangle:
            TriangleShape().fill(color)
        case .star:
            StarShape(points: 5, innerRatio: 0.45).fill(color)
        }
    }
}

// MARK: - Leaderboard Model
struct ScoreEntry: Codable, Identifiable {
    let id: UUID
    let name: String
    let score: Int
    let mode: GameMode
    let date: Date

    init(name: String, score: Int, mode: GameMode, date: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.score = score
        self.mode = mode
        self.date = date
    }
}

final class LeaderboardStore: ObservableObject {
    @AppStorage("leaderboard_json") private var leaderboardJSON: String = "[]"
    @Published private(set) var entries: [ScoreEntry] = []

    init() { load() }

    func load() {
        guard let data = leaderboardJSON.data(using: .utf8) else { entries = []; return }
        do {
            entries = try JSONDecoder().decode([ScoreEntry].self, from: data)
        } catch {
            entries = []
        }
    }

    func saveEntry(_ entry: ScoreEntry) {
        entries.append(entry)
        entries.sort { $0.score > $1.score }
        if entries.count > 50 { entries = Array(entries.prefix(50)) }

        do {
            let data = try JSONEncoder().encode(entries)
            leaderboardJSON = String(data: data, encoding: .utf8) ?? "[]"
        } catch { }
    }

    func clear() {
        entries = []
        leaderboardJSON = "[]"
    }

    func top(for mode: GameMode? = nil) -> [ScoreEntry] {
        let filtered = mode == nil ? entries : entries.filter { $0.mode == mode! }
        return Array(filtered.sorted { $0.score > $1.score }.prefix(10))
    }
}

// MARK: - Root
struct ContentView: View {
    var body: some View {
        NavigationStack {
            MainMenuView()
        }
    }
}

// MARK: - Main Menu
struct MainMenuView: View {
    @EnvironmentObject private var leaderboard: LeaderboardStore

    @State private var selectedMode: GameMode? = nil
    @State private var pendingMode: GameMode? = nil
    @State private var showNameSheet: Bool = false

    @State private var playerName: String = ""
    @State private var shapeModeEnabled: Bool = false

    var body: some View {
        ZStack {
            galaxyBackground

            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    Text("🎨 ColorGame")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(radius: 4)

                    Text("Galaxy Match Challenge")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.black.opacity(0.25))
                        .cornerRadius(12)
                }
                .padding(.top, 10)

                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    Text("PLAY")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.horizontal, 6)

                    VStack(spacing: 12) {
                        ForEach(GameMode.allCases) { m in
                            Button {
                                pendingMode = m
                                showNameSheet = true
                            } label: {
                                MenuCard(
                                    title: "Play \(m.title)",
                                    subtitle: "\(m.subtitle) • \(m.roundTime)s",
                                    icon: "play.fill"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)

                VStack(spacing: 12) {
                    Toggle(isOn: $shapeModeEnabled) {
                        Text("Shape Mode (Color + Shape)")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .white.opacity(0.9)))
                    .padding(14)
                    .background(Color.black.opacity(0.22))
                    .cornerRadius(14)
                    .shadow(radius: 2)
                    .padding(.horizontal)

                    MenuLeaderboardPreview()
                        .padding(.horizontal)

                    HStack(spacing: 12) {
                        NavigationLink {
                            LeaderboardView()
                        } label: {
                            SmallMenuButton(title: "Leaderboard", icon: "trophy.fill")
                        }

                        NavigationLink {
                            HowToPlayView()
                        } label: {
                            SmallMenuButton(title: "How to Play", icon: "questionmark.circle.fill")
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()

                Text("Tip: Speed + streak bonuses give more points!")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.bottom, 10)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)

        .navigationDestination(item: $selectedMode) { mode in
            GameView(
                mode: mode,
                shapeModeEnabled: shapeModeEnabled,
                playerName: safeName(playerName)
            )
        }

        .sheet(isPresented: $showNameSheet) {
            NameEntrySheet(
                playerName: $playerName,
                selectedMode: pendingMode?.title ?? "",
                onStart: {
                    selectedMode = pendingMode
                    pendingMode = nil
                    showNameSheet = false
                },
                onCancel: {
                    pendingMode = nil
                    showNameSheet = false
                }
            )
            .presentationDetents([.medium])
        }
    }

    private func safeName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Player" : trimmed
    }

    private var galaxyBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(#colorLiteral(red: 0.1, green: 0.15, blue: 0.25, alpha: 1)),
                    Color(#colorLiteral(red: 0.2, green: 0.3, blue: 0.45, alpha: 1))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GalaxyBackgroundView()
        }
    }
}

// MARK: - Menu mini leaderboard preview
struct MenuLeaderboardPreview: View {
    @EnvironmentObject private var leaderboard: LeaderboardStore

    var body: some View {
        let topAll = leaderboard.top(for: nil)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Top Scores")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "trophy.fill")
                    .foregroundColor(.white.opacity(0.85))
            }

            if topAll.isEmpty {
                Text("No scores yet. Play a game and save your score!")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(topAll.prefix(3).enumerated()), id: \.element.id) { idx, item in
                        HStack {
                            Text("#\(idx + 1)")
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 34, alignment: .leading)

                            Text(item.name)
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()

                            Text("\(item.score)")
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text(item.mode.title)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.75))
                                .padding(.leading, 6)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.22))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(radius: 2)
    }
}

// MARK: - UI Pieces
struct MenuCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.white.opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: icon).foregroundColor(.white.opacity(0.95))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).fontWeight(.semibold).foregroundColor(.white)
                Text(subtitle).font(.subheadline).foregroundColor(.white.opacity(0.82))
            }

            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.75))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(radius: 2)
    }
}

struct SmallMenuButton: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(.white)
            Text(title).foregroundColor(.white).fontWeight(.semibold)
            Spacer()
        }
        .padding(14)
        .background(Color.black.opacity(0.22))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Name Entry Sheet
struct NameEntrySheet: View {
    @Binding var playerName: String
    let selectedMode: String
    let onStart: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(#colorLiteral(red: 0.1, green: 0.15, blue: 0.25, alpha: 1)),
                    Color(#colorLiteral(red: 0.2, green: 0.3, blue: 0.45, alpha: 1))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Enter your name")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Mode: \(selectedMode)")
                    .foregroundColor(.white.opacity(0.85))

                TextField("Your name", text: $playerName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.top, 6)

                HStack(spacing: 12) {
                    Button("Cancel") { onCancel() }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.25))
                        .cornerRadius(12)
                        .foregroundColor(.white)

                    Button("Start") { onStart() }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.25))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                }
                .padding(.top, 6)

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - How To Play
struct HowToPlayView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(#colorLiteral(red: 0.1, green: 0.15, blue: 0.25, alpha: 1)),
                    Color(#colorLiteral(red: 0.2, green: 0.3, blue: 0.45, alpha: 1))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            GalaxyBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("How to Play")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top, 10)

                    tipCard("Goal", "Tap the tile that matches the target.")
                    tipCard("Timer", "If time ends, the round restarts (score stays).")
                    tipCard("Bonuses", "⚡️ Speed: +2 (≤5s), +3 (≤2s)\n🔥 Streak: +2 at 3, +5 at 5 correct in a row")
                    tipCard("Shape Mode", "If enabled, match BOTH the color and the shape.")
                    tipCard("Leaderboard", "Tap “Save to Leaderboard” in-game to keep your best scores.")

                    Spacer(minLength: 18)
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tipCard(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundColor(.white)
            Text(body).font(.subheadline).foregroundColor(.white.opacity(0.85))
        }
        .padding(14)
        .background(Color.black.opacity(0.22))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Leaderboard Screen
struct LeaderboardView: View {
    @EnvironmentObject private var leaderboard: LeaderboardStore
    @State private var filter: GameMode? = nil

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(#colorLiteral(red: 0.1, green: 0.15, blue: 0.25, alpha: 1)),
                    Color(#colorLiteral(red: 0.2, green: 0.3, blue: 0.45, alpha: 1))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GalaxyBackgroundView()

            VStack(spacing: 14) {
                Text("🏆 Leaderboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(radius: 3)

                HStack(spacing: 10) {
                    filterPill("All", active: filter == nil) { filter = nil }
                    ForEach(GameMode.allCases) { m in
                        filterPill(m.title, active: filter == m) { filter = m }
                    }
                }

                let rows = leaderboard.top(for: filter)
                if rows.isEmpty {
                    Text("No scores yet.\nPlay and save your score.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.top, 18)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, item in
                                HStack {
                                    Text("#\(idx + 1)")
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.85))
                                        .frame(width: 42, alignment: .leading)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text(item.mode.title)
                                            .font(.footnote)
                                            .foregroundColor(.white.opacity(0.75))
                                    }

                                    Spacer()

                                    Text("\(item.score)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                .padding(14)
                                .background(Color.black.opacity(0.22))
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.top, 6)
                    }
                }

                Button(role: .destructive) { leaderboard.clear() } label: {
                    Text("Clear Leaderboard")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Color.black.opacity(0.22))
                        .cornerRadius(12)
                }
                .padding(.top, 6)

                Spacer()
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func filterPill(_ text: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.footnote)
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.black.opacity(active ? 0.45 : 0.22))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(active ? 0.25 : 0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Game Screen
struct GameView: View {
    let mode: GameMode
    let shapeModeEnabled: Bool
    let playerName: String

    @EnvironmentObject private var leaderboard: LeaderboardStore

    struct Tile: Identifiable {
        let id = UUID()
        let color: Color
        let shape: TileShape
    }

    @State private var targetColor: Color = .red
    @State private var targetShape: TileShape = .circle
    @State private var tiles: [Tile] = []

    @State private var score = 0
    @State private var round = 1
    private let maxRounds = 100

    @State private var showConfetti = false
    @State private var showWrongFeedback = false

    @State private var roundEndTime: Date = Date()
    @State private var timeLeft: Int = 0
    private let ticker = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    @State private var streak: Int = 0
    @State private var toastText: String? = nil

    private var progress: Double {
        guard mode.roundTime > 0 else { return 0 }
        return max(0, min(1, Double(timeLeft) / Double(mode.roundTime)))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(#colorLiteral(red: 0.1, green: 0.15, blue: 0.25, alpha: 1)),
                    Color(#colorLiteral(red: 0.2, green: 0.3, blue: 0.45, alpha: 1))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GalaxyBackgroundView()

            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    Text("🎨 ColorGame")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(radius: 3)

                    Text("Player: \(playerName)")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))

                    HStack(spacing: 12) {
                        pill("S: \(score)")
                        pill("R: \(round)/\(maxRounds)")
                        pill("⏳ \(timeLeft)s")
                    }

                    TimerProgressBar(progress: progress)
                        .frame(height: 10)

                    Text("\(mode.title) • \(mode.subtitle)")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.black.opacity(0.25))
                        .cornerRadius(10)

                    if streak >= 2 {
                        Text("🔥 Streak: \(streak)")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.black.opacity(0.25))
                            .cornerRadius(10)
                    }
                }

                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.black.opacity(0.20))
                            .frame(width: 120, height: 120)

                        if shapeModeEnabled {
                            targetShape.view(color: targetColor)
                                .frame(width: 72, height: 72)
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(targetColor)
                                .frame(width: 90, height: 90)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.22), lineWidth: 2)
                    )
                    .shadow(radius: 5)

                    Text(shapeModeEnabled ? "Match color + shape" : "Match this color")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding(.vertical, 6)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible()), count: mode.gridSize),
                    spacing: 12
                ) {
                    ForEach(tiles) { tile in
                        TileView(
                            tile: tile,
                            shapeModeEnabled: shapeModeEnabled,
                            isWrong: showWrongFeedback && !isCorrect(tile)
                        ) {
                            tileTapped(tile)
                        }
                    }
                }

                Button {
                    leaderboard.saveEntry(ScoreEntry(name: playerName, score: score, mode: mode))
                    showToast("Saved ✅")
                } label: {
                    Text("Save to Leaderboard")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.22))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                }
                .padding(.top, 6)

                Spacer()
            }
            .padding()

            if showConfetti { ConfettiView().transition(.opacity) }

            if let toastText {
                VStack {
                    Spacer()
                    Text(toastText)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(Color.black.opacity(0.55))
                        .cornerRadius(14)
                        .shadow(radius: 3)
                        .padding(.bottom, 24)
                }
                .transition(.opacity)
            }
        }
        .onAppear { startRound(resetTimer: true) }
        .onReceive(ticker) { _ in
            let remaining = Int(ceil(roundEndTime.timeIntervalSinceNow))
            timeLeft = max(0, remaining)

            if timeLeft == 0 {
                streak = 0
                showToast("Time’s up! Restarting…")
                triggerHaptic(success: false)
                startRound(resetTimer: true)
            }
        }
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Color.black.opacity(0.4))
            .cornerRadius(12)
            .shadow(radius: 2)
    }

    private func startRound(resetTimer: Bool) {
        showWrongFeedback = false

        if resetTimer {
            roundEndTime = Date().addingTimeInterval(Double(mode.roundTime))
            timeLeft = mode.roundTime
        }

        let gridCount = mode.gridSize * mode.gridSize

        var palette = generateDistinctColors(count: max(gridCount + 10, 90))
        palette.shuffle()

        targetColor = palette.removeFirst()
        targetShape = TileShape.allCases.randomElement() ?? .circle

        let correctIndex = Int.random(in: 0..<gridCount)
        var newTiles: [Tile] = []
        newTiles.reserveCapacity(gridCount)

        for i in 0..<gridCount {
            let color = (i == correctIndex) ? targetColor : (palette.isEmpty ? .blue : palette.removeFirst())

            let shape: TileShape
            if shapeModeEnabled {
                if i == correctIndex {
                    shape = targetShape
                } else {
                    var s = TileShape.allCases.randomElement() ?? .circle
                    if color == targetColor && s == targetShape {
                        s = TileShape.allCases.filter { $0 != targetShape }.randomElement() ?? .diamond
                    }
                    shape = s
                }
            } else {
                shape = .circle
            }

            newTiles.append(Tile(color: color, shape: shape))
        }

        tiles = newTiles
    }

    private func generateDistinctColors(count: Int) -> [Color] {
        guard count > 0 else { return [] }
        var colors: [Color] = []
        colors.reserveCapacity(count)
        for i in 0..<count {
            let hue = Double(i) / Double(count)
            let saturation = Double.random(in: 0.70...0.95)
            let brightness = Double.random(in: 0.75...0.95)
            colors.append(Color(hue: hue, saturation: saturation, brightness: brightness))
        }
        return colors
    }

    private func isCorrect(_ tile: Tile) -> Bool {
        if shapeModeEnabled {
            return tile.color == targetColor && tile.shape == targetShape
        } else {
            return tile.color == targetColor
        }
    }

    private func tileTapped(_ tile: Tile) {
        if isCorrect(tile) {
            var gained = 1

            let elapsed = mode.roundTime - timeLeft
            if elapsed <= 2 { gained += 3; showToast("⚡️ Speed Bonus +3") }
            else if elapsed <= 5 { gained += 2; showToast("⚡️ Speed Bonus +2") }

            streak += 1
            if streak == 3 { gained += 2; showToast("🔥 Streak Bonus +2") }
            else if streak == 5 { gained += 5; showToast("🔥 Streak Bonus +5") }

            score += gained

            showConfetti = true
            triggerHaptic(success: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showConfetti = false }

            round += 1
            if round > maxRounds {
                round = 1
                score = 0
                streak = 0
                showToast("New run started!")
            }

            withAnimation(.easeInOut(duration: 0.25)) {
                startRound(resetTimer: true)
            }
        } else {
            showWrongFeedback = true
            streak = 0
            triggerHaptic(success: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showWrongFeedback = false }
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.easeInOut(duration: 0.2)) { toastText = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeInOut(duration: 0.2)) {
                if toastText == text { toastText = nil }
            }
        }
    }

    private func triggerHaptic(success: Bool) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(success ? .success : .error)
    }
}

// MARK: - Tile View
struct TileView: View {
    let tile: GameView.Tile
    let shapeModeEnabled: Bool
    let isWrong: Bool
    let action: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(tile.color)
                .shadow(radius: 4)

            if shapeModeEnabled {
                tile.shape.view(color: Color.white.opacity(0.85))
                    .frame(width: 26, height: 26)
                    .blendMode(.overlay)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isWrong ? Color.red : Color.clear, lineWidth: 3)
        )
        .scaleEffect(isWrong ? 1.07 : 1.0)
        .animation(.easeInOut(duration: 0.18), value: isWrong)
        .onTapGesture { action() }
    }
}

// MARK: - Progress Bar View
struct TimerProgressBar: View {
    let progress: Double // 0..1
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.35))
                Capsule()
                    .fill(Color.white.opacity(0.75))
                    .frame(width: max(0, geo.size.width * progress))
                    .animation(.linear(duration: 0.15), value: progress)
                Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
            }
        }
        .frame(height: 10)
        .cornerRadius(999)
    }
}

// MARK: - Galaxy Background
struct GalaxyBackgroundView: View {
    @State private var animateStars = false
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<100, id: \.self) { _ in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.1...0.6)))
                        .frame(width: CGFloat.random(in: 2...6), height: CGFloat.random(in: 2...6))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: animateStars ? CGFloat.random(in: 0...geo.size.height) : CGFloat.random(in: 0...geo.size.height)
                        )
                        .animation(
                            Animation.linear(duration: Double.random(in: 3...6))
                                .repeatForever(autoreverses: true),
                            value: animateStars
                        )
                }
            }
        }
        .onAppear { animateStars = true }
    }
}

// MARK: - Confetti
struct ConfettiView: View {
    @State private var animate = false
    var body: some View {
        ZStack {
            ForEach(0..<30, id: \.self) { _ in
                Rectangle()
                    .fill([Color.blue, Color.white, Color.purple, Color.cyan].randomElement()!)
                    .frame(width: 6, height: 12)
                    .rotationEffect(.degrees(Double.random(in: 0...360)))
                    .offset(x: CGFloat.random(in: -150...150), y: animate ? 600 : -300)
                    .animation(
                        Animation.linear(duration: Double.random(in: 1.0...1.5))
                            .repeatForever(autoreverses: false),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

// MARK: - Custom Shapes
struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

struct StarShape: Shape {
    let points: Int
    let innerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerR = min(rect.width, rect.height) / 2
        let innerR = outerR * innerRatio

        var path = Path()
        let angleStep = .pi * 2 / CGFloat(points * 2)
        var angle: CGFloat = -.pi / 2

        var firstPoint = true
        for i in 0..<(points * 2) {
            let r = (i % 2 == 0) ? outerR : innerR
            let pt = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            if firstPoint { path.move(to: pt); firstPoint = false }
            else { path.addLine(to: pt) }
            angle += angleStep
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Previews (✅ FIX: provide env object)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(LeaderboardStore())
    }
}
