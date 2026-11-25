//
//  ContentView.swift
//  SimpleAPICall
//
//  Created by Paresh Thakor on 17/11/26.
//
import SwiftUI
import NetworkKit
struct ContentView: View {
    @State var posts: [ResponseDTO]?
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            
            if let posts {
                Text("I have \(posts.count) posts now!")
            }
        }
        .padding()
        .task {
            do {
                self.posts = try await NetworkManager.shared.postClient.execute(APIEndpoint.posts, as: [ResponseDTO].self)
                debugPrint("Response: ", posts ?? [])
            } catch {
                debugPrint("Error Message: ", error.localizedDescription)
            }
            
        }
    }
}

#Preview {
    ContentView()
}
