#!/bin/env ruby
require 'aws_include.rb'

# コマンドライン引数受取
require 'optparse'

# デフォルト値を設定する
config = {
    :reboot => 'on',
}

# 引数を解析する
OptionParser.new do |opts|
    begin
        # オプション情報を設定する
        opts = OptionParser.new
        opts.on('-i instance_id',
                '--instance-id instance_id',
                "EC2のInstance Idを指定") { 
            |v| config[:instance_id] = v 
        }
        opts.on('-n name',
                '--name name',
                "TagのName要素を指定") {
            |v| config[:name] = v
        }
        opts.on('-r reboot',
                '--reboot reboot',
                "on/off(default on) クローン元を再起動してImageを作成するか決定<offは非推奨>") {
            |v| config[:reboot] = v
        }

        opts.parse!(ARGV)

    rescue => e
        puts opts.help
        puts
        puts e.message
        exit 1
    end
end

if !config[:instance_id].nil? then
    input_instance_id = config[:instance_id]
elsif !config[:name].nil? then
    input_instance_id = get_instance_id(config[:name])
else
    input_instance_id  = input("クローン元のEC2インスタンスのidを入力して下さい : ")
end

reboot_flg = true
if config[:reboot] == "off" then
    reboot_flg = false
end

instance_data = get_instance_data(input_instance_id)

load_balancer_name = check_load_balancer(input_instance_id)
if load_balancer_name then
    if reboot_flg && deregister_instance_from_load_balancer(load_balancer_name, input_instance_id) then
        puts("指定したInstanceをLoad Balancer(" + load_balancer_name + ")から外しました")
    end
end

ami_id = create_image(input_instance_id, reboot_flg)
puts "AMI作成完了 : " + ami_id

instance_id = create_instance(ami_id, instance_data)
puts "新規Instance生成完了 : " + instance_id




