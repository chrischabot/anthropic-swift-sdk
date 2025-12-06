import Foundation

public struct Page<Item: Decodable & Sendable>: Decodable, Sendable {
    public let data: [Item]
    public let nextPageToken: String?
}

public struct PageSequence<Item: Decodable & Sendable>: AsyncSequence {
    public typealias Element = Item

    private let initialPage: Page<Item>
    private let fetch: @Sendable (String) async throws -> Page<Item>

    public init(initialPage: Page<Item>, fetch: @escaping @Sendable (String) async throws -> Page<Item>) {
        self.initialPage = initialPage
        self.fetch = fetch
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(currentPage: initialPage, fetch: fetch)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var currentPage: Page<Item>?
        private var fetch: @Sendable (String) async throws -> Page<Item>
        private var index = 0

        init(currentPage: Page<Item>, fetch: @escaping @Sendable (String) async throws -> Page<Item>) {
            self.currentPage = currentPage
            self.fetch = fetch
        }

        public mutating func next() async throws -> Item? {
            while true {
                guard let page = currentPage else { return nil }
                if index < page.data.count {
                    let item = page.data[index]
                    index += 1
                    return item
                }
                if let token = page.nextPageToken {
                    let nextPage = try await fetch(token)
                    currentPage = nextPage
                    index = 0
                    continue
                } else {
                    currentPage = nil
                    return nil
                }
            }
        }
    }
}
