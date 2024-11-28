import SwiftUI

struct OnboardingView: View {
    @StateObject var vm = OnboardingViewModel()
    
    var body: some View {
        VStack {
            Spacer()
            Text("Bem vindo!")
                .bold()
                .font(.title)
            
            Spacer()
            Spacer()
            Spacer()
            
            functionalityDescriber("Descubra novos filmes", description: "Procure filmes que te interessam na nossa lista", image: "movieclapper", color: .blue)
            functionalityDescriber("Adicione comentários", description: "Coloque as suas ideias sobre um filme para você ver depois", image: "text.page", color: .yellow)
            functionalityDescriber("Favorite filmes", description: "Marque os seus filmes favoritos com uma estrelinha!", image: "star.fill", color: .purple)
            
            Spacer()
            Spacer()
            Spacer()
            
            Button {
                vm.showInputUsername = true
            } label: {
                Text("Começar")
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding()
                    

            }
            
            Spacer()
        }
        .sheet(isPresented: $vm.showInputUsername) {
            InputUsernameView(goHome: $vm.goHome) {username in
                vm.finishInput(username)
            }
                .presentationDetents([.fraction(0.2)])
        }
        .navigationDestination(isPresented: $vm.goHome) {
            HomeView()
                .navigationBarBackButtonHidden()
        }
        
    }
    
    @ViewBuilder
    func functionalityDescriber (_ title : String, description : String, image : String, color : Color) -> some View {
        HStack {
            Image(systemName: image)
                .resizable()
                .scaledToFit()
                .frame(height: 30)
                .padding(.horizontal)
                .foregroundStyle(color)
            
            VStack (alignment: .leading) {
                Text(title)
                    .font(.headline)
                
                Text(description)
            }
            .frame(maxWidth: 250)
        }
        .padding()
    }
}

#Preview {
    OnboardingView()
}
