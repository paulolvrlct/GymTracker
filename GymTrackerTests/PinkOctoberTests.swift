import XCTest
@testable import GymTracker

/// Octobre Rose : le bandeau et le thème rose offert ne valent que pour octobre.
final class PinkOctoberTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testActiveFromFirstToLastDayOfOctober() {
        XCTAssertTrue(PinkOctober.isActive(on: date(2026, 10, 1, hour: 0), calendar: calendar))
        XCTAssertTrue(PinkOctober.isActive(on: date(2026, 10, 31, hour: 23), calendar: calendar))
        XCTAssertFalse(PinkOctober.isActive(on: date(2026, 9, 30, hour: 23), calendar: calendar))
        XCTAssertFalse(PinkOctober.isActive(on: date(2026, 11, 1, hour: 0), calendar: calendar))
    }

    func testPinkThemeIsFreeOnlyInOctober() {
        XCTAssertTrue(AccentTheme.pink.isUnlocked(isPremium: false, on: date(2026, 10, 15)))
        XCTAssertFalse(AccentTheme.pink.isUnlocked(isPremium: false, on: date(2026, 11, 15)))
        // les autres couleurs restent Premium, même en octobre
        XCTAssertFalse(AccentTheme.purple.isUnlocked(isPremium: false, on: date(2026, 10, 15)))
        XCTAssertTrue(AccentTheme.purple.isUnlocked(isPremium: true, on: date(2026, 3, 1)))
    }

    func testDismissedBannerComesBackTheNextYear() {
        XCTAssertNotEqual(PinkOctober.dismissedKey(on: date(2026, 10, 5), calendar: calendar),
                          PinkOctober.dismissedKey(on: date(2027, 10, 5), calendar: calendar))
    }

    /// L'icône principale se demande à iOS avec nil ; l'autre, par le nom de son
    /// jeu d'icônes, qui doit être listé en icône alternative dans le projet.
    func testOnlyTheNonPrimaryIconIsRequestedByName() {
        XCTAssertNil(AppIconChoice.primary.iconName)
        let others = AppIconChoice.allCases.filter { $0 != AppIconChoice.primary }
        XCTAssertEqual(others.count, 1)
        XCTAssertEqual(others.first?.iconName, others.first?.assetName)
        XCTAssertNotEqual(others.first?.assetName, AppIconChoice.primary.assetName)
    }
}
