import OktaOidc
import OktaAuthNative
import OktaJWT

public struct AuthPackage2 {
    public init() {}
}

struct LoginInfo: Codable {
    var username: String
    var password: String
    var date: Date
    static let id: String = "OktaIDP"
    func data() -> Data {
        return try! JSONEncoder().encode(self)
    }
}

public class AuthenticationClient {
    
    var oidcStateManager: OktaOidcStateManager?
    var successStatus: OktaAuthStatusSuccess?
    var authStatus: OktaAuthStatus?
    var authError: OktaError?
    var urlString: String?
    public var user: String?
    public var password: String?
    public var successCallback: ((OktaAuthStatus) -> Void)?
    public var failureCallback: ((OktaError) -> Void)?
    public var logoutSuccessCallback: (() -> Void)?
    
    public static let shared = AuthenticationClient()
    
    public init(){}
    public init(user: String, password: String, urlString: String = "https://dev-60965666.okta.com"){
        self.urlString = urlString
        self.user = user
        self.password = password
        self.authStatus = nil
        self.authError = nil
    }
    
    
    
    // authenticate
    public func authenticate() {
        let authFromKeychainSuccessBlock: (OktaAuthStatus) -> Void = { status in
            
            self.authStatus = status
            self.successStatus = status as? OktaAuthStatusSuccess
            /**
             # Keychain - save credentials
             
                   On successful authentication, save credentials to keychain
             
             */
            if let username = self.user, let password = self.password {
                do {
                    
                    let credentials = LoginInfo(username: username, password: password, date: Date())
                    
                    try OktaOidcKeychain.set(
                        key: LoginInfo.id,
                        data: credentials.data()
                    )
                    
                    print("creating oidc client...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        guard let oidcClient = self.createOidcClient() else {
                            print("failed to create oidc client")
                            return
                        }
                        print("getting token...")
                        oidcClient.authenticate(withSessionToken: self.successStatus!.sessionToken!, callback: { [weak self] stateManager, error in
                            
                            if let stateManager = stateManager {
                                // this is where we can keep the access and id tokens
                                self?.oidcStateManager = stateManager
                                if let accessToken = stateManager.accessToken {
                                    print("token is:\(accessToken)")
                                    let options = [
                                      "issuer": "https://dev-60965666.okta.com/oauth2/default",
                                          "audience": "api://default"
                                    ] as [String: Any]

                                    let validator = OktaJWTValidator(options)
                                    do {
                                      let valid = try validator.isValid(accessToken)
                                      print("Valid: \(valid)")
                                    } catch let error {
                                      print("JWT Validation Error: \(error)")
                                    }
                                    self?.checkToken(accessToken)
                                }
                                
                            }
                            
                            if let success = self?.successCallback {
                                success(status)
                                return
                            }
                        })
                    }
                } catch let error {
                    print("Error: \(error)")
                }
            }
    
            self.authStatus = status
        }

        let authFromKeychainErrorBlock: (OktaError) -> Void = {  error in
            
            self.authError = error
            if let fail = self.failureCallback {
                return fail(error)
            }
        }
 
        /**
         # Keychain - check for stored credentials
         
                if credentials exist, check date, if date passes then Okta authenticate API
         
         */
        if let user = self.user, let password = self.password, let urlString = self.urlString, let url = URL(string: urlString) {
                OktaAuthSdk.authenticate(with: url,
                             username: user,
                             password: password,
                             onStatusChange: authFromKeychainSuccessBlock,
                             onError: authFromKeychainErrorBlock)
                   
        }
    }
    
    // check Token
    func checkToken(_ jwtString: String){
        let options = [
          "issuer": "https://dev-60965666.okta.com/oauth2/default",
          "audience": "{aud}" // More info below
        ] as [String: Any]

        let validator = OktaJWTValidator(options)
        do {
          let valid = try validator.isValid(jwtString)
          print("Valid: \(valid)")
        } catch let error {
          print("JWT Validation Error: \(error)")
        }
    }
    
    // check authentication
    func checkAuthentication() {
        let authFromKeychainSuccessBlock: (OktaAuthStatus) -> Void = { status in
            self.authStatus = status
        
            /**
             # Keychain - save credentials
             
                   On successful authentication, save credentials to keychain
             
             */
            if let username = self.user, let password = self.password {
                do {
                    
                    let credentials = LoginInfo(username: username, password: password, date: Date())
                    
                    try OktaOidcKeychain.set(
                        key: LoginInfo.id,
                        data: credentials.data()
                    )
                } catch let error {
                    print("Error: \(error)")
                }
            }
    
            
            if let success = self.successCallback {
                return success(status)
            }
        }

        let authFromKeychainErrorBlock: (OktaError) -> Void = {  error in
            self.authError = error
        }
 
        /**
         # Keychain - check for stored credentials
         
                if credentials exist, check date, if date passes then Okta authenticate API
         
         */
        do {
            let result: Data = try OktaOidcKeychain.get(key: LoginInfo.id)
            let loginInfo: LoginInfo = try JSONDecoder().decode(LoginInfo.self, from: result)

            let lastLoginDate = loginInfo.date
            let now = Date()
            if let lastAccessPlus1Day = Calendar.current.date(byAdding: .day, value: 1, to: lastLoginDate), now < lastAccessPlus1Day, let authURLString = urlString, let authURL = URL(string: authURLString){
                
                self.user = loginInfo.username
                self.password = loginInfo.password
                OktaAuthSdk.authenticate(with: authURL,
                         username: loginInfo.username,
                         password: loginInfo.password,
                         onStatusChange: authFromKeychainSuccessBlock,
                         onError: authFromKeychainErrorBlock)
               
            }
        } catch let error {
            // log for now
            print("Error: \(error)")
        }
    }
    
    private var configForUITests: [String: String]? {
        let env = ProcessInfo.processInfo.environment
        guard let oktaURL = env["OKTA_URL"],
              let clientID = env["CLIENT_ID"],
              let redirectURI = env["REDIRECT_URI"],
              let logoutRedirectURI = env["LOGOUT_REDIRECT_URI"] else {
                return nil
        }
        return ["issuer": "\(oktaURL)/oauth2/default",
            "clientId": clientID,
            "redirectUri": redirectURI,
            "logoutRedirectUri": logoutRedirectURI,
            "scopes": "openid profile offline_access"
        ]
    }
    
    private func readTestConfig() -> OktaOidcConfig? {
        guard let _ = ProcessInfo.processInfo.environment["OKTA_URL"],
              let testConfig = configForUITests else {
                return nil
                
        }

        return try? OktaOidcConfig(with: testConfig)
    }
    
    private func createOidcClient() -> OktaOidc? {
        var oidcClient: OktaOidc?
        if let config = self.readTestConfig() {
            oidcClient = try? OktaOidc(configuration: config)
        } else {
            oidcClient = try? OktaOidc()
        }

        return oidcClient
    }
    
    // logout - signOutOf Okta requires a UIiViewController reference
//    func logoutFromVC(_ viewController: UIViewController) {
//        if let oidcStateManager = self.oidcStateManager {
//            let oidcClient = self.createOidcClient()
//            oidcClient?.signOutOfOkta(oidcStateManager, from: viewController, callback: { [weak self] error in
//                if let error = error {
//                    print("Okta Error: \(error)")
//                } else {
//
//                    /**
//                     # Keychain - delete credentials
//
//                           On logout remove credentials from keychain
//
//                     */
//
//                    do {
//                        try OktaOidcKeychain.remove(key: LoginInfo.id)
//                        try oidcStateManager.removeFromSecureStorage()
//                    } catch let error {
//                        print("Keychain Error: \(error)")
//                    }
//
//                    self?.oidcStateManager = nil
//                    // assume status changes to act on logged out state
//                    if let success = self!.logoutSuccessCallback {
//                        success()
//                    }
//                }
//            })
//        }
//    }
}
