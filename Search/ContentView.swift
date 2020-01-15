//
//  ContentView.swift
//  Search
//
//  Created by Sven A. Schmidt on 15/01/2020.
//  Copyright © 2020 finestructure. All rights reserved.
//

import Combine
import Foundation
import SwiftUI

struct Item: Decodable {
    let name: String
    let fullName: String
}

struct SearchResult: Decodable {
    let totalCount: Int
    let incompleteResults: Bool
    let items: [Item]
}

enum SearchError: Error {
    case publisherError
    case invalidServerResponse
    case decodingError(String)
}

let queryURL: (String) -> URL? = { query in
    guard !query.isEmpty else { return nil }
    return URL(string: "https://api.github.com/search/repositories?q=\(query)")
}

let dataTask: (URL) -> AnyPublisher<SearchResult, Error> = { url in
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return URLSession.shared.dataTaskPublisher(for: url)
        .tryMap { data, response -> Data in
            guard let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200 else {
                    throw SearchError.invalidServerResponse
            }
            return data
    }
    .decode(type: SearchResult.self, decoder: decoder)
    .mapError { err in
        SearchError.decodingError(err.localizedDescription)
    }
    .eraseToAnyPublisher()
}

struct ErrorMessage: Identifiable {
    var id: String { string }
    let string: String
}

func createRequestPipeline(
    debounceDelay: Double = 0.8,
    query: Published<String>.Publisher,
    errorHandler: @escaping (Error) -> Void,
    sink: @escaping (SearchResult) -> Void) -> AnyCancellable {

    let p = query
        .print("initial")
        .mapError { _ in SearchError.publisherError }
        .debounce(for: .seconds(debounceDelay), scheduler: RunLoop.main)
        .removeDuplicates()
        .compactMap(queryURL)
        .flatMap(dataTask)
        .receive(on: RunLoop.main)
        .catch { err -> Just<SearchResult> in
            errorHandler(err)
            return Just(SearchResult(totalCount: 0, incompleteResults: false, items: []))
        }
        .sink(receiveValue: sink)
    return p
}

final class GithubSearchRequest: ObservableObject {
    @Published var query: String = ""
    @Published var results = [String]()
    @Published var error: ErrorMessage? = nil

    private var requestPipeline: AnyCancellable? = nil

    init() {
        self.requestPipeline = createRequestPipeline(
            query: $query,
            errorHandler: { [weak self] err in
                print("err: \(err)")
                self?.error = ErrorMessage(string: err.localizedDescription)
            },
            sink: { [weak self] result in
                print("✅: \(result)")
                self?.results = result.items.map { $0.fullName }
        })
    }
}

struct ContentView: View {
    @ObservedObject var searchRequest = GithubSearchRequest()

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Type to search", text: $searchRequest.query)
                    .autocapitalization(.none)
            }
            .padding(EdgeInsets(top: 8, leading: 6, bottom: 8, trailing: 6))
            .foregroundColor(.secondary)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)

            List {
                ForEach(searchRequest.results, id: \.self) {
                    Text($0)
                }
            }
            .navigationBarTitle(Text("Search Github"))
        }
        .padding()
        .alert(item: $searchRequest.error) { error in
            Alert(title: Text("Error"), message: Text(error.string), dismissButton: .default(Text("OK")))
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
