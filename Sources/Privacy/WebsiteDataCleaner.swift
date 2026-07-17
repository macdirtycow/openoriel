import Foundation
import WebKit

enum WebsiteDataCleaner {
    static func clearBrowsingData(
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

        let store = WKWebsiteDataStore.default()
        let records = await store.dataRecords(ofTypes: types)
        await store.removeData(ofTypes: types, for: records)
    }
}
