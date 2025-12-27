import Carbon

/// Константы кодов клавиш для использования в приложении.
enum KeyCode: UInt32 {
    case escape = 53
    case returnKey = 36
    case tab = 48
    case space = 49
    case delete = 51
    
    case a = 0, s = 1, d = 2, f = 3, h = 4, g = 5
    case z = 6, x = 7, c = 8, v = 9, b = 11
    case q = 12, w = 13, e = 14, r = 15, y = 16, t = 17
    case o = 31, u = 32, i = 34, p = 35, l = 37
    case j = 38, k = 40, n = 45, m = 46
    
    case one = 18, two = 19, three = 20, four = 21, five = 23
    case six = 22, seven = 26, eight = 28, nine = 25, zero = 29
    
    case equals = 24, minus = 27, rightBracket = 30, leftBracket = 33
    case quote = 39, semicolon = 41, backslash = 42, comma = 43, slash = 44, period = 47
    
    init(_ rawValue: UInt32) {
        if let keyCode = KeyCode(rawValue: rawValue) {
            self = keyCode
        } else {
            self = .a
        }
    }
    
    var stringValue: String {
        switch self {
        case .escape: return "⎋"
        case .returnKey: return "↩"
        case .tab: return "⇥"
        case .space: return "␣"
        case .delete: return "⌫"
        case .a: return "A"
        case .s: return "S"
        case .d: return "D"
        case .f: return "F"
        case .h: return "H"
        case .g: return "G"
        case .z: return "Z"
        case .x: return "X"
        case .c: return "C"
        case .v: return "V"
        case .b: return "B"
        case .q: return "Q"
        case .w: return "W"
        case .e: return "E"
        case .r: return "R"
        case .y: return "Y"
        case .t: return "T"
        case .o: return "O"
        case .u: return "U"
        case .i: return "I"
        case .p: return "P"
        case .l: return "L"
        case .j: return "J"
        case .k: return "K"
        case .n: return "N"
        case .m: return "M"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .zero: return "0"
        case .equals: return "="
        case .minus: return "-"
        case .rightBracket: return "]"
        case .leftBracket: return "["
        case .quote: return "'"
        case .semicolon: return ";"
        case .backslash: return "\\"
        case .comma: return ","
        case .slash: return "/"
        case .period: return "."
        }
    }
}


