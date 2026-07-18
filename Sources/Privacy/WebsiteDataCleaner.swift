import Foundation
import WebKit

enum WebsiteDataCleaner {
    @MainActor
    static func clearBrowsingData(
        in store: WKWebsiteDataStore? = nil,
        includingCookies: Bool = true,
        includingCache: Bool = true,
        includingLocalStorage: Bool = true
    ) async {
        var types = Set<String>()
        if includingCookies {
            types.insert(WKWebsiteDataTypeCookies)
        }
        if includingCache {
            types.insert(WKWebsiteDataTypeDiskCache)
            types.insert(WKWebsiteDataTypeMemoryCache)
        }
        if includingLocalStorage {
            types.insert(WKWebsiteDataTypeLocalStorage)
            types.insert(WKWebsiteDataTypeSessionStorage)
            types.insert(WKWebsiteDataTypeIndexedDBDatabases)
            types.insert(WKWebsiteDataTypeWebSQLDatabases)
        }
        guard !types.isEmpty else { return }

        let dataStore = store ?? .default()
        let records = await dataStore.dataRecords(ofTypes: types)
        await dataStore.removeData(ofTypes: types, for: records)
    }
}
