# coding: utf-8
require 'httpclient'
require "open3"
require 'serialport'

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


# Sends start mode
module Mode
  FULL = 132
  SAFE = 131
  START = 128
end

module Speed
  MAX = 500
  SLOW = 250
  NEG = (65536 - 250)
  ZERO = 0
end

module Direction
  STRAIGHT = 32768
  CLOCKWISE = 65535
  COUNTERCLOCKWISE = 1
end

def send_bytes(bytes)
  bytes = [bytes] unless bytes.respond_to?(:map)
  bytes.map!(&:chr)
  p "sending: #{bytes.inspect}"
  res = []
  bytes.each{|b| res << @sp.write(b) }
  p "returned: #{res.inspect}"
end

def start
  send_bytes(Mode::START)
  sleep 0.2
end

def full_mode
  start
  send_bytes(Mode::FULL)
  sleep 0.1
end

def init_roomba
  @sp = SerialPort.new('/dev/ttyAMA0', 115200, 8, 1, 0)
  full_mode
end

def split_bytes(num)
  [num >> 8, num & 255]
end

def drive(v, r, s = 0)
  vH,vL = split_bytes(v)
  rH,rL = split_bytes(r)
  send_bytes([137, vH, vL, rH, rL])
  sleep(s) if s > 0
end

def stop
  drive(Speed::ZERO, Direction::STRAIGHT)
end

def forward(seconds, velocity = Speed::SLOW)
  drive(velocity, Direction::STRAIGHT, seconds)
  stop if seconds > 0
end

def backwards(seconds)
  drive(Speed::NEG, Direction::STRAIGHT, seconds)
  stop if seconds > 0
end

def turn_left(seconds = 1)
  drive(Speed::SLOW, Direction::COUNTERCLOCKWISE, seconds)
  stop if seconds > 0
end

def turn_right(seconds = 1)
  drive(Speed::SLOW, Direction::CLOCKWISE, seconds)
  stop if seconds > 0
end

# サーバからコマンドをってくる
def fetch_command(httpclient)
  res = httpclient.get("#{SERVER_URL}commands/fetch_command")
  comm = res.content.strip

  case comm
  when "foward" then
    forward(0.5)
  when "back" then
    backwards(0.5)
  when "left" then
    turn_left(0.5)
  when "right" then
    turn_right(0.5)
  end
  p comm
end

httpclient = HTTPClient.new()
start_capture

init_roomba

# 無限ループ Ctrl-Cで抜ける
while true
  # サーバからコマンド取得する
  fetch_command(httpclient)
  p "#{Time.now}"
  
  # サーバに画像を送信する
  begin
    post_image(IMAGE_PATH, httpclient)
  rescue
    p "post error"
  end
  # 0.5スリープして再びループ処理する
  #sleep(0.5)
end

