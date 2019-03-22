
require 'sinatra'
require 'sinatra/reloader'
require 'pg'
require 'rack/contrib'
require 'pry'
require 'jwt'


# Sinatraでjsonを受け取る為に記述
# curlの--dataはjsonになるっぽいぞ
use Rack::PostBodyContentTypeParser


# 秘密鍵を生成
# 以降、この秘密鍵で暗号化・復号化していく
# $rsa_private = OpenSSL::PKey::RSA.generate(2048)
$rsa_private = OpenSSL::PKey::RSA.generate(1000)


# PostgreSQLに接続
def db
  @db ||= PG.connect(
    dbname: 'todo'
  )
end


# 中身がnilじゃないかをチェックし、結果を配列で返す
def conv(key, item)
  unless item
    [false, "!!#{key.to_s} is not."]
  else
    [true, item]
  end
end


# 中身があると、trueを、無いなら[そのkeyの文字列]の配列を返す
def is_allcheck(array)
  res = []
  status = true

  array.each do |key, value|
    unless value[0]
      status = false
      res.push(key) 
    end
  end
  
  return res unless status
  return true
end


# ユーザー新規登録
post '/api/v1/users' do

  # 最終的に返すHash
  result = {'status' => 400, 'msg' => ''}

  # 欲しい情報
  wana = {'name' => nil, 'email' => nil, 'description' => nil, 'password' => nil}

  # 受け取り
  params.each{ |key, values| wana[key] = params[key] }

  # 中身があるか確認し、結果を配列として返す
  get_params = Hash[wana.map do |key, value|
    res = conv(key, value)
    [key, [res[0], res[1].to_s]]
  end]

  if is_allcheck(get_params) == true
    # データベースで検索して、重複がないか確認
    res = db.exec("select * from users where email = '#{params[:email]}';").to_a
    if res.length > 0
      result['status'] = 400
      result['msg'] = "そのメールアドレスは使用されています。"
    else
      db.exec("insert into users(name, description, email, password) values('#{params[:name]}', '#{params[:description]}', '#{params[:email]}', '#{params[:password]}');")
      result['status'] = 200
      result['msg'] = "ユーザー登録が成功しました"
    end
  else
    result['status'] = 400
    result['msg'] = "#{is_allcheck(get_params).join('と')}を入力してください"
  end
  
  result.to_json
end


# ユーザーログイン
post '/api/v1/users/login' do

  # 最終的に返すHash
  result = {'status' => 400, 'msg' => ''}

  # 欲しい情報
  wana = {'email' => nil, 'password' => nil}

  # 受け取り
  params.each{ |key, values| wana[key] = params[key] }

  # 中身があるか確認し、結果を配列として返す
  get_params = Hash[wana.map do |key, value|
    res = conv(key, value)
    [key, [res[0], res[1].to_s]]
  end]

  if is_allcheck(get_params) == true
    # データベースで検索して、一致しているかで分岐させる
    res = db.exec("select * from users where email = '#{params[:email]}' and password = '#{params[:password]}';").to_a
    if res.length > 0

      # トークンの生成
      payload = {user_id: res.first['id'].to_i}
      token = JWT.encode(payload, $rsa_private, 'RS256')

      result['status'] = 200
      result['msg'] = "access_token: '#{token}'"
    else
      result['status'] = 401
      result['msg'] = "認証に失敗しました"
    end

  else
    result['status'] = 400
    result['msg'] = "#{is_allcheck(get_params).join('と')}を入力してください"
  end
  
  result.to_json
end


# 自分のタスク一覧
get '/api/v1/todos' do

  # 最終的に返すHash
  result = {'status' => 400, 'msg' => ''}

  # p request.env.select.to_a.to_json

  i = 0
  token = ''
  request.env.select.size.times do
    if request.env.select.to_a[i][0] == "HTTP_AUTHORIZATION"
      token = request.env.select.to_a[i][1].to_s
    end
    i += 1
  end

  if token != ''
    begin
      infos = JWT.decode(token, $rsa_private, true, { algorithm: 'RS256' })
      user_id = infos.first['user_id']
    rescue => error
      p 'エラーが発生'
      result = {'status' => 401, 'msg' => 'トークンのエラーが発生'}
    end
  else
    result = {'status' => 401, 'msg' => 'ログインしてください'}
  end
  
  result = db.exec("select title, status from todos where user_id = #{user_id.to_i};").to_a if user_id

  result.to_json
end
