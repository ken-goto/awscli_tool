#!/bin/sh
wget http://peak.telecommunity.com/dist/ez_setup.py
python ez_setup.py
easy_install pip
pip install awscli
mkdir ~/.aws
touch ~/.aws/config
printf "[default]\r\n" >> ~/.aws/config
printf "aws_access_key_id = AKIAJSG6AJ3H6KPTXMFQ\r\n" >> ~/.aws/config
printf "aws_secret_access_key = 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\r\n" >> ~/.aws/config
printf "region = ap-northeast-1\r\n" >> ~/.aws/config
aws ec2 describe-instances --dry-run

# jq インストール
yum install -y jq

# rubyインストール
yum check-update
yum update -y
yum install -y ruby ruby-devel ruby-docs
ruby -v

# gemsインストール
wget http://rubyforge.org/frs/download.php/76729/rubygems-1.8.25.tgz
tar zxvf rubygems-1.8.25.tgz
cd rubygems-1.8.25
ruby setup.rb
gem -v

# rubyライブラリインストール
gem install json