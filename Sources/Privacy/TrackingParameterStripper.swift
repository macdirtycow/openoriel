import Foundation

/// Removes common analytics / ad attribution query parameters from URLs.
enum TrackingParameterStripper {
    private static let exactNames: Set<String> = [
        "fbclid", "gclid", "gclsrc", "dclid", "gbraid", "wbraid",
        "msclkid", "mc_cid", "mc_eid", "yclid",
        "igshid", "twclid", "li_fat_id",
        "vero_conv", "vero_id",
        "_ga", "_gl", "_hsenc", "_hsmi", "__hssc", "__hstc", "__hsfp",
        "mkt_tok", "oly_anon_id", "oly_enc_id",
        "rb_clickid", "s_kwcid", "sscid", "ttclid",
        "wickedid", "ref_src", "ref_url"
    ]

    private static let prefixes: [String] = [
        "utm_", "mtm_", "pk_", "piwik_", "hsa_"
    ]

    /// Returns a cleaned URL when tracking params were removed.
    static func strip(_ url: URL, enabled: Bool = true) -> (url: URL, didStrip: Bool) {
        guard enabled else { return (url, false) }
        guard !URLParser.isStartPage(url) else { return (url, false) }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return (url, false)
        }
        guard let items = components.queryItems, !items.isEmpty else {
            return (url, false)
        }

        let kept = items.filter { item in
            let name = item.name.lowercased()
            if exactNames.contains(name) { return false }
            if prefixes.contains(where: { name.hasPrefix($0) }) { return false }
            return true
        }

        guard kept.count != items.count else { return (url, false) }
        components.queryItems = kept.isEmpty ? nil : kept
        if components.queryItems?.isEmpty == true {
            components.queryItems = nil
            components.query = nil
        }
        guard let cleaned = components.url else { return (url, false) }
        return (cleaned, true)
    }
}
