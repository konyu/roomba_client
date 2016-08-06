# coding: utf-8
require 'httpclient'
require "open3"

# サーバのURLを記載
SERVER_URL= "http://192.168.3.4:3000/"
IMAGE_PATH= "tmp/pic.jpg"
# カメラモジュールのタイムラプスモードを使ってを使ってキャプチャを取る
def start_capture
  Open3.popen3("ps aux |grep raspistill") do |i, o, e, w|
    cnt = 0
    o.each do |line|
      p line
      cnt = cnt + 1
    end
    p cnt
    # grep して本体がpsコマンドと、grepコマンド以外にraspistillがあれば3になるはず
    return if cnt > 2
    fork do
      Process.setsid
      exit if fork
      p "CCCC"
      `raspistill -n -w 640 -h 480 -q 20 -o tmp/pic.jpg -tl 1000 -t 99999999 --thumb none 2>&1 & echo $!`
    end
  end
end

# 画像をサーバにポスト
def post_image(img_path, httpclient)
  res = httpclient.post(
          "#{SERVER_URL}images",
          {
            "image[img_path]" => "aaaa",
            "image[image]" => open(img_path,"r")
          }
        )
end

# サーバからコマンドをってくる
def fetch_command(httpclient)
  res = httpclient.get("#{SERVER_URL}commands/fetch_command")
  comm = res.content.strip
  
  case comm
  when "foward" then
  #  roomba.forward 1.0
  when "back" then
   # roomba.backwards 1.0
  when "left" then
   # roomba.nudge_left
  when "right" then
   # roomba.nudge_right
  end
  p comm
end

httpclient = HTTPClient.new()
start_capture

# 無限ループ Ctrl-Cで抜ける
while true
  # サーバからコマンド取得する
  fetch_command(httpclient)
  p "#{Time.now}"
  
  # サーバに画像を送信する
  post_image(IMAGE_PATH, httpclient)
  # 0.5スリープして再びループ処理する
  sleep(0.5)
end

