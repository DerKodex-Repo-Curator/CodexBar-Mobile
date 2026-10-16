import CodexBarSync
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import CodexBarMobile

@Suite("v0.76 provider presentation")
struct V076ProviderPresentationTests {
    @Test func `new provider detail labels localize in four languages`() {
        let expected: [(String, String, [String: String])] = [
            ("flora", "Workspace balance", ["zh-Hans": "工作区余额", "zh-Hant": "工作區餘額", "ja": "ワークスペース残高"]),
            ("flora", "Member limit", ["zh-Hans": "成员上限", "zh-Hant": "成員上限", "ja": "メンバー上限"]),
            ("flora", "Runs this month", ["zh-Hans": "本月运行次数", "zh-Hant": "本月執行次數", "ja": "今月の実行回数"]),
            ("flora", "Spent this month", ["zh-Hans": "本月支出", "zh-Hant": "本月支出", "ja": "今月の支出"]),
            ("parallel", "Pending debit", ["zh-Hans": "待扣款", "zh-Hant": "待扣款", "ja": "保留中の引き落とし"]),
            ("parallel", "Account balance", ["zh-Hans": "账户余额", "zh-Hant": "帳戶餘額", "ja": "アカウント残高"]),
            ("fal", "Credit balance", ["zh-Hans": "额度余额", "zh-Hant": "額度餘額", "ja": "クレジット残高"]),
            ("claudeplatform", "Other credit grants", ["zh-Hans": "其他额度授予", "zh-Hant": "其他額度授予", "ja": "その他のクレジット付与"]),
            ("claudeplatform", "This month (UTC)", ["zh-Hans": "本月 (UTC)", "zh-Hant": "本月 (UTC)", "ja": "今月 (UTC)"]),
            ("claude", "Monthly cap", ["zh-Hans": "每月上限", "zh-Hant": "每月上限", "ja": "月間上限"]),
        ]
        for (provider, label, translations) in expected {
            #expect(ProviderDetailLocalization.localized(label, providerID: provider, locale: Locale(identifier: "en")) == label)
            for (language, value) in translations {
                let localized = ProviderDetailLocalization.localized(
                    label, providerID: provider, locale: Locale(identifier: language))
                #expect(localized != label, "\(provider) \(label) \(language) must be translated")
                // Labels this release introduced have pinned translations; older shared labels only need a translation.
                if ["Workspace balance", "Member limit", "Runs this month", "Pending debit", "Other credit grants",
                    "Monthly cap"].contains(label)
                {
                    #expect(localized == value, "\(provider) \(label) \(language)")
                }
            }
        }
        // A custom plugin's identical label stays verbatim.
        #expect(ProviderDetailLocalization.localized(
            "Pending debit", providerID: "my-plugin", locale: Locale(identifier: "zh-Hans")) == "Pending debit")
    }

    @Test func `Claude Platform grant names stay verbatim while the Billing row localizes`() {
        let zh = Locale(identifier: "zh-Hans")
        let grants = SyncProviderDetailSection(
            title: "Other credit grants",
            rows: [.init(label: "Balance", value: "$20.00 of $25.00 left", secondaryValue: "Expires Nov 15 (UTC)")])
        let context = ProviderDetailLocalization.rowContext(
            providerID: "claudeplatform", section: grants, row: grants.rows[0], index: 0)
        #expect(ProviderDetailLocalization.localized("Balance", providerID: "claudeplatform", context: context, locale: zh)
            == "Balance")
        let billing = SyncProviderDetailSection(
            title: "Billing", rows: [.init(label: "This month (UTC)", value: "$36.20")])
        let billingContext = ProviderDetailLocalization.rowContext(
            providerID: "claudeplatform", section: billing, row: billing.rows[0], index: 0)
        #expect(ProviderDetailLocalization.localized(
            "This month (UTC)", providerID: "claudeplatform", context: billingContext, locale: zh)
            == MobileLocalizedString.value("This month (UTC)", defaultValue: "This month (UTC)", locale: zh))
    }

    @Test func `Claude Platform values localize remaining amounts and UTC expiry days`() {
        let en = Locale(identifier: "en")
        let zh = Locale(identifier: "zh-Hans")
        let ja = Locale(identifier: "ja")
        #expect(ProviderDetailLocalization.localizedValue("$124.75 of $200.00 left", providerID: "claudeplatform", locale: en)
            == "$124.75 of $200.00 left")
        #expect(ProviderDetailLocalization.localizedValue("$124.75 of $200.00 left", providerID: "claudeplatform", locale: zh)
            == "剩余 $124.75（共 $200.00）")
        #expect(ProviderDetailLocalization.localizedValue("$124.75 of $200.00 left", providerID: "claudeplatform", locale: ja)
            == "残り $124.75 / $200.00")
        #expect(ProviderDetailLocalization.localizedValue("Expires Oct 28 (UTC)", providerID: "claudeplatform", locale: en)
            == "Expires Oct 28 (UTC)")
        #expect(ProviderDetailLocalization.localizedValue("Expires Oct 28, 2027 (UTC)", providerID: "claudeplatform", locale: en)
            == "Expires Oct 28, 2027 (UTC)")
        let zhExpiry = ProviderDetailLocalization.localizedValue("Expires Oct 28 (UTC)", providerID: "claudeplatform", locale: zh)
        #expect(zhExpiry.hasSuffix(" 到期 (UTC)"), "\(zhExpiry)")
        #expect(zhExpiry.contains("10月28日"), "\(zhExpiry)")
        let zhExpiryWithYear = ProviderDetailLocalization.localizedValue(
            "Expires Oct 28, 2027 (UTC)", providerID: "claudeplatform", locale: zh)
        #expect(zhExpiryWithYear.contains("2027"), "\(zhExpiryWithYear)")
        // The window description joins both fragments.
        let combined = ProviderDetailLocalization.localizedValue(
            "$124.75 of $200.00 left · Expires Oct 28 (UTC)", providerID: "claudeplatform", locale: zh)
        #expect(combined.hasPrefix("剩余 $124.75（共 $200.00） · "), "\(combined)")
        #expect(combined.hasSuffix(" 到期 (UTC)"), "\(combined)")
        // A year-free leap day keeps its day in every reader year and non-Gregorian system calendars.
        let leap = ProviderDetailLocalization.localizedValue("Expires Feb 29 (UTC)", providerID: "claudeplatform", locale: zh)
        #expect(leap.contains("2月29日"), "\(leap)")
        let hebrew = ProviderDetailLocalization.localizedValue(
            "Expires Oct 28 (UTC)", providerID: "claudeplatform", locale: Locale(identifier: "en_US@calendar=hebrew"))
        #expect(hebrew == "Expires Oct 28 (UTC)", "\(hebrew)")
        #expect(ProviderDetailLocalization.localizedValue("Unavailable", providerID: "claudeplatform", locale: zh) == "不可用")
        // Unknown shapes and dynamic text stay verbatim.
        #expect(ProviderDetailLocalization.localizedValue("Expires someday (UTC)", providerID: "claudeplatform", locale: zh)
            == "Expires someday (UTC)")
        #expect(ProviderDetailLocalization.localizedValue("$1 of $2 of $3 left", providerID: "claudeplatform", locale: zh)
            == "$1 of $2 of $3 left")
        #expect(ProviderDetailLocalization.localizedValue("$124.75 of $200.00 left", providerID: "my-plugin", locale: zh)
            == "$124.75 of $200.00 left")
    }

    @Test func `FLORA fixed notes localize and amounts stay verbatim`() {
        let zh = Locale(identifier: "zh-Hans")
        let ja = Locale(identifier: "ja")
        #expect(ProviderDetailLocalization.localizedValue("Workspace pool", providerID: "flora", locale: zh) == "工作区共享池")
        #expect(ProviderDetailLocalization.localizedValue("Your allowance", providerID: "flora", locale: ja) == "あなたの割当")
        #expect(ProviderDetailLocalization.localizedValue("All time", providerID: "flora", locale: zh) == "累计")
        #expect(ProviderDetailLocalization.localizedValue("Monthly", providerID: "flora", locale: zh)
            == MobileLocalizedString.value("Monthly", defaultValue: "Monthly", locale: zh))
        #expect(ProviderDetailLocalization.localizedValue("Needs billing permission", providerID: "flora", locale: zh)
            == "需要账单权限")
        #expect(ProviderDetailLocalization.localizedValue("Totals not computed; try again", providerID: "flora", locale: ja)
            == "合計が未計算です。再試行してください")
        #expect(ProviderDetailLocalization.localizedValue("Unavailable", providerID: "flora", locale: zh) == "不可用")
        #expect(ProviderDetailLocalization.localizedValue("-$2.00", providerID: "flora", locale: zh) == "-$2.00")
        #expect(ProviderDetailLocalization.localizedValue("1,234", providerID: "flora", locale: zh) == "1,234")
        #expect(ProviderDetailLocalization.localizedValue("$42.50", providerID: "fal", locale: zh) == "$42.50")
        #expect(ProviderDetailLocalization.localizedValue("$1.50", providerID: "parallel", locale: zh) == "$1.50")
    }

    @Test func `Claude Platform window labels localize without falling back to Extra usage`() {
        let zh = Locale(identifier: "zh-Hans")
        let ja = Locale(identifier: "ja")
        #expect(ProviderWindowLabel.localized("API credit", fallback: "Session", providerID: "claudeplatform", locale: zh)
            == "API 额度")
        #expect(ProviderWindowLabel.localized("Purchased credit", fallback: "Weekly", providerID: "claudeplatform", locale: ja)
            == "購入済みクレジット")
        #expect(ProviderWindowLabel.localized("API credit", fallback: "Session", providerID: "claudeplatform",
                                              locale: Locale(identifier: "en")) == "API credit")
    }
}
