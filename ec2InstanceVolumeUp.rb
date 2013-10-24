require 'rubygems'
require 'json'
require 'pp'

# コマンド実行
def exec_command(cmd, put_flg=true)
    if put_flg then
        puts cmd
    end
    return `#{cmd}`
end

# Instance 各データを取得
def get_instance_data(instance_id)
    result = JSON.parse(exec_command("aws ec2 describe-instances --instance-ids " + instance_id))
    return {
                "private_ip"=>result["Reservations"][0]["Instances"][0]["PrivateIpAddress"], 
                "availability_zone"=>result["Reservations"][0]["Instances"][0]["Placement"]["AvailabilityZone"],
                "volume_id"=>result["Reservations"][0]["Instances"][0]["BlockDeviceMappings"][0]["Ebs"]["VolumeId"],
                "device_name"=>result["Reservations"][0]["Instances"][0]["BlockDeviceMappings"][0]["DeviceName"]
            }
end

def get_volume_id(volume_id)
    result = JSON.parse(exec_command("aws ec2 describe-volumes --volume-ids " + volume_id))
    return {
                "size"=>result["Volumes"][0]["Size"] 
            }
end

def create_snapshot(volume_id)
    result = JSON.parse(exec_command("aws ec2 create-snapshot --volume-id " + volume_id))
    check_pend(result["SnapshotId"], "completed", 5)
    return result["SnapshotId"]
end

def create_volume(snapshot_id, size, availability_zone)
    result = JSON.parse(exec_command("aws ec2 create-volume --snapshot-id " + snapshot_id + " --size " + size + " --availability-zone " + availability_zone))
    check_pend(result["VolumeId"], "available", 5)
    return result["VolumeId"]
end

# ec2インスタンスをstart
def start_instance(instance_id)
    if get_instance_state(instance_id) != "running" then
        puts "instance starting\n"
        result = JSON.parse(exec_command("aws ec2 start-instances --instance-ids " + instance_id))
        check_pend(instance_id, "running")
    end
end

# ec2インスタンスをstop
def stop_instance(instance_id)
    if get_instance_state(instance_id) != "stopped" then
        puts "instance stopping\n"
        result = JSON.parse(exec_command("aws ec2 stop-instances --instance-ids " + instance_id))
        check_pend(instance_id, "stopped")
    end
end

# detach
def detach_volume(volume_id)
    puts "device detaching\n"
    result = JSON.parse(exec_command("aws ec2 detach-volume --volume-id " + volume_id))
    check_pend(volume_id, "available")
end

# attach
def attach_volume(volume_id, instance_id, device_name)
    puts "device attaching\n"
    result = JSON.parse(exec_command("aws ec2 attach-volume --volume-id " + volume_id + " --instance-id " + instance_id + " --device " + device_name))
    check_pend(volume_id, "in-use")
end

# penddingチェックメソッド
def check_pend(id, check_state, time=3)
    current_state = ""
    id_type = id.split("-")
    while current_state != check_state
        sleep time
        if id_type[0] == "i" then
            current_state = get_instance_state(id)
        elsif id_type[0] == "snap" then
            current_state = get_snapshot_state(id)
        elsif id_type[0] == "vol" then
            current_state = get_volume_state(id)
        end
        puts "."
    end
    print(current_state + "\n")
end

# Instance Stateを取得
def get_instance_state(instance_id)
    result = JSON.parse(exec_command("aws ec2 describe-instances --instance-ids " + instance_id, false))
    return result["Reservations"][0]["Instances"][0]["State"]["Name"]
end

# Snapshot Stateを取得
def get_snapshot_state(snapshot_id)
    result = JSON.parse(exec_command("aws ec2 describe-snapshots --snapshot-ids " + snapshot_id, false))
    return result["Snapshots"][0]["State"]
end

# Volume Stateを取得
def get_volume_state(volume_id)
    result = JSON.parse(exec_command("aws ec2 describe-volumes --volume-ids " + volume_id))
    return result["Volumes"][0]["State"]
end

# id受取
print("EC2インスタンスのidを入力して下さい : ")
input_id = STDIN.gets
print("対象サーバにrootログイン可能な秘密鍵を絶対パス指定して下さい : ")
key_file = STDIN.gets
input_id.chomp!
key_file.chomp!

instance_data = get_instance_data(input_id)
volume_data = get_volume_id(instance_data["volume_id"])
print("現在のVolumeSize : " + volume_data["size"].to_s + "GB\n")
print("変更後のVolumeのサイズを入力して下さい(GB) : ")
input_size = STDIN.gets
input_size.chomp!

if input_size.to_i <= volume_data["size"] then
    print("サイズを下げることは出来ません\n")
    exit(0)
end

ssh_str = "ssh -i " + key_file + " root@" + instance_data["private_ip"] + " "
# チェック用ファイル作成
exec_command(ssh_str + "touch ssh_chk.txt");

# dfコマンドで対象サーバのルートデバイスを取得
device_pos = exec_command(ssh_str + "df -x tmpfs | grep / | cut -d' ' -f1")

# Instanceストップ
stop_instance(input_id)

new_snapshot_id = create_snapshot(instance_data["volume_id"])
puts "Snapshot作成完了 : " + new_snapshot_id

new_volume_id = create_volume(new_snapshot_id, input_size, instance_data["availability_zone"])
puts "新規Volume作成完了 : " + new_volume_id

detach_volume(instance_data["volume_id"])
puts "旧Volume detach完了 : " + instance_data["volume_id"]

attach_volume(new_volume_id, input_id, instance_data["device_name"])
puts "新規Volume attach完了 : " + new_volume_id

# Instanceスタート
start_instance(input_id)

# リサイズ
exec_command(ssh_str + "resize2fs " + device_pos)

# ファイル存在チェック
response = exec_command(ssh_str + "cat ssh_chk.txt")
if response != "cat: ssh_chk.txt: No such file or directory" then
    exec_command(ssh_str + "rm -f ssh_chk.txt")
    puts "Finish!!"
else
    puts "Error!!"
end

