import SwiftUI
import UIKit

// MARK: - Game Modes
enum GameMode: String, CaseIterable {
    case easy, moderate, hard
    
    var gridSize: Int {
        switch self {
        case .easy: return 3
        case .moderate: return 5
        case .hard: return 7
        }
    }
}

// MARK: - Main ContentView
struct ContentView: View {
    @State private var mode: GameMode = .easy
    @State private var targetColor: Color = .red
    @State private var squares: [Color] = []
    @State private var score = 0
    @State private var round = 1
    let maxRounds = 100
    @State private var showConfetti = false
    @State private var showWrongFeedback = false
    
    var body: some View {
        ZStack {
            // MARK: - Full Galaxy Background
            LinearGradient(colors: [Color(#colorLiteral(red: 0.1, green: 0.15, blue: 0.25, alpha: 1)), Color(#colorLiteral(red: 0.2, green: 0.3, blue: 0.45, alpha: 1))],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            GalaxyBackgroundView() // moving stars
            
            VStack(spacing: 25) {
                
                // MARK: - Top Panel
                VStack(spacing: 15) { // More spacing between title and score
                    Text("🎨 ColorGame")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(radius: 3)
                    
                    HStack(spacing: 40) { // Separate S and R nicely
                        Text("S: \(score)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(12)
                            .shadow(radius: 2)
                        
                        Text("R: \(round)/\(maxRounds)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(12)
                            .shadow(radius: 2)
                    }
                }
                
                // Mode selection buttons
                HStack(spacing: 12) {
                    ForEach(GameMode.allCases, id: \.self) { m in
                        Button(action: {
                            mode = m
                            startRound()
                        }) {
                            Text(m.rawValue.capitalized) // Full word: Easy, Moderate, Hard
                                .fontWeight(.semibold)
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color.black.opacity(mode == m ? 0.25 : 0.15))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(radius: 2)
                        }
                    }
                }
                
                // Target Color Preview
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(targetColor)
                        .frame(width: 100, height: 100)
                        .shadow(radius: 5)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white, lineWidth: 3))
                        .transition(.scale)
                        .animation(.easeInOut(duration: 0.3), value: targetColor)
                    
                    Text("Match this color")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .shadow(radius: 1)
                }
                .padding(.vertical)
                
                // Grid of squares
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: mode.gridSize), spacing: 12) {
                    ForEach(squares.indices, id: \.self) { i in
                        SquareView(
                            color: squares[i],
                            wrongFeedback: showWrongFeedback && squares[i] != targetColor
                        ) {
                            squareTapped(index: i)
                        }
                    }
                }
                .padding()
                
                Spacer()
            }
            .padding()
            
            // Confetti Overlay
            if showConfetti {
                ConfettiView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            startRound()
        }
    }
    
    // MARK: - Game Logic
    func startRound() {
        showWrongFeedback = false
        let gridCount = mode.gridSize * mode.gridSize
        
        // Generate target color
        let r = Double.random(in: 0.3...0.85)
        let g = Double.random(in: 0.3...0.85)
        let b = Double.random(in: 0.3...0.85)
        targetColor = Color(red: r, green: g, blue: b)
        
        // Grid squares
        squares = (0..<gridCount).map { _ in
            Color(
                red: r + Double.random(in: -0.12...0.12),
                green: g + Double.random(in: -0.12...0.12),
                blue: b + Double.random(in: -0.12...0.12)
            )
        }
        
        // Place exact target color
        squares[Int.random(in: 0..<gridCount)] = targetColor
    }
    
    func squareTapped(index: Int) {
        if squares[index] == targetColor {
            score += 1
            showConfetti = true
            triggerHaptic(success: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showConfetti = false
            }
            
            round += 1
            if round > maxRounds {
                round = 1
                score = 0
            }
            
            withAnimation(.easeInOut(duration: 0.3)) {
                startRound()
            }
        } else {
            showWrongFeedback = true
            triggerHaptic(success: false)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showWrongFeedback = false
            }
        }
    }
    
    func triggerHaptic(success: Bool) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(success ? .success : .error)
    }
}

// MARK: - Square View
struct SquareView: View {
    var color: Color
    var wrongFeedback: Bool = false
    var action: () -> Void
    
    var body: some View {
        Rectangle()
            .fill(color)
            .aspectRatio(1, contentMode: .fit)
            .cornerRadius(12)
            .shadow(radius: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(wrongFeedback ? Color.red : Color.clear, lineWidth: 3)
            )
            .scaleEffect(wrongFeedback ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: wrongFeedback)
            .onTapGesture { action() }
    }
}

// MARK: - Confetti Animation
struct ConfettiView: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            ForEach(0..<30, id: \.self) { i in
                Rectangle()
                    .fill([Color.blue, Color.white, Color.purple, Color.cyan].randomElement()!)
                    .frame(width: 6, height: 12)
                    .rotationEffect(.degrees(Double.random(in: 0...360)))
                    .offset(x: CGFloat.random(in: -150...150), y: animate ? 600 : -300)
                    .animation(Animation.linear(duration: Double.random(in: 1.0...1.5)).repeatForever(autoreverses: false), value: animate)
            }
        }
        .onAppear { animate = true }
    }
}

// MARK: - Full Galaxy Background
struct GalaxyBackgroundView: View {
    @State private var animateStars = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<100, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.1...0.6)))
                        .frame(width: CGFloat.random(in: 2...6), height: CGFloat.random(in: 2...6))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: animateStars ? CGFloat.random(in: 0...geo.size.height) : CGFloat.random(in: 0...geo.size.height)
                        )
                        .animation(Animation.linear(duration: Double.random(in: 3...6)).repeatForever(autoreverses: true), value: animateStars)
                }
            }
        }
        .onAppear { animateStars = true }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
