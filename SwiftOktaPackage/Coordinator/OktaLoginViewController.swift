//
//  OktaLoginViewController.swift
//  PepAuthKitExample
//
//  Created by infyuser on 26/04/22.
//
import UIKit
import OktaOidc
import OktaJWT

protocol OktaLoginViewControllerPotocol {
    func didFinishLogin(vc:OktaLoginViewController, loginStatus:LoginStatus)
}

final class OktaLoginViewController: UIViewController {

    var oktaOidc: OktaOidc?
    var stateManager: OktaOidcStateManager?
    var oktaLoginDelegate:OktaLoginViewControllerPotocol?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.view.backgroundColor = .lightGray
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.hidesBackButton = true
        self.view.backgroundColor = .red
        do {
            if let configForUITests = self.configForUITests {
                oktaOidc = try OktaOidc(configuration: OktaOidcConfig(with: configForUITests))
            } else {
                oktaOidc = try OktaOidc()
            }
        } catch let error {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
            return
        }
        
        oktaOidc?.signInWithBrowser(from: self, callback: { [weak self] stateManager, error in
            
            if let error = error {
                let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self?.present(alert, animated: true, completion: {
                
                    let status = LoginStatus(status: "Error")
                    self?.oktaLoginDelegate?.didFinishLogin(vc: self!, loginStatus: status)
                })
                
                return
            }
            self?.stateManager?.clear()
            self?.stateManager = stateManager
            self?.stateManager?.writeToSecureStorage()
            
            UserDefaults.standard.set(self?.stateManager?.accessToken, forKey: "accessToken")
            print("Access Token: ",self?.stateManager?.accessToken ?? "")
            print("Refresh Token: ",self?.stateManager?.refreshToken ?? "")
            
            //Get User Info
            self?.loadUserInfo()
            DispatchQueue.global().async {
                let options = ["iss": self?.oktaOidc?.configuration.issuer, "exp": "true"]
                let idTokenValidator = OktaJWTValidator(options)
                do {
                    _ = try idTokenValidator.isValid(self?.stateManager!.idToken ?? "0")
                } catch let verificationError {
                    var errorDescription = verificationError.localizedDescription
                    if let verificationError = verificationError as? OktaJWTVerificationError, let description = verificationError.errorDescription {
                        errorDescription = description
                    }
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "Error", message: errorDescription, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self?.present(alert, animated: true, completion: nil)
                    }
                }
            }
            
        })

    }
    
    private func loadUserInfo() {
        stateManager?.getUser { [weak self] response, error in
            DispatchQueue.main.async {
                guard let response = response else {
                    let alert = UIAlertController(title: "Error", message: error?.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self?.present(alert, animated: true, completion: nil)
                    return
                }
                print("Response : ",response)
                self?.updateUI(info: response)
            }
        }
    }
    
    private func updateUI(info: [String:Any]?) {
        let userName = info?["FirstName"] as? String ?? ""
        UserDefaults.standard.set(userName, forKey: "FirstName") //setObject
        
        let gpid = info?["gpid"] as? String ?? "0"
        UserDefaults.standard.set(gpid, forKey: "gpid") //setObject
        
        let status = LoginStatus(status: "Success")
        self.oktaLoginDelegate?.didFinishLogin(vc: self, loginStatus: status)
    }
}
// UI Tests
private extension OktaLoginViewController {
    var configForUITests: [String: String]? {
        let env = ProcessInfo.processInfo.environment
        guard let oktaURL = env["OKTA_URL"], oktaURL.count > 0,
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
}

