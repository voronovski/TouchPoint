import Foundation
import SwiftUI

protocol StableStringCodable: RawRepresentable, Codable where RawValue == String {
    static var legacyRawValues: [String: Self] { get }
}

extension StableStringCodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let decoded = Self(rawValue: value) ?? Self.legacyRawValues[value] else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported \(Self.self) value: \(value)"
            )
        }
        self = decoded
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum Relationship: String, CaseIterable, Identifiable, StableStringCodable {
    case client
    case family
    case friend
    case colleague

    var id: Self { self }

    static let legacyRawValues: [String: Relationship] = [
        "Client": .client,
        "Family": .family,
        "Friend": .friend,
        "Colleague": .colleague
    ]

    var title: String {
        switch self {
        case .client: String(localized: "Client")
        case .family: String(localized: "Family")
        case .friend: String(localized: "Friend")
        case .colleague: String(localized: "Colleague")
        }
    }
}

enum OccasionCategory: String, CaseIterable, Identifiable {
    case personal
    case usHolidays = "us_holidays"
    case observances
    case latinAmerican = "latin_american"
    case frenchHolidays = "french_holidays"
    case germanHolidays = "german_holidays"
    case italianHolidays = "italian_holidays"
    case portugueseHolidays = "portuguese_holidays"
    case russianHolidays = "russian_holidays"
    case ukrainianHolidays = "ukrainian_holidays"
    case japaneseHolidays = "japanese_holidays"
    case koreanHolidays = "korean_holidays"
    case chineseHolidays = "chinese_holidays"

    var id: Self { self }

    var title: String {
        switch self {
        case .personal: String(localized: "Personal moments")
        case .usHolidays: String(localized: "U.S. holidays")
        case .observances: String(localized: "Observances")
        case .latinAmerican: String(localized: "Latin American dates")
        case .frenchHolidays: String(localized: "French holidays")
        case .germanHolidays: String(localized: "German holidays")
        case .italianHolidays: String(localized: "Italian holidays")
        case .portugueseHolidays: String(localized: "Portuguese holidays")
        case .russianHolidays: String(localized: "Russian holidays")
        case .ukrainianHolidays: String(localized: "Ukrainian holidays")
        case .japaneseHolidays: String(localized: "Japanese holidays")
        case .koreanHolidays: String(localized: "Korean holidays")
        case .chineseHolidays: String(localized: "Chinese holidays")
        }
    }
}

enum Occasion: String, CaseIterable, Identifiable, StableStringCodable {
    case birthday
    case homeAnniversary = "home_anniversary"
    case weddingAnniversary = "wedding_anniversary"
    case workAnniversary = "work_anniversary"
    case clientAppreciation = "client_appreciation"
    case custom

    // U.S. federal holidays.
    case newYearsDay = "new_years_day"
    case martinLutherKingJrDay = "martin_luther_king_jr_day"
    case presidentsDay = "presidents_day"
    case memorialDay = "memorial_day"
    case juneteenth
    case independenceDay = "independence_day"
    case laborDay = "labor_day"
    case columbusDay = "columbus_day"
    case veteransDay = "veterans_day"
    case thanksgiving
    case christmas

    // Widely used personal and community observances.
    case valentinesDay = "valentines_day"
    case internationalWomensDay = "international_womens_day"
    case earthDay = "earth_day"
    case mothersDay = "mothers_day"
    case fathersDay = "fathers_day"
    case halloween

    // Dates commonly celebrated across Latin American communities. Country-
    // specific names stay explicit rather than implying one universal calendar.
    case threeKingsDay = "three_kings_day"
    case cincoDeMayo = "cinco_de_mayo"
    case mexicanMothersDay = "mexican_mothers_day"
    case mexicanIndependenceDay = "mexican_independence_day"
    case hispanicHeritageMonth = "hispanic_heritage_month"
    case diaDeLaRaza = "dia_de_la_raza"
    case diaDeLosMuertos = "dia_de_los_muertos"
    case ourLadyOfGuadalupe = "our_lady_of_guadalupe"
    case lasPosadas = "las_posadas"
    case nochebuena

    // Fixed-date French national and public holidays.
    case franceNationalDay = "france_national_day"
    case franceVictoryInEuropeDay = "france_victory_in_europe_day"
    case franceArmisticeDay = "france_armistice_day"

    // Fixed-date German national and state holidays.
    case germanLaborDay = "german_labor_day"
    case germanUnityDay = "german_unity_day"
    case germanReformationDay = "german_reformation_day"

    // Fixed-date Italian national holidays.
    case italianLiberationDay = "italian_liberation_day"
    case italianRepublicDay = "italian_republic_day"
    case italianAssumptionDay = "italian_assumption_day"

    // Fixed-date Portuguese national holidays.
    case portugalFreedomDay = "portugal_freedom_day"
    case portugalDay = "portugal_day"
    case portugalRepublicDay = "portugal_republic_day"

    // Fixed-date Russian national holidays.
    case russiaDefenderOfFatherlandDay = "russia_defender_of_fatherland_day"
    case russiaVictoryDay = "russia_victory_day"
    case russiaDay = "russia_day"
    case russiaNationalUnityDay = "russia_national_unity_day"

    // Fixed-date Ukrainian national holidays.
    case ukraineConstitutionDay = "ukraine_constitution_day"
    case ukraineIndependenceDay = "ukraine_independence_day"
    case ukraineDefendersDay = "ukraine_defenders_day"

    // Fixed-date Japanese national holidays.
    case japanNationalFoundationDay = "japan_national_foundation_day"
    case japanConstitutionMemorialDay = "japan_constitution_memorial_day"
    case japanCultureDay = "japan_culture_day"
    case japanLaborThanksgivingDay = "japan_labor_thanksgiving_day"

    // Fixed-date South Korean national holidays.
    case koreaIndependenceMovementDay = "korea_independence_movement_day"
    case koreaLiberationDay = "korea_liberation_day"
    case koreaNationalFoundationDay = "korea_national_foundation_day"
    case koreaHangulDay = "korea_hangul_day"

    // Fixed-date Chinese public holidays. Lunar holidays are intentionally omitted.
    case chinaLaborDay = "china_labor_day"
    case chinaNationalDay = "china_national_day"

    var id: Self { self }

    static let legacyRawValues: [String: Occasion] = [
        "Birthday": .birthday,
        "Home anniversary": .homeAnniversary,
        "Wedding anniversary": .weddingAnniversary,
        "Work anniversary": .workAnniversary,
        "Client appreciation": .clientAppreciation,
        "Custom occasion": .custom,
        "Thanksgiving": .thanksgiving,
        "Christmas": .christmas,
        "New Year's Day": .newYearsDay,
        "Martin Luther King Jr. Day": .martinLutherKingJrDay,
        "Presidents' Day": .presidentsDay,
        "Memorial Day": .memorialDay,
        "Juneteenth": .juneteenth,
        "Independence Day": .independenceDay,
        "Labor Day": .laborDay,
        "Columbus Day": .columbusDay,
        "Veterans Day": .veteransDay
    ]

    var title: String {
        switch self {
        case .birthday: String(localized: "Birthday")
        case .homeAnniversary: String(localized: "Home anniversary")
        case .weddingAnniversary: String(localized: "Wedding anniversary")
        case .workAnniversary: String(localized: "Work anniversary")
        case .clientAppreciation: String(localized: "Client appreciation")
        case .custom: String(localized: "Custom occasion")
        case .newYearsDay: String(localized: "New Year's Day")
        case .martinLutherKingJrDay: String(localized: "Martin Luther King Jr. Day")
        case .presidentsDay: String(localized: "Presidents' Day")
        case .memorialDay: String(localized: "Memorial Day")
        case .juneteenth: String(localized: "Juneteenth")
        case .independenceDay: String(localized: "Independence Day")
        case .laborDay: String(localized: "Labor Day")
        case .columbusDay: String(localized: "Columbus Day")
        case .veteransDay: String(localized: "Veterans Day")
        case .thanksgiving: String(localized: "Thanksgiving")
        case .christmas: String(localized: "Christmas")
        case .valentinesDay: String(localized: "Valentine's Day")
        case .internationalWomensDay: String(localized: "International Women's Day")
        case .earthDay: String(localized: "Earth Day")
        case .mothersDay: String(localized: "Mother's Day")
        case .fathersDay: String(localized: "Father's Day")
        case .halloween: String(localized: "Halloween")
        case .threeKingsDay: String(localized: "Three Kings Day")
        case .cincoDeMayo: String(localized: "Cinco de Mayo")
        case .mexicanMothersDay: String(localized: "Mexican Mother's Day")
        case .mexicanIndependenceDay: String(localized: "Mexican Independence Day")
        case .hispanicHeritageMonth: String(localized: "Hispanic Heritage Month")
        case .diaDeLaRaza: String(localized: "Día de la Raza")
        case .diaDeLosMuertos: String(localized: "Día de los Muertos")
        case .ourLadyOfGuadalupe: String(localized: "Our Lady of Guadalupe")
        case .lasPosadas: String(localized: "Las Posadas")
        case .nochebuena: String(localized: "Nochebuena")
        case .franceNationalDay: String(localized: "French National Day")
        case .franceVictoryInEuropeDay: String(localized: "Victory in Europe Day (France)")
        case .franceArmisticeDay: String(localized: "Armistice Day (France)")
        case .germanLaborDay: String(localized: "German Labor Day")
        case .germanUnityDay: String(localized: "German Unity Day")
        case .germanReformationDay: String(localized: "German Reformation Day")
        case .italianLiberationDay: String(localized: "Italian Liberation Day")
        case .italianRepublicDay: String(localized: "Italian Republic Day")
        case .italianAssumptionDay: String(localized: "Italian Assumption Day")
        case .portugalFreedomDay: String(localized: "Portuguese Freedom Day")
        case .portugalDay: String(localized: "Portugal Day")
        case .portugalRepublicDay: String(localized: "Portuguese Republic Day")
        case .russiaDefenderOfFatherlandDay: String(localized: "Defender of the Fatherland Day")
        case .russiaVictoryDay: String(localized: "Victory Day")
        case .russiaDay: String(localized: "Russia Day")
        case .russiaNationalUnityDay: String(localized: "National Unity Day (Russia)")
        case .ukraineConstitutionDay: String(localized: "Constitution Day of Ukraine")
        case .ukraineIndependenceDay: String(localized: "Independence Day of Ukraine")
        case .ukraineDefendersDay: String(localized: "Defenders Day of Ukraine")
        case .japanNationalFoundationDay: String(localized: "National Foundation Day (Japan)")
        case .japanConstitutionMemorialDay: String(localized: "Constitution Memorial Day (Japan)")
        case .japanCultureDay: String(localized: "Culture Day (Japan)")
        case .japanLaborThanksgivingDay: String(localized: "Labor Thanksgiving Day (Japan)")
        case .koreaIndependenceMovementDay: String(localized: "March 1st Movement Day (Korea)")
        case .koreaLiberationDay: String(localized: "Liberation Day (Korea)")
        case .koreaNationalFoundationDay: String(localized: "National Foundation Day (Korea)")
        case .koreaHangulDay: String(localized: "Hangul Day (Korea)")
        case .chinaLaborDay: String(localized: "Labor Day (China)")
        case .chinaNationalDay: String(localized: "National Day (China)")
        }
    }

    var category: OccasionCategory {
        switch self {
        case .birthday, .homeAnniversary, .weddingAnniversary, .workAnniversary, .clientAppreciation, .custom:
            .personal
        case .newYearsDay, .martinLutherKingJrDay, .presidentsDay, .memorialDay,
             .juneteenth, .independenceDay, .laborDay, .columbusDay, .veteransDay,
             .thanksgiving, .christmas:
            .usHolidays
        case .valentinesDay, .internationalWomensDay, .earthDay, .mothersDay,
             .fathersDay, .halloween:
            .observances
        case .threeKingsDay, .cincoDeMayo, .mexicanMothersDay, .mexicanIndependenceDay,
             .hispanicHeritageMonth, .diaDeLaRaza, .diaDeLosMuertos,
             .ourLadyOfGuadalupe, .lasPosadas, .nochebuena:
            .latinAmerican
        case .franceNationalDay, .franceVictoryInEuropeDay, .franceArmisticeDay:
            .frenchHolidays
        case .germanLaborDay, .germanUnityDay, .germanReformationDay:
            .germanHolidays
        case .italianLiberationDay, .italianRepublicDay, .italianAssumptionDay:
            .italianHolidays
        case .portugalFreedomDay, .portugalDay, .portugalRepublicDay:
            .portugueseHolidays
        case .russiaDefenderOfFatherlandDay, .russiaVictoryDay, .russiaDay,
             .russiaNationalUnityDay:
            .russianHolidays
        case .ukraineConstitutionDay, .ukraineIndependenceDay, .ukraineDefendersDay:
            .ukrainianHolidays
        case .japanNationalFoundationDay, .japanConstitutionMemorialDay,
             .japanCultureDay, .japanLaborThanksgivingDay:
            .japaneseHolidays
        case .koreaIndependenceMovementDay, .koreaLiberationDay,
             .koreaNationalFoundationDay, .koreaHangulDay:
            .koreanHolidays
        case .chinaLaborDay, .chinaNationalDay:
            .chineseHolidays
        }
    }

    var searchTerms: String {
        switch self {
        case .newYearsDay: "new year federal january"
        case .martinLutherKingJrDay: "mlk civil rights federal january"
        case .presidentsDay: "washington birthday federal february"
        case .memorialDay: "military remembrance federal may"
        case .juneteenth: "freedom emancipation federal june"
        case .independenceDay: "fourth july federal usa"
        case .laborDay: "workers federal september"
        case .columbusDay: "indigenous peoples federal october"
        case .veteransDay: "military service federal november"
        case .thanksgiving: "gratitude federal november"
        case .christmas: "holiday federal december"
        case .valentinesDay: "love february"
        case .internationalWomensDay: "women march 8"
        case .earthDay: "environment april 22"
        case .mothersDay: "mom mother may"
        case .fathersDay: "dad father june"
        case .halloween: "october 31"
        case .threeKingsDay: "día de reyes dia de reyes epiphany enero january"
        case .cincoDeMayo: "méxico mexico mayo may"
        case .mexicanMothersDay: "día de las madres dia madres méxico mexico mayo may"
        case .mexicanIndependenceDay: "independencia méxico mexico septiembre september"
        case .hispanicHeritageMonth: "latino heritage september septiembre"
        case .diaDeLaRaza: "día dia raza octubre october"
        case .diaDeLosMuertos: "day of the dead muertos noviembre november"
        case .ourLadyOfGuadalupe: "virgen guadalupe diciembre december"
        case .lasPosadas: "posadas diciembre december"
        case .nochebuena: "christmas eve víspera navidad diciembre december"
        case .franceNationalDay: "france national bastille july 14 juillet"
        case .franceVictoryInEuropeDay: "france victory europe may 8 liberation"
        case .franceArmisticeDay: "france armistice november 11 remembrance"
        case .germanLaborDay: "germany german labor workers may 1 tag der arbeit"
        case .germanUnityDay: "germany german unity reunification october 3"
        case .germanReformationDay: "germany german reformation october 31"
        case .italianLiberationDay: "italy italian liberation april 25"
        case .italianRepublicDay: "italy italian republic june 2"
        case .italianAssumptionDay: "italy italian assumption ferragosto august 15"
        case .portugalFreedomDay: "portugal freedom carnation revolution april 25"
        case .portugalDay: "portugal day portugal national june 10"
        case .portugalRepublicDay: "portugal republic october 5"
        case .russiaDefenderOfFatherlandDay: "russia defender fatherland february 23"
        case .russiaVictoryDay: "russia victory may 9 победы"
        case .russiaDay: "russia day national june 12"
        case .russiaNationalUnityDay: "russia national unity november 4"
        case .ukraineConstitutionDay: "ukraine constitution june 28"
        case .ukraineIndependenceDay: "ukraine independence august 24"
        case .ukraineDefendersDay: "ukraine defenders october 1"
        case .japanNationalFoundationDay: "japan national foundation february 11"
        case .japanConstitutionMemorialDay: "japan constitution memorial may 3"
        case .japanCultureDay: "japan culture november 3"
        case .japanLaborThanksgivingDay: "japan labor labour thanksgiving november 23"
        case .koreaIndependenceMovementDay: "korea independence movement samil march 1"
        case .koreaLiberationDay: "korea liberation gwangbok august 15"
        case .koreaNationalFoundationDay: "korea national foundation gaecheonjeol october 3"
        case .koreaHangulDay: "korea hangul hangeul alphabet october 9"
        case .chinaLaborDay: "china labor workers may 1"
        case .chinaNationalDay: "china national october 1"
        default: ""
        }
    }

    /// Disambiguates occasion labels for the on-device language model. This is
    /// intentionally explicit for labels such as "Home anniversary", which can
    /// otherwise be interpreted as an unspecified anniversary.
    var generationContextDescription: String {
        switch self {
        case .birthday:
            "The recipient's birthday. Celebrate the recipient personally."
        case .homeAnniversary:
            "The anniversary of the recipient buying or moving into their home. Celebrate that home milestone; this is not a wedding, relationship, or work anniversary."
        case .weddingAnniversary:
            "The recipient's wedding anniversary. Celebrate their marriage without inventing a year count or spouse details."
        case .workAnniversary:
            "The anniversary of the recipient starting a job or professional role. Celebrate the work milestone without inventing a year count."
        case .clientAppreciation:
            "A message thanking the recipient as a client. Do not imply a birthday or anniversary."
        case .custom:
            "A custom occasion. Follow the provided occasion label and event context exactly; do not replace it with a generic anniversary."
        case .thanksgiving:
            "A Thanksgiving greeting appropriate to the recipient and relationship."
        case .christmas:
            "A Christmas greeting appropriate to the recipient and relationship."
        default:
            "A greeting for \(title). Respect the cultural meaning of the date and do not invent personal details."
        }
    }

    static let contactSpecificCases: [Occasion] = [
        .birthday,
        .homeAnniversary,
        .weddingAnniversary,
        .workAnniversary,
        .clientAppreciation,
        .custom
    ]

    var icon: String {
        switch self {
        case .birthday: "birthday.cake"
        case .homeAnniversary: "house"
        case .weddingAnniversary: "heart"
        case .workAnniversary: "briefcase"
        case .clientAppreciation: "hands.sparkles"
        case .custom: "star"
        case .newYearsDay: "sparkles"
        case .martinLutherKingJrDay: "person.crop.circle.badge.checkmark"
        case .presidentsDay: "building.columns"
        case .memorialDay: "flag"
        case .juneteenth: "sun.max"
        case .independenceDay: "flag.fill"
        case .laborDay: "hammer"
        case .columbusDay: "map"
        case .veteransDay: "medal"
        case .thanksgiving: "leaf"
        case .christmas: "gift"
        case .valentinesDay: "heart.fill"
        case .internationalWomensDay: "figure.dress.line.vertical.figure"
        case .earthDay: "globe.americas.fill"
        case .mothersDay: "camera.macro"
        case .fathersDay: "person.crop.circle"
        case .halloween: "moon.stars.fill"
        case .threeKingsDay: "crown"
        case .cincoDeMayo: "party.popper"
        case .mexicanMothersDay: "camera.macro"
        case .mexicanIndependenceDay: "flag.fill"
        case .hispanicHeritageMonth: "person.3.fill"
        case .diaDeLaRaza: "globe.americas"
        case .diaDeLosMuertos: "flame"
        case .ourLadyOfGuadalupe: "star.circle"
        case .lasPosadas: "house.and.flag"
        case .nochebuena: "moon.stars"
        case .franceNationalDay: "flag.fill"
        case .franceVictoryInEuropeDay: "flag"
        case .franceArmisticeDay: "shield"
        case .germanLaborDay: "hammer"
        case .germanUnityDay: "flag.fill"
        case .germanReformationDay: "book.closed"
        case .italianLiberationDay: "flag"
        case .italianRepublicDay: "building.columns"
        case .italianAssumptionDay: "sparkles"
        case .portugalFreedomDay: "flag"
        case .portugalDay: "flag.fill"
        case .portugalRepublicDay: "building.columns"
        case .russiaDefenderOfFatherlandDay: "shield"
        case .russiaVictoryDay: "medal"
        case .russiaDay: "flag.fill"
        case .russiaNationalUnityDay: "person.3"
        case .ukraineConstitutionDay: "book.closed"
        case .ukraineIndependenceDay: "flag.fill"
        case .ukraineDefendersDay: "shield"
        case .japanNationalFoundationDay: "sun.max"
        case .japanConstitutionMemorialDay: "book.closed"
        case .japanCultureDay: "paintpalette"
        case .japanLaborThanksgivingDay: "hands.sparkles"
        case .koreaIndependenceMovementDay: "figure.walk"
        case .koreaLiberationDay: "flag.fill"
        case .koreaNationalFoundationDay: "building.columns"
        case .koreaHangulDay: "character.book.closed"
        case .chinaLaborDay: "hammer"
        case .chinaNationalDay: "flag.fill"
        }
    }

    var tint: Color {
        switch self {
        case .birthday: TouchPointColor.coral
        case .homeAnniversary: .accentColor
        case .weddingAnniversary: TouchPointColor.rose
        case .workAnniversary: TouchPointColor.teal
        case .clientAppreciation: TouchPointColor.teal
        case .custom: .accentColor
        case .newYearsDay, .martinLutherKingJrDay, .presidentsDay, .memorialDay,
             .juneteenth, .independenceDay, .laborDay, .columbusDay, .veteransDay:
            TouchPointColor.blue
        case .thanksgiving: TouchPointColor.amber
        case .christmas: TouchPointColor.forest
        case .valentinesDay, .internationalWomensDay, .mothersDay, .fathersDay:
            TouchPointColor.rose
        case .earthDay: TouchPointColor.forest
        case .halloween: TouchPointColor.amber
        case .threeKingsDay, .cincoDeMayo, .mexicanMothersDay, .mexicanIndependenceDay,
             .hispanicHeritageMonth, .diaDeLaRaza, .diaDeLosMuertos,
             .ourLadyOfGuadalupe, .lasPosadas, .nochebuena:
            TouchPointColor.coral
        case .franceNationalDay, .franceVictoryInEuropeDay, .franceArmisticeDay,
             .germanLaborDay, .germanUnityDay, .germanReformationDay,
             .portugalFreedomDay, .portugalDay, .portugalRepublicDay,
             .russiaDefenderOfFatherlandDay, .russiaVictoryDay, .russiaDay,
             .russiaNationalUnityDay,
             .ukraineConstitutionDay, .ukraineIndependenceDay, .ukraineDefendersDay,
             .japanNationalFoundationDay, .japanConstitutionMemorialDay,
             .japanCultureDay, .japanLaborThanksgivingDay,
             .koreaIndependenceMovementDay, .koreaLiberationDay,
             .koreaNationalFoundationDay, .koreaHangulDay,
             .chinaLaborDay, .chinaNationalDay:
            TouchPointColor.blue
        case .italianLiberationDay, .italianRepublicDay, .italianAssumptionDay:
            TouchPointColor.forest
        }
    }
}

enum ContactMethod: String, CaseIterable, Identifiable, StableStringCodable {
    case sms
    case email
    case reminder

    var id: Self { self }

    static let legacyRawValues: [String: ContactMethod] = [
        "Text message": .sms,
        "Email": .email,
        "Reminder only": .reminder
    ]

    var title: String {
        switch self {
        case .sms: String(localized: "Text message")
        case .email: String(localized: "Email")
        case .reminder: String(localized: "Reminder only")
        }
    }

    var icon: String {
        switch self {
        case .sms: "message"
        case .email: "envelope"
        case .reminder: "bell"
        }
    }
}

enum TouchPointLanguage {
    static let defaultLanguage = "English"
    static let supported = [
        "English", "Spanish", "French", "German", "Italian", "Portuguese",
        "Russian", "Ukrainian", "Japanese", "Korean", "Chinese"
    ]

    static func resolved(_ value: String?) -> String {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              let match = supported.first(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) else {
            return defaultLanguage
        }
        return match
    }

    static func options(including value: String) -> [String] {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !supported.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            return supported
        }
        return [trimmed] + supported
    }
}

enum GreetingStatus: String, CaseIterable, Identifiable, StableStringCodable {
    case planned
    case ready
    case completed
    case skipped

    var id: Self { self }

    static let legacyRawValues: [String: GreetingStatus] = [
        "Planned": .planned,
        "Ready": .ready,
        "Completed": .completed,
        "Skipped": .skipped
    ]

    var title: String {
        switch self {
        case .planned: String(localized: "Planned")
        case .ready: String(localized: "Ready")
        case .completed: String(localized: "Completed")
        case .skipped: String(localized: "Skipped")
        }
    }
}

struct Person: Identifiable, Hashable, Codable {
    let id: UUID
    var firstName: String
    var preferredName: String
    var lastName: String
    var email: String
    var phone: String
    var organization: String
    var relationship: Relationship
    var preferredContactMethod: ContactMethod
    var preferredLanguage: String
    var timeZoneIdentifier: String
    var importantDates: [ImportantDate]
    /// Free-form context kept with a person. Missing fields decode as empty for legacy data.
    var notes: String
    var tags: [String]
    var communicationStopped: Bool

    var hasContactInfo: Bool {
        Self.hasContactInfo(phone: phone, email: email)
    }

    static func hasContactInfo(phone: String, email: String) -> Bool {
        !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        firstName: String? = nil,
        preferredName: String = "",
        lastName: String? = nil,
        email: String = "",
        phone: String = "",
        organization: String = "",
        relationship: Relationship,
        preferredContactMethod: ContactMethod = .sms,
        preferredLanguage: String = "English",
        timeZoneIdentifier: String = "America/Los_Angeles",
        importantDates: [ImportantDate] = [],
        notes: String = "",
        tags: [String] = [],
        communicationStopped: Bool = false
    ) {
        self.id = id
        let legacyName = Self.splitLegacyName(name)
        self.firstName = firstName ?? legacyName.first
        self.preferredName = preferredName
        self.lastName = lastName ?? legacyName.last
        self.email = email
        self.phone = phone
        self.organization = organization
        self.relationship = relationship
        self.preferredContactMethod = preferredContactMethod
        self.preferredLanguage = preferredLanguage
        self.timeZoneIdentifier = timeZoneIdentifier
        self.importantDates = importantDates
        self.notes = notes
        self.tags = tags
        self.communicationStopped = communicationStopped
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, firstName, preferredName, lastName, email, phone, organization, relationship, preferredContactMethod
        case preferredLanguage, timeZoneIdentifier, importantDates, notes, tags, communicationStopped
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        let legacyName = Self.splitLegacyName(try container.decodeIfPresent(String.self, forKey: .name) ?? "")
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName) ?? legacyName.first
        preferredName = try container.decodeIfPresent(String.self, forKey: .preferredName) ?? ""
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName) ?? legacyName.last
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
        organization = try container.decodeIfPresent(String.self, forKey: .organization) ?? ""
        relationship = try container.decodeIfPresent(Relationship.self, forKey: .relationship) ?? .friend
        preferredContactMethod = try container.decodeIfPresent(ContactMethod.self, forKey: .preferredContactMethod) ?? .sms
        preferredLanguage = try container.decodeIfPresent(String.self, forKey: .preferredLanguage) ?? "English"
        timeZoneIdentifier = try container.decodeIfPresent(String.self, forKey: .timeZoneIdentifier) ?? "America/Los_Angeles"
        importantDates = try container.decodeIfPresent([ImportantDate].self, forKey: .importantDates) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        communicationStopped = try container.decodeIfPresent(Bool.self, forKey: .communicationStopped) ?? false
        tags = (try container.decodeIfPresent([String].self, forKey: .tags) ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id); try container.encode(name, forKey: .name)
        try container.encode(firstName, forKey: .firstName)
        try container.encode(preferredName, forKey: .preferredName)
        try container.encode(lastName, forKey: .lastName)
        try container.encode(email, forKey: .email); try container.encode(phone, forKey: .phone)
        try container.encode(organization, forKey: .organization); try container.encode(relationship, forKey: .relationship)
        try container.encode(preferredContactMethod, forKey: .preferredContactMethod)
        try container.encode(preferredLanguage, forKey: .preferredLanguage)
        try container.encode(timeZoneIdentifier, forKey: .timeZoneIdentifier)
        try container.encode(importantDates, forKey: .importantDates)
        try container.encode(notes, forKey: .notes); try container.encode(tags, forKey: .tags)
        try container.encode(communicationStopped, forKey: .communicationStopped)
    }

    /// Keep the existing full-name token and consumers compatible.
    var name: String {
        [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var displayName: String {
        let preferred = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        return [firstName, preferred.isEmpty ? "" : "\"\(preferred)\"", lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Legacy full names have no reliable boundaries beyond the first word.
    /// Preserve all remaining words, including compound surnames.
    private static func splitLegacyName(_ name: String) -> (first: String, last: String) {
        let parts = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
        return (parts.first.map(String.init) ?? "",
                parts.dropFirst().first.map(String.init) ?? "")
    }

    var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}

/// Persisted library identity is independent of the built-in calendar calculation.
struct OccasionNode: Identifiable, Hashable, Codable {
    var id: String = UUID().uuidString
    var name: String = ""
    var parentID: String?
    var isGroup: Bool = false
    var builtInOccasion: Occasion?
    var builtInCategoryID: String?
    var templateID: UUID?
    var dateRule: OccasionDateRule = .personDate
    var month: Int = 1
    var day: Int = 1
    var sortOrder: Int = 0

    var occasion: Occasion { builtInOccasion ?? .custom }
    var title: String {
        if !name.isEmpty { return name }
        if let builtInOccasion { return builtInOccasion.title }
        return OccasionCategory(rawValue: builtInCategoryID ?? "")?.title ?? ""
    }
    var icon: String { isGroup ? "folder" : occasion.icon }

    static func defaults() -> [OccasionNode] {
        let groups = OccasionCategory.allCases.enumerated().map { index, category in
            OccasionNode(id: "group:" + category.rawValue, isGroup: true,
                         builtInCategoryID: category.rawValue, sortOrder: index)
        }
        let occasions = Occasion.allCases.map { occasion in
            OccasionNode(id: "occasion:" + occasion.rawValue,
                         parentID: "group:" + occasion.category.rawValue,
                         builtInOccasion: occasion,
                         dateRule: Occasion.contactSpecificCases.contains(occasion) ? .personDate : .calendar,
                         sortOrder: Occasion.allCases.filter { $0.category == occasion.category }.firstIndex(of: occasion) ?? 0)
        }
        return groups + occasions
    }
}

enum OccasionDateRule: String, Codable, CaseIterable, Identifiable {
    case personDate, fixedDate, calendar
    var id: Self { self }
    var title: String {
        switch self {
        case .personDate: String(localized: "Date set for each person")
        case .fixedDate: String(localized: "Same date every year")
        case .calendar: String(localized: "Holiday calendar")
        }
    }
}

struct ImportantDate: Identifiable, Hashable, Codable {
    let id: UUID
    var occasion: Occasion
    var month: Int
    var day: Int
    /// Optional label for a custom event represented by this date.
    var customName: String?
    var occasionID: String?

    init(id: UUID = UUID(), occasion: Occasion, month: Int, day: Int, customName: String? = nil, occasionID: String? = nil) {
        self.id = id
        self.occasion = occasion
        self.month = month
        self.day = day
        self.customName = customName
        self.occasionID = occasionID
    }

    private enum CodingKeys: String, CodingKey { case id, occasion, month, day, customName, occasionID }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        occasion = try c.decodeIfPresent(Occasion.self, forKey: .occasion) ?? .birthday
        month = try c.decodeIfPresent(Int.self, forKey: .month) ?? 1
        day = try c.decodeIfPresent(Int.self, forKey: .day) ?? 1
        customName = try c.decodeIfPresent(String.self, forKey: .customName)
        occasionID = try c.decodeIfPresent(String.self, forKey: .occasionID)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(occasion, forKey: .occasion)
        try c.encode(month, forKey: .month); try c.encode(day, forKey: .day)
        try c.encodeIfPresent(customName, forKey: .customName)
        try c.encodeIfPresent(occasionID, forKey: .occasionID)
    }

    var formatted: String {
        var components = DateComponents()
        components.calendar = .current
        components.year = 2000
        components.month = month
        components.day = day
        guard let date = components.date else { return "Date unavailable" }
        return date.formatted(.dateTime.month(.wide).day())
    }

    var displayName: String {
        guard let customName else { return occasion.title }
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? occasion.title : trimmed
    }
}

struct GreetingEvent: Identifiable, Hashable, Codable {
    let id: UUID
    var personID: UUID
    var occasion: Occasion
    var date: Date
    var method: ContactMethod
    var status: GreetingStatus
    var message: String
    var subject: String?
    /// The template snapshot used when this greeting was planned. Optional for legacy events.
    var sourceTemplateID: UUID?
    var sourceTemplateRevision: Int?
    /// Optional user-facing name for an event that does not fit the built-in occasions.
    var customName: String?
    var occasionID: String?
    var recurrence: EventRecurrence
    var sourceImportantDateID: UUID?

    init(
        id: UUID = UUID(),
        personID: UUID,
        occasion: Occasion,
        date: Date,
        method: ContactMethod,
        status: GreetingStatus,
        message: String = "",
        subject: String? = nil,
        sourceTemplateID: UUID? = nil,
        sourceTemplateRevision: Int? = nil,
        customName: String? = nil,
        recurrence: EventRecurrence = .annual,
        occasionID: String? = nil,
        sourceImportantDateID: UUID? = nil
    ) {
        self.id = id
        self.personID = personID
        self.occasion = occasion
        self.date = date
        self.method = method
        self.status = status
        self.message = message
        self.subject = subject
        self.sourceTemplateID = sourceTemplateID
        self.sourceTemplateRevision = sourceTemplateRevision
        self.customName = customName
        self.occasionID = occasionID
        self.recurrence = recurrence
        self.sourceImportantDateID = sourceImportantDateID
    }

    private enum CodingKeys: String, CodingKey {
        case id, personID, occasion, date, method, status, message, subject
        case sourceTemplateID, sourceTemplateRevision, customName, recurrence, occasionID, sourceImportantDateID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        personID = try c.decodeIfPresent(UUID.self, forKey: .personID) ?? UUID()
        occasion = try c.decodeIfPresent(Occasion.self, forKey: .occasion) ?? .birthday
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? .now
        method = try c.decodeIfPresent(ContactMethod.self, forKey: .method) ?? .reminder
        status = try c.decodeIfPresent(GreetingStatus.self, forKey: .status) ?? .planned
        message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
        subject = try c.decodeIfPresent(String.self, forKey: .subject)
        sourceTemplateID = try c.decodeIfPresent(UUID.self, forKey: .sourceTemplateID)
        sourceTemplateRevision = try c.decodeIfPresent(Int.self, forKey: .sourceTemplateRevision)
        customName = try c.decodeIfPresent(String.self, forKey: .customName)
        occasionID = try c.decodeIfPresent(String.self, forKey: .occasionID)
        sourceImportantDateID = try c.decodeIfPresent(UUID.self, forKey: .sourceImportantDateID)
        recurrence = try c.decodeIfPresent(EventRecurrence.self, forKey: .recurrence) ?? .annual
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(personID, forKey: .personID)
        try c.encode(occasion, forKey: .occasion); try c.encode(date, forKey: .date)
        try c.encode(method, forKey: .method); try c.encode(status, forKey: .status)
        try c.encode(message, forKey: .message); try c.encodeIfPresent(subject, forKey: .subject)
        try c.encodeIfPresent(sourceTemplateID, forKey: .sourceTemplateID)
        try c.encodeIfPresent(sourceTemplateRevision, forKey: .sourceTemplateRevision)
        try c.encodeIfPresent(customName, forKey: .customName)
        try c.encodeIfPresent(occasionID, forKey: .occasionID)
        try c.encodeIfPresent(sourceImportantDateID, forKey: .sourceImportantDateID)
        try c.encode(recurrence, forKey: .recurrence)
    }

    var displayName: String {
        guard let customName else { return occasion.title }
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? occasion.title : trimmed
    }
}

enum EventRecurrence: String, CaseIterable, Codable, Identifiable, StableStringCodable {
    case annual
    case oneTime = "one_time"

    var id: Self { self }

    static let legacyRawValues: [String: EventRecurrence] = [
        "Annual": .annual, "One-time": .oneTime, "one-time": .oneTime
    ]

    var title: String {
        switch self {
        case .annual: String(localized: "Annual")
        case .oneTime: String(localized: "One-time")
        }
    }
}

/// A user-manageable collection for organizing templates.
struct TemplateGroup: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var iconSemantic: String
    var iconID: String
    var colorToken: String
    var sortOrder: Int
    var isBuiltIn: Bool
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date

    var title: String {
        get { name }
        set { name = newValue }
    }

    var icon: String {
        get { iconID }
        set { iconID = newValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        iconSemantic: String = "folder",
        iconID: String = "folder",
        colorToken: String = "teal",
        sortOrder: Int = 0,
        isBuiltIn: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.iconSemantic = iconSemantic
        self.iconID = iconID
        self.colorToken = colorToken
        self.sortOrder = sortOrder
        self.isBuiltIn = isBuiltIn
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct GreetingTemplate: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    /// The occasions this template can be used for. `occasion` remains available for the current UI.
    var occasions: [Occasion]
    var body: String
    /// Additional messages in order; the legacy body is always variation one.
    var bodyVariations: [String]
    /// The next suggestion, advanced only when a greeting is committed.
    var nextVariationIndex: Int

    var messageBodies: [String] { [body] + bodyVariations }

    mutating func advanceVariation() {
        nextVariationIndex = (max(0, nextVariationIndex) % messageBodies.count + 1) % messageBodies.count
    }
    var isFavorite: Bool
    var iconSemantic: String
    var iconID: String
    var colorToken: String
    var groupID: UUID?
    var relationships: [Relationship]
    var channels: [ContactMethod]
    var languages: [String]
    var emailSubject: String?
    var isBuiltIn: Bool
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date
    /// Monotonically increasing local content revision. Starts at one for legacy templates.
    var revisionNumber: Int
    /// The legacy single-occasion API used by the existing views.
    var occasion: Occasion {
        get { occasions.first ?? .birthday }
        set {
            occasions = [newValue] + occasions.filter { $0 != newValue }
        }
    }

    /// The legacy message API used by the existing views and v1/v2 data.
    var message: String {
        get { body }
        set { body = newValue }
    }

    var icon: String {
        get { iconID }
        set { iconID = newValue }
    }

    /// Descriptive aliases for clients that prefer the audience terminology.
    var relationshipAudiences: [Relationship] {
        get { relationships }
        set { relationships = newValue }
    }

    var channelAudiences: [ContactMethod] {
        get { channels }
        set { channels = newValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        occasion: Occasion,
        message: String,
        isFavorite: Bool = false
    ) {
        self.init(
            id: id,
            title: title,
            occasions: [occasion],
            body: message,
            isFavorite: isFavorite,
            iconSemantic: "occasion",
            iconID: occasion.icon,
            colorToken: occasion.defaultColorToken
        )
    }

    init(
        id: UUID = UUID(),
        title: String,
        occasion: Occasion,
        body: String,
        isFavorite: Bool = false
    ) {
        self.init(id: id, title: title, occasion: occasion, message: body, isFavorite: isFavorite)
    }

    init(
        id: UUID = UUID(),
        title: String,
        occasions: [Occasion],
        body: String,
        bodyVariations: [String] = [],
        isFavorite: Bool = false,
        iconSemantic: String = "occasion",
        iconID: String? = nil,
        colorToken: String? = nil,
        groupID: UUID? = nil,
        relationships: [Relationship] = [],
        channels: [ContactMethod] = [],
        languages: [String] = [],
        emailSubject: String? = nil,
        isBuiltIn: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        revisionNumber: Int = 1
    ) {
        var normalizedOccasions: [Occasion] = []
        for occasion in occasions where !normalizedOccasions.contains(occasion) {
            normalizedOccasions.append(occasion)
        }
        if normalizedOccasions.isEmpty { normalizedOccasions = [.birthday] }
        self.id = id
        self.title = title
        self.occasions = normalizedOccasions
        self.body = body
        self.bodyVariations = bodyVariations
        self.nextVariationIndex = 0
        self.isFavorite = isFavorite
        self.iconSemantic = iconSemantic
        self.iconID = iconID ?? normalizedOccasions.first?.icon ?? "text.quote"
        self.colorToken = colorToken ?? normalizedOccasions.first?.defaultColorToken ?? "teal"
        self.groupID = groupID
        self.relationships = relationships
        self.channels = channels
        self.languages = languages
        self.emailSubject = emailSubject
        self.isBuiltIn = isBuiltIn
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.revisionNumber = max(1, revisionNumber)
    }

    /// The supported interpolation tokens, without braces.
    static let supportedTokens: Set<String> = ["first_name", "preferred_name", "last_name", "name", "organization", "occasion", "date", "sender_name"]

    var validationErrors: [String] {
        var errors: [String] = []
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append("A title is required.") }
        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append("A body is required.") }
        if bodyVariations.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            errors.append(String(localized: "Every variation needs a message."))
        }
        if occasions.isEmpty { errors.append("At least one occasion is required.") }
        let tokenPattern = #"\{\{([A-Za-z0-9_]+)\}\}"#
        for source in messageBodies + [emailSubject ?? ""] where !source.isEmpty {
            let openingCount = source.components(separatedBy: "{{").count - 1
            let closingCount = source.components(separatedBy: "}}").count - 1
            if openingCount != closingCount {
                errors.append("A template variable has unmatched braces.")
            }
            if let regex = try? NSRegularExpression(pattern: tokenPattern) {
                let range = NSRange(source.startIndex..., in: source)
                for match in regex.matches(in: source, range: range) {
                    guard let tokenRange = Range(match.range(at: 1), in: source) else { continue }
                    let token = String(source[tokenRange])
                    if !Self.supportedTokens.contains(token) {
                        errors.append("Unsupported token: {{\(token)}}.")
                    }
                }
            }
        }
        return Array(Set(errors)).sorted()
    }

    func validate() -> [String] { validationErrors }

    enum CodingKeys: String, CodingKey {
        case id, title, occasion, occasions, body, message, isFavorite
        case bodyVariations, nextVariationIndex
        case iconSemantic, iconID, icon, colorToken, groupID
        case relationships, relationshipAudiences, channels, channelAudiences, languages
        case emailSubject, isBuiltIn, isArchived, createdAt, updatedAt
        case revisionNumber
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled template"
        let legacyOccasion = try container.decodeIfPresent(Occasion.self, forKey: .occasion)
        let decodedOccasions = try container.decodeIfPresent([Occasion].self, forKey: .occasions) ?? []
        occasions = decodedOccasions.isEmpty ? [legacyOccasion ?? .birthday] : decodedOccasions
        body = try container.decodeIfPresent(String.self, forKey: .body)
            ?? container.decodeIfPresent(String.self, forKey: .message)
            ?? ""
        bodyVariations = try container.decodeIfPresent([String].self, forKey: .bodyVariations) ?? []
        nextVariationIndex = max(0, try container.decodeIfPresent(Int.self, forKey: .nextVariationIndex) ?? 0)
            % (bodyVariations.count + 1)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        iconSemantic = try container.decodeIfPresent(String.self, forKey: .iconSemantic) ?? "occasion"
        iconID = try container.decodeIfPresent(String.self, forKey: .iconID)
            ?? container.decodeIfPresent(String.self, forKey: .icon)
            ?? occasions.first?.icon
            ?? "text.quote"
        colorToken = try container.decodeIfPresent(String.self, forKey: .colorToken)
            ?? occasions.first?.defaultColorToken
            ?? "teal"
        groupID = try container.decodeIfPresent(UUID.self, forKey: .groupID)
        relationships = try container.decodeIfPresent([Relationship].self, forKey: .relationships)
            ?? container.decodeIfPresent([Relationship].self, forKey: .relationshipAudiences)
            ?? []
        channels = try container.decodeIfPresent([ContactMethod].self, forKey: .channels)
            ?? container.decodeIfPresent([ContactMethod].self, forKey: .channelAudiences)
            ?? []
        languages = try container.decodeIfPresent([String].self, forKey: .languages) ?? []
        emailSubject = try container.decodeIfPresent(String.self, forKey: .emailSubject)
        isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        revisionNumber = max(1, try container.decodeIfPresent(Int.self, forKey: .revisionNumber) ?? 1)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(occasion, forKey: .occasion)
        try container.encode(occasions, forKey: .occasions)
        try container.encode(body, forKey: .body)
        try container.encode(bodyVariations, forKey: .bodyVariations)
        try container.encode(nextVariationIndex, forKey: .nextVariationIndex)
        // Keep writing `message` so an older build can still read newly saved data.
        try container.encode(body, forKey: .message)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(iconSemantic, forKey: .iconSemantic)
        try container.encode(iconID, forKey: .iconID)
        try container.encode(colorToken, forKey: .colorToken)
        try container.encodeIfPresent(groupID, forKey: .groupID)
        try container.encode(relationships, forKey: .relationships)
        try container.encode(channels, forKey: .channels)
        try container.encode(languages, forKey: .languages)
        try container.encodeIfPresent(emailSubject, forKey: .emailSubject)
        try container.encode(isBuiltIn, forKey: .isBuiltIn)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(revisionNumber, forKey: .revisionNumber)
    }
}

/// The user-editable portion of a template, used by version history.
struct TemplateContentSnapshot: Codable, Hashable {
    var title: String
    var occasions: [Occasion]
    var body: String
    /// Optional so revision history from older backups continues to decode.
    var bodyVariations: [String]?
    var iconSemantic: String
    var iconID: String
    var colorToken: String
    var groupID: UUID?
    var relationships: [Relationship]
    var channels: [ContactMethod]
    var languages: [String]
    var emailSubject: String?

    init(template: GreetingTemplate) {
        title = template.title
        occasions = template.occasions
        body = template.body
        bodyVariations = template.bodyVariations.isEmpty ? nil : template.bodyVariations
        iconSemantic = template.iconSemantic
        iconID = template.iconID
        colorToken = template.colorToken
        groupID = template.groupID
        relationships = template.relationships
        channels = template.channels
        languages = template.languages
        emailSubject = template.emailSubject
    }
}

struct TemplateRevision: Identifiable, Codable, Hashable {
    let id: UUID
    let templateID: UUID
    let number: Int
    let createdAt: Date
    let snapshot: TemplateContentSnapshot

    init(
        id: UUID = UUID(),
        templateID: UUID,
        number: Int,
        createdAt: Date = .now,
        snapshot: TemplateContentSnapshot
    ) {
        self.id = id
        self.templateID = templateID
        self.number = max(1, number)
        self.createdAt = createdAt
        self.snapshot = snapshot
    }
}

extension Occasion {
    var defaultColorToken: String {
        switch self {
        case .birthday: "coral"
        case .homeAnniversary: "blue"
        case .weddingAnniversary: "rose"
        case .workAnniversary: "teal"
        case .clientAppreciation: "teal"
        case .custom: "indigo"
        case .newYearsDay, .martinLutherKingJrDay, .presidentsDay, .memorialDay,
             .juneteenth, .independenceDay, .laborDay, .columbusDay, .veteransDay:
            "blue"
        case .thanksgiving: "amber"
        case .christmas: "forest"
        case .valentinesDay, .internationalWomensDay, .mothersDay, .fathersDay:
            "rose"
        case .earthDay: "forest"
        case .halloween: "amber"
        case .threeKingsDay, .cincoDeMayo, .mexicanMothersDay, .mexicanIndependenceDay,
             .hispanicHeritageMonth, .diaDeLaRaza, .diaDeLosMuertos,
             .ourLadyOfGuadalupe, .lasPosadas, .nochebuena:
            "coral"
        case .franceNationalDay, .franceVictoryInEuropeDay, .franceArmisticeDay,
             .germanLaborDay, .germanUnityDay, .germanReformationDay,
             .portugalFreedomDay, .portugalDay, .portugalRepublicDay,
             .russiaDefenderOfFatherlandDay, .russiaVictoryDay, .russiaDay,
             .russiaNationalUnityDay,
             .ukraineConstitutionDay, .ukraineIndependenceDay, .ukraineDefendersDay,
             .japanNationalFoundationDay, .japanConstitutionMemorialDay,
             .japanCultureDay, .japanLaborThanksgivingDay,
             .koreaIndependenceMovementDay, .koreaLiberationDay,
             .koreaNationalFoundationDay, .koreaHangulDay,
             .chinaLaborDay, .chinaNationalDay:
            "blue"
        case .italianLiberationDay, .italianRepublicDay, .italianAssumptionDay:
            "forest"
        }
    }
}

enum PlanningHorizon: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "7 days"
    case month = "1 month"
    case sixMonths = "6 months"
    case year = "1 year"
    case twoYears = "2 years"

    var id: Self { self }

    var dateComponents: DateComponents {
        switch self {
        case .today: DateComponents(day: 1)
        case .week: DateComponents(day: 7)
        case .month: DateComponents(month: 1)
        case .sixMonths: DateComponents(month: 6)
        case .year: DateComponents(year: 1)
        case .twoYears: DateComponents(year: 2)
        }
    }
}
