import AWSS3
class AWSManager {

    //(メモ)セキュリティのためキーは伏せており、AmplityConfigフォルダはGit管理から外している
    // AWSのキーや設定値(公開しないように注意！)
    let accessKey = "ACCESSKEY"
    let secretKey = "SECREATKEY"
    let bucketName = "BUCKETNAME"
    let identityPoolId = "IDENTITY_POOLID"
    let region = AWSRegionType.APNortheast1

    // AWS初期化処理(※Keyはコンソールで作成できsecretKeyは作成時しか参照できない)
    func initializeAWS() {
        let credentialsProvider = AWSStaticCredentialsProvider(accessKey: accessKey, secretKey: secretKey)
        let configuration = AWSServiceConfiguration(region: region, credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
    }
}
