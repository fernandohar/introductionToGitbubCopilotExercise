import Foundation

enum CardColor: String, Codable, CaseIterable, Hashable {
    case red
    case blue
    case green
    case yellow
    case wild

    var displayName: String {
        rawValue.capitalized
    }
}

enum CardValue: String, Codable, Hashable {
    case zero, one, two, three, four, five, six, seven, eight, nine
    case skip, reverse, drawTwo
    case wild, wildDrawFour

    var displayName: String {
        switch self {
        case .zero: return "0"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .skip: return "Skip"
        case .reverse: return "Reverse"
        case .drawTwo: return "+2"
        case .wild: return "Wild"
        case .wildDrawFour: return "+4"
        }
    }

    var isNumber: Bool {
        switch self {
        case .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine:
            return true
        default:
            return false
        }
    }
}

struct Card: Identifiable, Codable, Hashable {
    let id: UUID
    let color: CardColor
    let value: CardValue

    init(id: UUID = UUID(), color: CardColor, value: CardValue) {
        self.id = id
        self.color = color
        self.value = value
    }

    var isWild: Bool {
        value == .wild || value == .wildDrawFour
    }

    func matches(topCard: Card, activeColor: CardColor?) -> Bool {
        if isWild { return true }
        let effectiveColor = topCard.isWild ? (activeColor ?? topCard.color) : topCard.color
        return color == effectiveColor || value == topCard.value
    }
}
