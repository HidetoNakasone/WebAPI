
require 'jwt'


# ペイロード部： やりとりしたい内容
payload = { 
  user_id: 111
}

# 秘密鍵を生成： 自分のみが知っている
rsa_private = OpenSSL::PKey::RSA.generate(2048)
# p rsa_private
# p '========================'

# 公開鍵を生成： 秘密鍵より作れる
rsa_public  = rsa_private.public_key
# p rsa_public
# p '========================'

# payloadを、rsa_private(秘密鍵)で暗号化
token = JWT.encode(payload, rsa_private, 'RS256')
p token
p token.to_s
p '========================'

# tokenを、rsa_public(公開鍵)で復号化
# decoded_token = JWT.decode(token, rsa_public, true, { algorithm: 'RS256' })
# p decoded_token
# p '========================'

# tokenを、rsa_private(秘密鍵)で復号化
decoded_token = JWT.decode(token, rsa_private, true, { algorithm: 'RS256' })
p decoded_token
p '========================'

__END__

秘密鍵 と 公開鍵 を作る(generateで勝手に作らせる)
秘密鍵 で 暗号化(encode) した 情報 は 公開鍵 で 復号化(decode) する。
(今回はRS256方式で変換する)
※秘密鍵でも複合できるっぽい。


WebAPIのトークンとして使用する場合・・・
秘密鍵 や 公開鍵 はサーバー外には出さない。

暗号化することで、もし通信を盗み見られても、公開鍵が無いので復号化できない。
ただ、トークンは絶対に盗まれないようにしないと。
正規ユーザーを装って、正しいトークンが送られると見分けがつかん。(サーバーからすれば同じ人)


サーバーは起動したら、まず秘密鍵を作る(公開鍵は要らない？？)

POST '/login' で入力データを受け取る。この時、もし正しかったら、データベースからのそのユーザーのIDを持ってきて、
それを秘密鍵を使って暗号化する！

暗号化した情報をトークンと呼んでる？？っぽい。

このトークンをクライアントに教えてあげて、
以降のリクエストでは、必ずトークンを付けるようにさせる！



