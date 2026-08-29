import XCTest
@testable import KoyomiCoreTests

fileprivate extension ContentLibraryTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static nonisolated(unsafe) let __allTests__ContentLibraryTests = [
        ("testActionsAreShortAndConcrete", testActionsAreShortAndConcrete),
        ("testCategoryTextPoolsAreLargeEnough", testCategoryTextPoolsAreLargeEnough),
        ("testContentIsJapaneseOnly", testContentIsJapaneseOnly),
        ("testEverySeasonHasFallbackHints", testEverySeasonHasFallbackHints),
        ("testEveryWeatherCategoryHasAtLeastTenHints", testEveryWeatherCategoryHasAtLeastTenHints),
        ("testEveryZodiacHasAtLeastTwentyThemes", testEveryZodiacHasAtLeastTwentyThemes),
        ("testEveryZodiacHasFlavors", testEveryZodiacHasFlavors),
        ("testLuckyColorsUseValidHexAndUniqueNames", testLuckyColorsUseValidHexAndUniqueNames),
        ("testNoForbiddenExpressions", testNoForbiddenExpressions),
        ("testTextsEndWithJapanesePunctuation", testTextsEndWithJapanesePunctuation)
    ]
}

fileprivate extension FortuneGeneratorTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static nonisolated(unsafe) let __allTests__FortuneGeneratorTests = [
        ("testAccessibilityScoreText", testAccessibilityScoreText),
        ("testContentVersionChangesResult", testContentVersionChangesResult),
        ("testDifferentZodiacsGetDifferentThemesOnTheSameDay", testDifferentZodiacsGetDifferentThemesOnTheSameDay),
        ("testDisclaimerIsAlwaysPresent", testDisclaimerIsAlwaysPresent),
        ("testFallbackWithoutWeatherDoesNotMentionWeather", testFallbackWithoutWeatherDoesNotMentionWeather),
        ("testJSONShapeMatchesSpecification", testJSONShapeMatchesSpecification),
        ("testLuckyTimeIsWithinWakingHours", testLuckyTimeIsWithinWakingHours),
        ("testMoonPhaseIsOnlyMentionedWhenProvided", testMoonPhaseIsOnlyMentionedWhenProvided),
        ("testNoRepeatAcrossMonthBoundary", testNoRepeatAcrossMonthBoundary),
        ("testNoRepeatWithinSevenDaysForEveryZodiacAndWeather", testNoRepeatWithinSevenDaysForEveryZodiacAndWeather),
        ("testOverallLengthIsReadable", testOverallLengthIsReadable),
        ("testResultIsStableEvenIfWeatherIsCapturedAtADifferentTime", testResultIsStableEvenIfWeatherIsCapturedAtADifferentTime),
        ("testSameInputProducesIdenticalFortune", testSameInputProducesIdenticalFortune),
        ("testScoresAreWithinRangeAndNeverPunishing", testScoresAreWithinRangeAndNeverPunishing),
        ("testWeatherCategoryChangesSkySign", testWeatherCategoryChangesSkySign)
    ]
}

fileprivate extension KoyomiCalendarTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static nonisolated(unsafe) let __allTests__KoyomiCalendarTests = [
        ("testDayKeyDiffersAcrossTimeZonesAtMidnight", testDayKeyDiffersAcrossTimeZonesAtMidnight),
        ("testDayKeyUsesLocalDate", testDayKeyUsesLocalDate),
        ("testDayNumberAcrossLeapDay", testDayNumberAcrossLeapDay),
        ("testDayNumberIncrementsByOnePerLocalDay", testDayNumberIncrementsByOnePerLocalDay),
        ("testDayNumberIsStableWithinTheSameDay", testDayNumberIsStableWithinTheSameDay),
        ("testDisplayDateIsJapanese", testDisplayDateIsJapanese),
        ("testSeasonMapping", testSeasonMapping)
    ]
}

fileprivate extension ShareCardContentTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static nonisolated(unsafe) let __allTests__ShareCardContentTests = [
        ("testSelectableCitiesCoverRequiredList", testSelectableCitiesCoverRequiredList),
        ("testShareCardContainsNoPersonalInformation", testShareCardContainsNoPersonalInformation),
        ("testShortMessageIsASingleSentence", testShortMessageIsASingleSentence),
        ("testStableSeedIsDeterministicAcrossInstances", testStableSeedIsDeterministicAcrossInstances),
        ("testWeatherSnapshotFormatting", testWeatherSnapshotFormatting)
    ]
}

fileprivate extension ZodiacTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static nonisolated(unsafe) let __allTests__ZodiacTests = [
        ("testEveryDayOfTheYearMapsToAZodiac", testEveryDayOfTheYearMapsToAZodiac),
        ("testLeapDayIsPisces", testLeapDayIsPisces),
        ("testOrdinalsAreUnique", testOrdinalsAreUnique),
        ("testZodiacBoundaryDays", testZodiacBoundaryDays)
    ]
}
@available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
func __KoyomiCoreTests__allTests() -> [XCTestCaseEntry] {
    return [
        testCase(ContentLibraryTests.__allTests__ContentLibraryTests),
        testCase(FortuneGeneratorTests.__allTests__FortuneGeneratorTests),
        testCase(KoyomiCalendarTests.__allTests__KoyomiCalendarTests),
        testCase(ShareCardContentTests.__allTests__ShareCardContentTests),
        testCase(ZodiacTests.__allTests__ZodiacTests)
    ]
}