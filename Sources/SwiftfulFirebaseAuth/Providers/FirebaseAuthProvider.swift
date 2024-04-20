//
//  FirebaseAuthProvider.swift
//
//
//  Created by Nick Sarno on 10/25/23.
//

import Foundation
import FirebaseAuth

struct FirebaseAuthProvider: AuthProvider {
    
    func getAuthenticatedUser() -> UserAuthInfo? {
        if let currentUser = Auth.auth().currentUser {
            return UserAuthInfo(user: currentUser)
        } else {
            return nil
        }
    }
    
    @MainActor
    func authenticationDidChangeStream() -> AsyncStream<UserAuthInfo?> {
        AsyncStream { continuation in
            Auth.auth().addStateDidChangeListener { _, currentUser in
                if let currentUser {
                    let user = UserAuthInfo(user: currentUser)
                    continuation.yield(user)
                } else {
                    continuation.yield(nil)
                }
            }
        }
    }
    
    @MainActor
    func authenticateUser_Apple() async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        let helper = SignInWithAppleHelper()
        
        // Sign in to Apple account
        for try await appleResponse in helper.startSignInWithAppleFlow() {
            
            // Convert Apple Auth to Firebase credential
            let credential = OAuthProvider.credential(
                withProviderID: AuthProviderOption.apple.rawValue,
                idToken: appleResponse.token,
                rawNonce: appleResponse.nonce
            )
            
            // Sign in to Firebase
            let authDataResult = try await signIn(credential: credential)
            
            var firebaserUser = authDataResult.user
            
            // Determines if this is the first time this user is being authenticated
            let isNewUser = authDataResult.additionalUserInfo?.isNewUser ?? true
            
            if isNewUser {
                // Update Firebase user profile with info from Apple account
                if let updatedUser = try await updateUserProfile(
                    displayName: appleResponse.displayName,
                    firstName: appleResponse.firstName,
                    lastName: appleResponse.lastName,
                    photoUrl: nil
                ) {
                    firebaserUser = updatedUser
                }
            }
            
            // Convert to generic type
            let user = UserAuthInfo(user: firebaserUser)
            
            return (user, isNewUser)
        }
        
        // Should never occur - only would occur if startSignInWithAppleFlow() completed without yielding a result (success or error)
        throw AuthError.noResponse
    }
    
    @MainActor
    func authenticateUser_Google(GIDClientID: String) async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        let helper = SignInWithGoogleHelper(GIDClientID: GIDClientID)
        
        // Sign in to Google account
        let googleResponse = try await helper.signIn()
        
        // Convert Google Auth to Firebase credential
        let credential = GoogleAuthProvider.credential(withIDToken: googleResponse.idToken, accessToken: googleResponse.accessToken)
        
        // Sign in to Firebase
        let authDataResult = try await signIn(credential: credential)
        
        var firebaserUser = authDataResult.user
        
        // Determines if this is the first time this user is being authenticated
        let isNewUser = authDataResult.additionalUserInfo?.isNewUser ?? true
        
        if isNewUser {
            // Update Firebase user profile with info from Google account
            if let updatedUser = try await updateUserProfile(
                displayName: googleResponse.displayName,
                firstName: googleResponse.firstName,
                lastName: googleResponse.lastName,
                photoUrl: googleResponse.profileImageUrl
            ) {
                firebaserUser = updatedUser
            }
        }
        
        // Convert to generic type
        let user = UserAuthInfo(user: firebaserUser)
        
        return (user, isNewUser)
    }
    
    @MainActor
    func authenticateUser_PhoneNumber(phoneNumber: String, verificationCode: String? = nil) async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        let helper = SignInWithPhoneHelper()
        
        let verificationId = try await helper.startPhoneFlow(phoneNumber: phoneNumber)
        print("GOT ID?")
        print(verificationId)
        // Authenticate with phone number
//        for try await phoneResponse in helper.startPhoneAuthFlow(phoneNumber: phoneNumber) {
//            switch phoneResponse.status {
//            case .sendingCode:
//                break
//            case .codeSent:
//                let verificationID = phoneResponse.verificationID
//                UserDefaults.standard.set(verificationID, forKey: "authVerificationID")
//                break
//            case .error(let error):
//                throw error
//            }
//        }
        
        // If verification code is provided, proceed with authentication
//        if let code = verificationCode {
//            guard let verificationID = UserDefaults.standard.string(forKey: "authVerificationID") else {
//                throw AuthError.verificationIDNotFound
//            }
//            
//            let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: code)
//            let authDataResult = try await signIn(credential: credential)
//            let firebaseUser = authDataResult.user
//            let isNewUser = authDataResult.additionalUserInfo?.isNewUser ?? true
//            
//            return (UserAuthInfo(user: firebaseUser), isNewUser)
//        }
        print("END")
        throw AuthError.noResponse
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.userNotFound
        }
        
        try await user.delete()
    }
    
    // MARK: PRIVATE
    
    
    private func signIn(credential: AuthCredential) async throws -> AuthDataResult {
        try await Auth.auth().signIn(with: credential)
    }
    
    private func updateUserProfile(displayName: String?, firstName: String?, lastName: String?, photoUrl: URL?) async throws -> User? {
        let request = Auth.auth().currentUser?.createProfileChangeRequest()
        
        var didMakeChanges: Bool = false
        if let displayName {
            request?.displayName = displayName
            didMakeChanges = true
        }
        
        if let firstName {
            UserDefaults.auth.firstName = firstName
        }
        
        if let lastName {
            UserDefaults.auth.lastName = lastName
        }
        
        if let photoUrl {
            request?.photoURL = photoUrl
            didMakeChanges = true
        }
        
        if didMakeChanges {
            try await request?.commitChanges()
        }
        
        return Auth.auth().currentUser
    }
    
    
    private enum AuthError: LocalizedError {
        case noResponse
        case userNotFound
        case verificationCodeNotFound
        case verificationIDNotFound
        
        var errorDescription: String? {
            switch self {
            case .noResponse:
                return "Bad response."
            case .userNotFound:
                return "Current user not found."
            case .verificationCodeNotFound:
                return "Verification code not found."
            case .verificationIDNotFound:
                return "Verification ID not found."
            }
        }
    }
    
}

extension UserDefaults {
    
    static let auth = UserDefaults(suiteName: "auth_defaults")!
    
    func reset() {
        firstName = nil
        lastName = nil
    }
    
    var firstName: String? {
        get {
            self.value(forKey: "first_name") as? String
        }
        set {
            self.setValue(newValue, forKey: "first_name")
        }
    }
    
    var lastName: String? {
        get {
            self.value(forKey: "last_name") as? String
        }
        set {
            self.setValue(newValue, forKey: "last_name")
        }
    }
}
