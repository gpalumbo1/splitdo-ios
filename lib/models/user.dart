class UserModel {
  final String uid;
  final String nickname;
  UserModel({required this.uid, required this.nickname});
  factory UserModel.fromMap(String id, Map<String, dynamic> data) => UserModel(
    uid: id,
    nickname: data['nickname'] ?? '',
  );
}
