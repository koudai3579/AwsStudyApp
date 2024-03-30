import UIKit
import AWSCore
import Amplify
import AmplifyPlugins

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.configure()
            print("Amplify configured with auth plugin")
        } catch {
            print("Failed to initialize Amplify with \(error)")
        }
        
        //↓AWS認証↓
        //※コンソールで作成できsecretKeyは作成時しか参照できない(公開しないように注意)
        let provider = AWSStaticCredentialsProvider(accessKey: "AKIA4A4MNQR7LZGM6WDZ", secretKey: "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")
        let configuration = AWSServiceConfiguration(
            region: AWSRegionType.APNortheast1,
            credentialsProvider: provider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
    
    
}

