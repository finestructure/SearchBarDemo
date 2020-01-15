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
    case invalidURL
    case invalidServerResponse
    case decodingError
}

let queryURL: (String) -> AnyPublisher<URL, Error> = { query in
    Just(query)
        .tryMap { query -> URL in
            guard let url = URL(string: "https://api.github.com/search/repositories?q=\(query)") else {
                throw SearchError.invalidURL
            }
            return url
    }
        .eraseToAnyPublisher()
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
    .mapError { _ in
        SearchError.decodingError
    }
    .eraseToAnyPublisher()
}

struct ErrorMessage: Identifiable {
    var id: String { string }
    let string: String
}

// https://stackoverflow.com/questions/56879734/convert-a-state-into-a-publisher
final class GithubSearchRequest: ObservableObject {
    @Published var query: String = "" {
        didSet { fetch() }
    }
    @Published var results = [String]()
    @Published var error: ErrorMessage? = nil

    var debounceDelay: Double

    private var currentRequest: AnyCancellable? = nil

    init(debounceDelay: Double = 0.5) {
        self.debounceDelay = debounceDelay
    }

    private func fetch() {
        self.error = nil
        let req = $query
            .print()
            .mapError { _ in SearchError.publisherError }
            .removeDuplicates()
            .debounce(for: .seconds(debounceDelay), scheduler: RunLoop.main)
            .flatMap(queryURL)
            .flatMap(dataTask)
            .receive(on: RunLoop.main)
            .mapError { err -> Error in
                print("err: \(err)")
                self.error = ErrorMessage(string: err.localizedDescription)
                return err
            }
            .replaceError(with: SearchResult(totalCount: 0, incompleteResults: false, items: []))
            .sink(receiveCompletion: { result in
                switch result {
                    case .finished:
                        break
                    case let .failure(error):
                        print("error: \(error.localizedDescription)")
                }
            }, receiveValue: { value in
                print(value)
                self.results = value.items.map { $0.fullName }
            })
        currentRequest = req
    }
}

struct ContentView: View {
    @ObservedObject var ghSearch = GithubSearchRequest(debounceDelay: 0.8)

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Type to search", text: $ghSearch.query)
            }
            .padding(EdgeInsets(top: 8, leading: 6, bottom: 8, trailing: 6))
            .foregroundColor(.secondary)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)

            List {
                ForEach(ghSearch.results, id: \.self) {
                    Text($0)
                }
            }
            .navigationBarTitle(Text("Search Github"))
        }
        .padding()
        .alert(item: $ghSearch.error) { error in
            Alert(title: Text("Error"), message: Text(error.string), dismissButton: .default(Text("OK")))
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
