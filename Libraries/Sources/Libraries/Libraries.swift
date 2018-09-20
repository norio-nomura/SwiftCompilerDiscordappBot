#if swift(>=4.2)
    #if canImport(RxSwift)
        import RxSwift
    #endif
    #if canImport(SwiftBacktrace)
        import SwiftBacktrace
    #endif
    #if canImport(SwiftyMath)
        import SwiftyMath
    #endif
    #if canImport(Vapor)
        import Vapor
    #endif
#else
    import RxSwift
    import SwiftBacktrace
    import Vapor
#endif

struct Libraries {
    var text = "Hello, World!"
}
