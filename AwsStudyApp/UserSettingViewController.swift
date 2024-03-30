import UIKit
import AWSMobileClient
import AWSCognitoIdentityProvider
import AWSDynamoDB
import AWSS3


class UserSettingViewController: UIViewController, UITextFieldDelegate, UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    
    var identityId: String! //画面遷移時に受け取る
    var credentialsProvider: AWSCognitoCredentialsProvider!
    var configuration: AWSServiceConfiguration!
    var userName:String!
    var useImageFileName:String!
    
    @IBOutlet weak var userImageView: UIImageView!
    @IBOutlet weak var userNameTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "プロフィール設定"
        // credentialsProvider,configurationを初期化しAWSサービスのデフォルト構成を設定
        credentialsProvider = AWSCognitoCredentialsProvider(
            regionType: .APNortheast1,
            identityPoolId: "ap-northeast-1:0ee33487-4892-49db-9ad4-ecbc02f2ba7a"
        )
        configuration = AWSServiceConfiguration(region:.APNortheast1,credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        userImageView.isUserInteractionEnabled = true
        userImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(userImageTapped)))
        userImageView.layer.cornerRadius = 100
        userNameTextField.delegate = self
        fetchUserName()
        fetchUserName()
    }
    
    //UserImageViweがタップされたらアルバムを開く
    @objc func userImageTapped() {
        let sourceType:UIImagePickerController.SourceType = .photoLibrary
        //カメラが利用可能かチェックする
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary){
            let cameraPicker = UIImagePickerController()
            cameraPicker.sourceType = sourceType
            cameraPicker.delegate = self
            cameraPicker.allowsEditing = false
            present(cameraPicker, animated: true, completion: nil)
        }
    }
    
    //UIImagePickerControllerで画像選択後の処理
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let image = info[.originalImage] as! UIImage
        userImageView.image = image
        self.dismiss(animated: true)
        SaveImageToAws(image: image)
    }
    
    //AWS_S3へ画像を保存
    private func SaveImageToAws(image: UIImage) {
        let credentialsProvider = AWSStaticCredentialsProvider(accessKey: "AKIA4A4MNQR7LZGM6WDZ", secretKey: "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")
        let configuration = AWSServiceConfiguration(region: .APNortheast1, credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        let bucketName = "amplify-awsstudyapp-dev-151305-deployment"
        let uuid = UUID().uuidString
        let fileName = "userImage/\(uuid).jpg" // AWS S3に保存される名前(/で区切ることでuserImageフォルダへデータを格納できる)
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {return}
        let transferUtility = AWSS3TransferUtility.default()
        let expression = AWSS3TransferUtilityUploadExpression()
        
        transferUtility.uploadData(
            imageData,
            bucket: bucketName,
            key: fileName,
            contentType: "image/jpeg",
            expression: expression,
            completionHandler: { (task, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        print("画像のアップロードに失敗しました: \(error.localizedDescription)")
                    } else {
                        // 画像がアップロードされた後に必要な処理
                        self.useImageFileName = fileName
                        self.SaveUserInfoToAWS()
                    }
                }
            }
        ).continueWith { (task) -> Any? in
            if let error = task.error {
                print("Error uploading image: \(error.localizedDescription)")
            }
            return nil
        }
    }
    
    //userNameTextFieldが変更される度→データベース情報を更新
    func textFieldDidChangeSelection(_ textField: UITextField) {
        SaveUserInfoToAWS()
    }
    
    //ユーザーネームおよびプロフィール画像のファイル名をAWS_dynamoDBへ保存
    private func SaveUserInfoToAWS(){
        let newUserName = self.userNameTextField.text ?? ""
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let user: User = User()
        user.cognitoId = self.identityId
        user.userName = newUserName
        user.useImageFileName = self.useImageFileName ?? ""
        //identityIdに紐づくユーザーデータを上書き保存
        dynamoDBObjectMapper.save(user, completionHandler: {(error:Error?) -> Void in
            if let error = error {
                print("データの保存に失敗しました:\(error)")
            }
        })
    }
    
    //全User情報を取得しidentityIdが一致するものを本ユーザーの名前とする(※identityIdをキー検索するのが理想ではあるが不明)
    private func fetchUserName() {
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let scanExpression = AWSDynamoDBScanExpression()
        
        // Userの部分は作成したModelのクラス名
        dynamoDBObjectMapper.scan(User.self, expression: scanExpression).continueWith() { (task:AWSTask<AWSDynamoDBPaginatedOutput>!) -> Void in
            
            guard let users = task.result?.items as? [User] else { return }
            if let error = task.error as NSError? {
                print("全User情報の取得に失敗しました: \(error)")
                return
            }
            print("全User情報の取得に成功しました: \(users)")
            DispatchQueue.main.async {
                for user in users{
                    //アプリで取得したidentityIdとデータベース上とで一致するものを探す
                    if (self.identityId == user.cognitoId){
                        self.userName = user.userName
                        self.useImageFileName = user.useImageFileName
                        self.userNameTextField.text = self.userName
                        self.fetchUserImageFromAWS(fileName: self.useImageFileName)
                    }
                }
            }
        }
    }
    
    //画面生成時にユーザーイメージをAWSから取得し表示
    private func fetchUserImageFromAWS(fileName:String){
        let credentialsProvider = AWSStaticCredentialsProvider(accessKey: "AKIA4A4MNQR7LZGM6WDZ", secretKey: "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")
        let configuration = AWSServiceConfiguration(region: .APNortheast1, credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        let bucketName = "amplify-awsstudyapp-dev-151305-deployment"
        let transferUtility = AWSS3TransferUtility.default()
        let expression = AWSS3TransferUtilityDownloadExpression()
        
        let downloadingFilePath = NSTemporaryDirectory().appending(fileName)
        
        print("downloadingFilePath:\(downloadingFilePath)")
        
        let downloadingFileURL = URL(fileURLWithPath: downloadingFilePath)
        
        print("downloadingFileURL:\(downloadingFileURL)")
        
        transferUtility.download(to: downloadingFileURL,bucket: bucketName,key:fileName,expression: expression) { (task, url, data, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("ユーザー画像(\(fileName))の取得に失敗しました: \(error.localizedDescription)") //現在ここで詰まっている
                } else if let data = data, let image = UIImage(data: data) {
                    // ダウンロードに成功した画像をアプリ内で表示
                    self.userImageView.image = image
                }
            }
        }
    }
    
}
