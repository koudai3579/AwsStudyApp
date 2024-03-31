import UIKit
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
        userImageView.isUserInteractionEnabled = true
        userImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(userImageTapped)))
        userImageView.layer.cornerRadius = 100
        userNameTextField.delegate = self
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
        
        let bucketName = AWSManager().bucketName
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
                print("画像のアップロードに失敗しました:  \(error.localizedDescription)")
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
    
    //全User情報を取得しidentityIdが一致するものを本ユーザー情報とする(※identityIdをキー検索するのが理想ではあるが不明)
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
        if (fileName == ""){return}
        let expression = AWSS3TransferUtilityDownloadExpression()
        let transferUtility = AWSS3TransferUtility.default()
        //バケット名およびファイル名を指定し一致する画像をダウンロード
        transferUtility.downloadData(fromBucket: AWSManager().bucketName, key: fileName, expression: expression) { (task, URL, data, error) in
            if let error = error {
                print("画像の取得に失敗しました：\(error)") //失敗する場合はコンソール側の設定も確かめる
            }
            DispatchQueue.main.async(execute: {
                if let data = data,let image = UIImage(data: data){
                    self.userImageView.image = image
                }
            })
        }
    }
    
}
