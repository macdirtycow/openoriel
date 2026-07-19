import Foundation

/// Browse category for Oriel Store — maps onto Firefox AMO + Chrome Web Store surfaces.
struct StoreBrowseCategory: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let kind: ExtensionStoreItem.Kind
    /// AMO `category` query value, if any.
    let firefoxCategory: String?
    /// Chrome Web Store category path segments after `/category/`, if any.
    let chromeCategoryPaths: [String]
    /// SF Symbol for chips.
    let systemImage: String

    static func categories(for kind: ExtensionStoreItem.Kind) -> [StoreBrowseCategory] {
        kind == .theme ? themeCategories : extensionCategories
    }

    static let featuredExtensions = StoreBrowseCategory(
        id: "featured-extensions",
        title: "Featured",
        kind: .extension,
        firefoxCategory: nil,
        chromeCategoryPaths: [
            "extensions",
            "extensions/make_chrome_yours/privacy",
            "extensions/productivity/tools",
            "extensions/productivity/communication",
            "extensions/lifestyle/shopping"
        ],
        systemImage: "star.fill"
    )

    static let featuredThemes = StoreBrowseCategory(
        id: "featured-themes",
        title: "Featured",
        kind: .theme,
        firefoxCategory: nil,
        chromeCategoryPaths: ["themes"],
        systemImage: "star.fill"
    )

    private static let extensionCategories: [StoreBrowseCategory] = [
        featuredExtensions,
        StoreBrowseCategory(
            id: "privacy-security",
            title: "Privacy & Security",
            kind: .extension,
            firefoxCategory: "privacy-security",
            chromeCategoryPaths: ["extensions/make_chrome_yours/privacy"],
            systemImage: "hand.raised.fill"
        ),
        StoreBrowseCategory(
            id: "appearance",
            title: "Appearance",
            kind: .extension,
            firefoxCategory: "appearance",
            chromeCategoryPaths: ["extensions/make_chrome_yours/accessibility"],
            systemImage: "paintbrush.fill"
        ),
        StoreBrowseCategory(
            id: "tabs",
            title: "Tabs",
            kind: .extension,
            firefoxCategory: "tabs",
            chromeCategoryPaths: ["extensions/productivity/workflow"],
            systemImage: "rectangle.on.rectangle"
        ),
        StoreBrowseCategory(
            id: "bookmarks",
            title: "Bookmarks",
            kind: .extension,
            firefoxCategory: "bookmarks",
            chromeCategoryPaths: ["extensions/productivity/tools"],
            systemImage: "bookmark.fill"
        ),
        StoreBrowseCategory(
            id: "search-tools",
            title: "Search",
            kind: .extension,
            firefoxCategory: "search-tools",
            chromeCategoryPaths: ["extensions/productivity/tools"],
            systemImage: "magnifyingglass"
        ),
        StoreBrowseCategory(
            id: "shopping",
            title: "Shopping",
            kind: .extension,
            firefoxCategory: "shopping",
            chromeCategoryPaths: ["extensions/lifestyle/shopping"],
            systemImage: "cart.fill"
        ),
        StoreBrowseCategory(
            id: "photos-music-videos",
            title: "Media",
            kind: .extension,
            firefoxCategory: "photos-music-videos",
            chromeCategoryPaths: ["extensions/lifestyle/art_lifestyle"],
            systemImage: "play.rectangle.fill"
        ),
        StoreBrowseCategory(
            id: "social-communication",
            title: "Social",
            kind: .extension,
            firefoxCategory: "social-communication",
            chromeCategoryPaths: ["extensions/productivity/communication"],
            systemImage: "bubble.left.and.bubble.right.fill"
        ),
        StoreBrowseCategory(
            id: "download-management",
            title: "Downloads",
            kind: .extension,
            firefoxCategory: "download-management",
            chromeCategoryPaths: ["extensions/productivity/tools"],
            systemImage: "arrow.down.circle.fill"
        ),
        StoreBrowseCategory(
            id: "games-entertainment",
            title: "Games",
            kind: .extension,
            firefoxCategory: "games-entertainment",
            chromeCategoryPaths: ["extensions/lifestyle/fun"],
            systemImage: "gamecontroller.fill"
        ),
        StoreBrowseCategory(
            id: "web-development",
            title: "Developer",
            kind: .extension,
            firefoxCategory: "web-development",
            chromeCategoryPaths: ["extensions/productivity/developer"],
            systemImage: "chevron.left.forwardslash.chevron.right"
        ),
        StoreBrowseCategory(
            id: "feeds-news-blogging",
            title: "News & Blogs",
            kind: .extension,
            firefoxCategory: "feeds-news-blogging",
            chromeCategoryPaths: ["extensions/lifestyle/news"],
            systemImage: "newspaper.fill"
        ),
        StoreBrowseCategory(
            id: "language-support",
            title: "Language",
            kind: .extension,
            firefoxCategory: "language-support",
            chromeCategoryPaths: ["extensions/productivity/education"],
            systemImage: "globe"
        ),
        StoreBrowseCategory(
            id: "alerts-updates",
            title: "Alerts",
            kind: .extension,
            firefoxCategory: "alerts-updates",
            chromeCategoryPaths: ["extensions/productivity/communication"],
            systemImage: "bell.fill"
        ),
        StoreBrowseCategory(
            id: "other-extensions",
            title: "Other",
            kind: .extension,
            firefoxCategory: "other",
            chromeCategoryPaths: ["extensions"],
            systemImage: "ellipsis.circle.fill"
        )
    ]

    private static let themeCategories: [StoreBrowseCategory] = [
        featuredThemes,
        StoreBrowseCategory(id: "theme-abstract", title: "Abstract", kind: .theme, firefoxCategory: "abstract", chromeCategoryPaths: ["themes"], systemImage: "square.on.circle"),
        StoreBrowseCategory(id: "theme-nature", title: "Nature", kind: .theme, firefoxCategory: "nature", chromeCategoryPaths: ["themes"], systemImage: "leaf.fill"),
        StoreBrowseCategory(id: "theme-solid", title: "Solid", kind: .theme, firefoxCategory: "solid", chromeCategoryPaths: ["themes"], systemImage: "paintpalette.fill"),
        StoreBrowseCategory(id: "theme-scenery", title: "Scenery", kind: .theme, firefoxCategory: "scenery", chromeCategoryPaths: ["themes"], systemImage: "mountain.2.fill"),
        StoreBrowseCategory(id: "theme-seasonal", title: "Seasonal", kind: .theme, firefoxCategory: "seasonal", chromeCategoryPaths: ["themes"], systemImage: "snowflake"),
        StoreBrowseCategory(id: "theme-holiday", title: "Holiday", kind: .theme, firefoxCategory: "holiday", chromeCategoryPaths: ["themes"], systemImage: "gift.fill"),
        StoreBrowseCategory(id: "theme-music", title: "Music", kind: .theme, firefoxCategory: "music", chromeCategoryPaths: ["themes"], systemImage: "music.note"),
        StoreBrowseCategory(id: "theme-fashion", title: "Fashion", kind: .theme, firefoxCategory: "fashion", chromeCategoryPaths: ["themes"], systemImage: "tshirt.fill"),
        StoreBrowseCategory(id: "theme-film-tv", title: "Film & TV", kind: .theme, firefoxCategory: "film-and-tv", chromeCategoryPaths: ["themes"], systemImage: "film.fill"),
        StoreBrowseCategory(id: "theme-sports", title: "Sports", kind: .theme, firefoxCategory: "sports", chromeCategoryPaths: ["themes"], systemImage: "sportscourt.fill"),
        StoreBrowseCategory(id: "theme-websites", title: "Websites", kind: .theme, firefoxCategory: "websites", chromeCategoryPaths: ["themes"], systemImage: "safari.fill"),
        StoreBrowseCategory(id: "theme-firefox", title: "Firefox", kind: .theme, firefoxCategory: "firefox", chromeCategoryPaths: ["themes"], systemImage: "flame.fill"),
        StoreBrowseCategory(id: "theme-other", title: "Other", kind: .theme, firefoxCategory: "other", chromeCategoryPaths: ["themes"], systemImage: "ellipsis.circle.fill")
    ]
}

enum StoreBrowseSort: String, CaseIterable, Identifiable, Sendable {
    case popular
    case rating
    case recent
    case relevance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .popular: return "Popular"
        case .rating: return "Top rated"
        case .recent: return "Newest"
        case .relevance: return "Relevance"
        }
    }

    /// AMO `sort` query value.
    var firefoxSort: String {
        switch self {
        case .popular: return "users"
        case .rating: return "rating"
        case .recent: return "created"
        case .relevance: return "relevance"
        }
    }

    static func options(forQuery query: String) -> [StoreBrowseSort] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return [.popular, .rating, .recent]
        }
        return [.relevance, .popular, .rating, .recent]
    }
}
