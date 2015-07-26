require 'artoo'
require 'httpclient'
require 'opencv'
include OpenCV

# サーバのURLを記載
SERVER_URL= "http://localhost:3000/"

# OpenCVを使ってキャプチャを取る
def capture(camera)
  image = camera.query
  mat = image.to_CvMat
  # 画像サイズを半分にする
  mat2 = mat.resize(CvSize.new(640,360))
  mat2.save('output.jpg')
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
    roomba.forward 1.0
  when "back" then
    roomba.backwards 1.0
  when "left" then
    roomba.nudge_left
  when "right" then
    roomba.nudge_right
  end
end

# マシンに接続されているカメラのうち, 1番めのカメラを利用する
camera = CvCapture.open(0)
httpclient = HTTPClient.new()
window = GUI::Window.new('camera')

#--------------------
connection :roomba, :adaptor => :roomba, :port => '/dev/tty.usbserial-A601HCTI'
device :roomba, :driver => :roomba, :connection => :roomba

work do
  roomba.safe_mode
  # 無限ループ Ctrl-Cで抜ける
  while true
    # サーバからコマンド取得する
    fetch_command(httpclient)
    p "#{Time.now}"
    # カメラから画像をキャプチャする
    out_path = capture(camera)
    # サーバに画像を送信する
    post_image(out_path, httpclient)
    # 0.5スリープして再びループ処理する
    sleep(0.5)
  end
end