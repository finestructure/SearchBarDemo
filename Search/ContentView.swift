//
//  ContentView.swift
//  Search
//
//  Created by Sven A. Schmidt on 15/01/2020.
//  Copyright © 2020 finestructure. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @State var searchText = ""
    var results = ["A", "B", "C"]

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Type to search", text: $searchText)
            }
            .padding(EdgeInsets(top: 8, leading: 6, bottom: 8, trailing: 6))
            .foregroundColor(.secondary)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)

            List {
                ForEach(results.filter { $0.contains(searchText) || searchText == "" }, id: \.self) {
                    Text($0)
                }
            }
            .navigationBarTitle(Text("Search Github"))
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
