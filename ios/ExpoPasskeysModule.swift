import AuthenticationServices
import ExpoModulesCore

public class ExpoPasskeysModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ExpoPasskeys")

    Function("isSupported") { () -> Bool in
      if #available(iOS 15.0, *) {
        return true
      } else {
        return false
      }
    }

    Function("isAutoFillAvailable") { () -> Bool in
      return false
    }

    AsyncFunction("get", getPasskey)

    AsyncFunction("create", createPasskey)

  }
}

private func prepareCrossPlatformAuthorizationRequest(challenge: Data,
                                                      userId: Data,
                                                      request: PublicKeyCredentialCreationOptions) -> ASAuthorizationSecurityKeyPublicKeyCredentialAssertionRequest {

  let securityKeyCredentialProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: request.rp.id!)


  let securityKeyRegistrationRequest =
      securityKeyCredentialProvider.createCredentialRegistrationRequest(challenge: challenge!,
                                                                        displayName: displayName!,
                                                                        name: username!,
                                                                        userID: userId!)

  // Set request options to the Security Key provider
  securityKeyRegistrationRequest.credentialParameters = request.pubKeyCredParams

  if let residentCredPref = self.attestationOptionsResponse?.publicKey.authenticatorSelection?.residentKey {
      securityKeyRegistrationRequest.residentKeyPreference = residentKeyPreference(residentCredPref)
  }

  if let userVerificationPref = self.attestationOptionsResponse?.publicKey.authenticatorSelection?.userVerification {
      securityKeyRegistrationRequest.userVerificationPreference = userVerificationPreference(userVerificationPref)
  }

  if let rpAttestationPref = self.attestationOptionsResponse?.publicKey.attestation {
      securityKeyRegistrationRequest.attestationPreference = attestationStatementPreference(rpAttestationPref)
  }

  if let excludedCredentials = self.attestationOptionsResponse?.publicKey.excludeCredentials {
      if !excludedCredentials.isEmpty {
          securityKeyRegistrationRequest.excludedCredentials = credentialAttestationDescriptor(credentials: excludedCredentials)!
      }
  }


  return securityKeyRegistrationRequest

}

private func preparePlatformAuthorizationRequest(challenge: Data,
                                                 userId: Data,
                                                 request: PublicKeyCredentialCreationOptions) -> ASAuthorizationPlatformPublicKeyCredentialAssertionRequest {
  let platformKeyPlatformCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier:  request.rp.id!)

  let platformKeyRegistrationRequest =
      platformKeyCredentialProvider.createCredentialRegistrationRequest(challenge: challenge!,
                                                                        displayName: displayName!,
                                                                        name: username!,
                                                                        userID: userId!)

  return platformKeyRegistrationRequest
}

private func createPasskey(request: PublicKeyCredentialCreationOptions) -> PublicKeyCredentialCreationResponse {
    if !self.isSupported {
      throw NotSupportedException()
    }

    guard let challengeData: Data = Data(base64URLEncoded: request.challenge!) else {
      throw InvalidChallengeException()
    }

    if !request.user.id.isEmpty {
      throw MissingUserIdException()
    }

    guard let userId: Data = Data(base64URLEncoded: request.user.id!) else {
      throw InvalidUserIdException()
    }

    let authController: ASAuthorizationController;
    let securityKeyRegistrationRequest: ASAuthorizationSecurityKeyPublicKeyCredentialAssertionRequest? 
    let platformKeyRegistrationRequest: ASAuthorizationPlatformPublicKeyCredentialAssertionRequest?

    // - AuthenticatorAttachment.crossPlatform indicates that a security key should be used
    // TODO: use the helper on the Authenticator Attachment enum?
    if let isSecurityKey: Bool = request.authenticatorSelection.authenticatorAttachment == AuthenticatorAttachment.crossPlatform {
      securityKeyRegistrationRequest = prepareCrossPlatformAuthorizationRequest(challenge: challengeData,
                                                                                userId: userId,
                                                                                request: request
      )
    } else {
      platformKeyRegistrationRequest = preparePlatformAuthorizationRequest(challenge: challengeData,
                                                                           userId: userId,
                                                                           request: request)
    }

    // Set up a PasskeyDelegate instance with a callback function
    self.passKeyDelegate = preparePasskeyDelegate()

    if let passKeyDelegate = self.passKeyDelegate {
      // Perform the authorization request
      passKeyDelegate.performAuthForController(controller: authController);
    }
}

private func getPasskey(request: PublicKeyCredentialRequestOptions) -> PublicKeyCredentialRequestResponse {


}

// ! adapted from https://github.com/f-23/react-native-passkey/blob/fdcf7cf297debb247ada6317337767072158629c/ios/Passkey.swift#L138C55-L138C55
func handleASAuthorizationError(error: Error) -> PassKeyError {
  let errorCode = (error as NSError).code;
  switch errorCode {
    case 1001:
      throw UserCancelledException()
    case 1004:
      throw PasskeyRequestFailedException()
    case 4004:
      throw NotConfiguredException()
    default:
      throw UnknownException()
  }
}

private func preparePasskeyDelegate() {
  return PasskeyDelegate { error, result in
        if (error != nil) {
          handleASAuthorizationError(error: error!);
        }

        // Check if the result object contains a valid registration result
        if let registrationResult = result?.registrationResult {
          // Return a NSDictionary instance with the received authorization data
          let authResponse: NSDictionary = [
            "rawAttestationObject": registrationResult.rawAttestationObject.base64EncodedString(),
            "rawClientDataJSON": registrationResult.rawClientDataJSON.base64EncodedString()
          ];

          let authResult: NSDictionary = [
            "credentialID": registrationResult.credentialID.base64EncodedString(),
            "response": authResponse
          ]
          return authResult
        } else {
          throw PasskeyRequestFailedException()
        }
      }

}

// - preferences for security keys


// // Parse the relying party's attestation statement preference response and return a ASAuthorizationPublicKeyCredentialAttestationKind
// // Acceptable values: direct, indirect, or enterprise
// func attestationStatementPreference(_ rpAttestationStatementPreference: String) -> ASAuthorizationPublicKeyCredentialAttestationKind {
//     switch rpAttestationStatementPreference {
//         case "direct":
//             return ASAuthorizationPublicKeyCredentialAttestationKind.direct
//         case "indirect":
//             return ASAuthorizationPublicKeyCredentialAttestationKind.indirect
//         case "enterprise":
//             return ASAuthorizationPublicKeyCredentialAttestationKind.enterprise
//         default:
//             return ASAuthorizationPublicKeyCredentialAttestationKind.direct
//     }
// }

// // Parse the relying party user verification preference response and return a ASAuthorizationPublicKeyCredentialUserVerificationPreference
// // Acceptable UV preferences: discouraged, preferred, or required
// func userVerificationPreference(_ userVerificationPreference: String) -> ASAuthorizationPublicKeyCredentialUserVerificationPreference {
//   switch userVerificationPreference {
//       case "discouraged":
//           return ASAuthorizationPublicKeyCredentialUserVerificationPreference.discouraged
//       case "preferred":
//           return ASAuthorizationPublicKeyCredentialUserVerificationPreference.preferred
//       case "required":
//           return ASAuthorizationPublicKeyCredentialUserVerificationPreference.required
//       default:
//           return ASAuthorizationPublicKeyCredentialUserVerificationPreference.preferred
//   }
// }

// // Parse the relying party's resident credential (aka "discoverable credential") preference response and return a ASAuthorizationPublicKeyCredentialResidentKeyPreference
// // Acceptable UV preferences: discouraged, preferred, or required
// func residentKeyPreference(_ residentCredPreference: String) -> ASAuthorizationPublicKeyCredentialResidentKeyPreference {
//     switch residentCredPreference {
//         case "discouraged":
//             return ASAuthorizationPublicKeyCredentialResidentKeyPreference.discouraged
//         case "preferred":
//             return ASAuthorizationPublicKeyCredentialResidentKeyPreference.preferred
//         case "required":
//             return ASAuthorizationPublicKeyCredentialResidentKeyPreference.required
//         default:
//             return ASAuthorizationPublicKeyCredentialResidentKeyPreference.preferred
//     }
// }

// - Encoding helpers

extension String {
    // Encode a string to Base64 encoded string
    // Convert the string to data, then encode the data with base64EncodedString()
    func base64Encoded() -> String? {
        data(using: .utf8)?.base64EncodedString()
    }

    // Decode a Base64 string
    // Convert it to data, then create a string from the decoded data
    func base64Decoded() -> String? {
        guard let data = Data(base64Encoded: self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

public extension Data {
    init?(base64URLEncoded input: String) {
        var base64 = input
        base64 = base64.replacingOccurrences(of: "-", with: "+")
        base64 = base64.replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64 = base64.appending("=")
        }
        self.init(base64Encoded: base64)
    }

    func toBase64URLEncodedString() -> String {
        var result = self.base64EncodedString()
        result = result.replacingOccurrences(of: "+", with: "-")
        result = result.replacingOccurrences(of: "/", with: "_")
        result = result.replacingOccurrences(of: "=", with: "")
        return result
    }
}
