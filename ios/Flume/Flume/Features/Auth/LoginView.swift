import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var showingSignUp = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Flume")
                .font(.largeTitle.bold())

            VStack(spacing: 12) {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    #endif

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
            }
            .textFieldStyle(.roundedBorder)

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button {
                Task { await viewModel.signIn() }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.email.isEmpty || viewModel.password.isEmpty || viewModel.isLoading)

            Button("Create Account") {
                showingSignUp = true
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: 400)
        .sheet(isPresented: $showingSignUp) {
            SignUpView(viewModel: viewModel)
        }
    }
}
