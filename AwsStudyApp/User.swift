import AWSDynamoDB

class User: AWSDynamoDBObjectModel, AWSDynamoDBModeling {

    @objc var cognitoId: String = ""
    @objc var userName: String = ""
    @objc var useImageFileName: String = ""

    class func dynamoDBTableName() -> String {
        return "user" // DyanmoDBに作成したテーブル名
    }

    class func hashKeyAttribute() -> String {
        return "cognitoId"
    }
}
