import AWSS3
class AWSManager {

    // AWSのキーや設定値(公開しないように注意！)
    let accessKey = "AKIA4A4MNQR7LZGM6WDZ"
    let secretKey = "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"
    let bucketName = "amplify-awsstudyapp-dev-151305-deployment"
    let identityPoolId = "ap-northeast-1:0ee33487-4892-49db-9ad4-ecbc02f2ba7a"
    let region = AWSRegionType.APNortheast1

    // AWS初期化処理(※Keyはコンソールで作成できsecretKeyは作成時しか参照できない)
    func initializeAWS() {
        let credentialsProvider = AWSStaticCredentialsProvider(accessKey: accessKey, secretKey: secretKey)
        let configuration = AWSServiceConfiguration(region: region, credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
    }
}
