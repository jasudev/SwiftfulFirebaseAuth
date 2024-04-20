//
//  SignInWithPhone.swift
//
//
//  Created by Vamsi Madduluri on 10/04/24.
//

import FirebaseAuth
import UIKit

public struct SignInWithPhoneResult {
    public let verificationID: String
}

/// A helper class that provides methods for phone authentication.
@MainActor
final class SignInWithPhoneHelper: NSObject {
    
    private var presentedViewController: UIViewController? = nil
    
    func startPhoneFlow(phoneNumber: String) async throws -> SignInWithPhoneResult {
        let verificationID = try await PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: self)
        return SignInWithPhoneResult(verificationID: verificationID)
    }

}

extension SignInWithPhoneHelper: AuthUIDelegate {

    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        viewControllerToPresent.modalPresentationStyle = .fullScreen
        viewControllerToPresent.present(viewControllerToPresent, animated: flag, completion: completion)
        presentedViewController = viewControllerToPresent
    }

    func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        presentedViewController?.dismiss(animated: flag, completion: completion)
    }
}