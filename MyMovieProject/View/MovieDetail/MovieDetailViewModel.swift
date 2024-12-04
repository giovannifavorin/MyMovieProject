import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftData

@MainActor
class MovieDetailViewModel : ObservableObject {
    let movieID : Int
    var modelContext : ModelContext?
    
    let db = Firestore.firestore()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var comments : [Comment] = []
    @Published var comment : String = ""
    @Published var likes : Int = 0
    @Published var didUserLiked : Bool = false
    @Published var waiting : Bool = false
    @Published var movieDetail: MovieDetail?
    @Published var showAlertLogin : Bool = false
    @Published var goLoginView : Bool = false
    @Published var loginAlertTitle : String = ""
    
    // swift data
    @Published var favoriteManager : FavoriteManager? = nil
    @Published var isFavorited : Bool = false
    private let api = MovieApi()
    
    init(movieID: Int) {
        self.movieID = movieID
    }
    
    func config (_ modelContext : ModelContext) {
        self.modelContext = modelContext
        self.favoriteManager = FavoriteManager(movieID: movieID, userID: getCurrentUser().1)
    }
    
    func fetchComments () async  {
        var comments: [Comment] = []
        
        do {
            let argument = try await db.collection("comment").getDocuments()
            for document in argument.documents {
                let data = document.data()
                let content = data["content"] as! String
                let movieID = data["movieID"] as! Int
                let username = data["username"] as! String
                
                if movieID == self.movieID {
                    comments.append(Comment(title: content, moovieID: movieID, username: username))
                }
            }
        } catch {
            print("[ERROR] Couldn't fetch comment data: \(error)")
        }
        self.comments = comments
    }
    
    func saveComment (_ loginState : LoginStateService.LoginState) async {
        guard loginState == .LOGGED_IN else {
            self.loginAlertTitle = "You need to log in to comment this movie..."
            self.showAlertLogin = true
            return
        }
        
        self.waiting = true
        
        do {
            let userInfo = getCurrentUser()
            
            try await db.collection("comment").addDocument(data: [
                "content": self.comment,
                "id" : UUID().uuidString,
                "movieID": movieID,
                "userID": userInfo.1,
                "username": userInfo.0
            ])
            
            await fetchComments()
        } catch {
            print("[ERROR] Couldn't add document in database...")
        }
        self.waiting = false
        self.comment = ""
    }
    
    func getCurrentUser () -> (String, String) {
        let currentUser = Auth.auth().currentUser
        
        if let currentUser, let displayName = currentUser.displayName {
            return (displayName, currentUser.uid)
        }
        
        if let currentUser {
            return ("", currentUser.uid)
        }
        
        return ("", "")
    }
    
    func fetchLikes () async {
        do {
            let query = try await db.collection("movie")
                .whereField("id", isEqualTo: movieID.description)
                .getDocuments()
            
            guard let document = query.documents.first else {
                try await self.db.collection("movie").addDocument(data: [
                    "id" : self.movieID.description,
                    "usersThatLiked": [],
                ])
                self.likes = 0
                return
            }
            
            let data = document.data()
            if let usersThatLiked = data["usersThatLiked"] as? [String] {
                self.likes = usersThatLiked.count
                self.didUserLiked = usersThatLiked.contains(where: { string in string == self.getCurrentUser().1 })
            } else {
                print("[ERROR] The data type was actually other than String...")
            }
        } catch {
            print("[ERROR] Error fetching likes")
        }
    }
    
    func likeButtonPressed (_ loginState : LoginStateService.LoginState) {
        guard loginState == .LOGGED_IN else {
            self.loginAlertTitle = "You need to login to give this movie a like..."
            self.showAlertLogin = true
            return
        }
        
        Task {
            if self.waiting == true {
                return
            }
            
            if didUserLiked {
                await unlike()
            } else {
                await like()
            }
            
            await fetchLikes()
        }
    }
    
    func loginAlertButtonPressed () {
        self.goLoginView = true
    }
    
    func like () async {
        self.waiting = true
        let userID = getCurrentUser().1
        
        do {
            let snapshot = try await db.collection("movie")
                .whereField("id", isEqualTo: movieID.description)
                .getDocuments()
            
            guard let document = snapshot.documents.first else {
                print("[ERROR] 404 - Documento não encontrado")
                return
            }
            
            var userLikes = document.data()["usersThatLiked"] as? [String] ?? []
            userLikes.append(userID)
            
            try await document.reference.updateData([
                "usersThatLiked" :  userLikes
            ])
            
            print("[DEBUG] Documento atualizado com sucesso!")
        } catch {
            print("[ERROR] Erro na hora de dar like \(error.localizedDescription)")
        }
         
        self.waiting = false
    }
    
    func unlike () async {
        self.waiting = true
        let userID = self.getCurrentUser().1
        
        do {
            let snapshot = try await db.collection("movie")
                .whereField("id", isEqualTo: movieID.description)
                .getDocuments()
            
            guard let document = snapshot.documents.first else {
                print("[ERROR] 404 - Documento não encontrado")
                return
            }
            
            var usersThatLiked = document.data()["usersThatLiked"] as? [String] ?? []
            
            if let index = usersThatLiked.firstIndex(of: userID) {
                usersThatLiked.remove(at: index)
                
                try await document.reference.updateData([
                    "usersThatLiked" : usersThatLiked
                ])
            } else {
                print("[ERROR] Usuário não tinha dado like...")
            }
        } catch {
            print("[ERROR] Erro na hora de dar like \(error.localizedDescription)")
        }
        
        self.waiting = false
    }
    
    func fetchDetailMovie() async {
        let url = URL(string: "https://api.themoviedb.org/3/movie/\(movieID)")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "language", value: "en-US"),
        ]
        components.queryItems = components.queryItems.map { $0 + queryItems } ?? queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.allHTTPHeaderFields = [
            "accept": "application/json",
            "Authorization": "Bearer eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJkYWRkMTc3ZWFlZWJjM2M1M2ZjZmM2OGNmY2ZiMmJkMyIsIm5iZiI6MTcxMDc4NDA4Ni43MDg5OTk5LCJzdWIiOiI2NWY4N2U1NmUxOTRiMDAxNjNiZjQxODYiLCJzY29wZXMiOlsiYXBpX3JlYWQiXSwidmVyc2lvbiI6MX0.yMEfLcsm8uM6QgNiVq-TiNEvcDUWl3sqfxq2Vpe9V3E"
        ]

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decodedData = try JSONDecoder().decode(MovieDetail.self, from: data)
            self.movieDetail = decodedData
        } catch {
            print("[ERROR] Failed to fetch movie details: \(error)")
            self.errorMessage = "Failed to load movie details. Please try again."
        }
    }
    
    func onLoadingView (_ modelContext : ModelContext) {
        Task {
            await fetchComments()
            await fetchLikes()
            await fetchDetailMovie()
            config(modelContext)
            favoriteManager?.config(modelContext)
            
            do {
                if let isUserFavorited = try self.favoriteManager?.verifyIfUserFavorited() {
                    self.isFavorited = isUserFavorited
                }
            } catch {
                print("[ERROR] Error fetching favorites: \(error.localizedDescription)")
            }
        }
    }
    
    func favoriteButtonPressed () {
        if self.isFavorited == false {
            do {
                if let favorited = try favoriteManager?.favorite() {
                    self.isFavorited = favorited
                }
            } catch {
                print("[ERROR] Error favoriting: \(error.localizedDescription)")
            }
        } else {
            do {
                if let favorited = try favoriteManager?.unfavorite() {
                    self.isFavorited = favorited
                }
            } catch {
                print("[ERROR] Error unfavoriting: \(error.localizedDescription)")
            }
        }
    }
}
