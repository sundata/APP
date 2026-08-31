import XCTest
@testable import ShiftTechoCore

final class BackupCodecTests: XCTestCase {
    private func sampleDocument() -> BackupDocument {
        let templates = ShiftTemplate.defaults
        let night = templates[3]
        return BackupDocument(
            exportedAt: Date(timeIntervalSince1970: 1_772_323_200),
            payrollSettings: PayrollSettings(hourlyWageYen: 1_300, transportAllowancePerWorkdayYen: 500),
            reminderSettings: ReminderSettings(monthlyReminderEnabled: true),
            templates: templates,
            assignments: [
                ShiftAssignment(dayKey: "2026-03-01", templateID: night.id, definition: night.definition, note: "夜勤明けは通院"),
                ShiftAssignment(dayKey: "2026-03-02", templateID: templates[4].id, definition: templates[4].definition)
            ]
        )
    }

    func testRoundTrip() throws {
        let document = sampleDocument()
        let data = try BackupCodec.encode(document)
        let decoded = try BackupCodec.decode(data)
        XCTAssertEqual(decoded, document)
        XCTAssertEqual(decoded.schemaVersion, BackupDocument.currentSchemaVersion)
        XCTAssertEqual(decoded.assignments.first?.definition.billableMinutes, 480)
        XCTAssertEqual(decoded.payrollSettings.hourlyWageYen, 1_300)
    }

    func testUnsupportedSchemaVersionIsRejected() throws {
        var document = sampleDocument()
        document.schemaVersion = BackupDocument.currentSchemaVersion + 1
        let data = try BackupCodec.encode(document)
        XCTAssertThrowsError(try BackupCodec.decode(data)) { error in
            XCTAssertEqual(error as? BackupError, .unsupportedSchemaVersion(BackupDocument.currentSchemaVersion + 1))
        }
    }

    func testMalformedDataIsRejected() {
        XCTAssertThrowsError(try BackupCodec.decode(Data("シフトです".utf8))) { error in
            XCTAssertEqual(error as? BackupError, .malformed)
        }
    }

    func testInvalidDayKeyIsRejected() throws {
        var document = sampleDocument()
        document.assignments[0].dayKey = "2026-02-30"
        let data = try BackupCodec.encode(document)
        XCTAssertThrowsError(try BackupCodec.decode(data)) { error in
            XCTAssertEqual(error as? BackupError, .invalidContent)
        }
    }

    func testDuplicateDayIsCollapsedToOneAssignment() throws {
        var document = sampleDocument()
        let duplicated = document.assignments[0]
        document.assignments.append(
            ShiftAssignment(dayKey: duplicated.dayKey, templateID: nil, definition: document.templates[0].definition)
        )
        let data = try BackupCodec.encode(document)
        let decoded = try BackupCodec.decode(data)
        XCTAssertEqual(decoded.assignments.filter { $0.dayKey == duplicated.dayKey }.count, 1)
        XCTAssertEqual(decoded.assignments.first?.definition.name, "夜勤")
    }

    func testFileNameUsesJapaneseLocalDate() {
        let exportedAt = Date(timeIntervalSince1970: 1_772_323_200)
        XCTAssertEqual(BackupCodec.fileName(exportedAt: exportedAt), "shifttecho-backup-2026-03-01.json")
    }

    func testReminderSettingsClampValues() {
        let settings = ReminderSettings(monthlyReminderDay: 40, monthlyReminderMinuteOfDay: 5_000)
        XCTAssertEqual(settings.monthlyReminderDay, 28)
        XCTAssertEqual(settings.monthlyReminderMinuteOfDay, 1_439)
    }
}
