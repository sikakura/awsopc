################################################################################
# encoding: utf-8
################################################################################
require 'rubygems'
require 'yaml'
require 'aws-sdk'
require 'date'
require 'parallel'
################################################################################
class Tasks::AwsOperationTask

  def make_aws_config( config={} )
    aws_config = {}
    aws_config["access_key_id"] = config["access_key"]
    aws_config["secret_access_key"] = config["secret_key"]
    aws_config["ec2_endpoint"] = config["ec2_endpoint"]
    #aws_config["proxy_uri"] = "http://hostname.ad.local:8080"
    return aws_config
  end

  def ec2_control_by_id(command, config={})

    id = config["servername"]
    AWS.config(make_aws_config(config))
    Rails.logger.info( "Instance-ID is #{id}, command is #{command}.")

  	instance = AWS::EC2.new.instances[id]
  	if instance.exists?
  		if command == "start"
  			if instance.status == :stopped
  				Rails.logger.info("Instance-ID:#{id} is going to start.")
  				instance.start
  			end
  		end
  		if command == "stop"
  			if instance.status == :running
  				Rails.logger.info("Instance-ID:#{id} is going to stop.")
  				instance.stop
  			end
  		end
  		if command == "status"
  			Rails.logger.info("Instance-ID:#{id} is " + instance.status.to_s)
  		end
  	else
  		Rails.logger.warn("Instance-ID:#{id} is not found.")
  	end
  end

  def ec2_backup_by_id(config={})

    now_string = DateTime.now.strftime("%Y-%m-%d %H-%M-%S")
    id = config["servername"]
    generation = config["generation"]
    AWS.config(make_aws_config(config))
    Rails.logger.info( "Instance-ID is #{id}, generation is #{generation}.")

    instance = AWS::EC2.new.instances[id]
    if instance.exists?
        new_image = nil
        if instance.status == :stopped
          Rails.logger.info("Instance-ID :#{id} is going to backup.")
          new_image = instance.create_image("Backup #{id} on #{now_string}")
        else
          # wait for complete
          Rails.logger.info "waiting for stop server: #{id}"
          begin
            sleep 5
            target = AWS::EC2.new.instances[id]
          end until target.status == :stopped
          Rails.logger.info("Instance-ID :#{id} is going to backup.")
          new_image = instance.create_image("Backup #{id} on #{now_string}")
        end
        new_image.tag('date', :value => DateTime.now.strftime("%Y%m%d%H%M%S")) if new_image != nil
        new_image.tag('server', :value => id) if new_image != nil
    else
      Rails.logger.warn("Instance-ID is #{id} is not found.")
    end

    # delete image over generations
    tagged_images = AWS::EC2.new.images.tagged('server').tagged_values(id)
    if tagged_images.count == 0
      Rails.logger.warn("#{id}'s image is not found.")
    else
      # wait for complete
      begin
        all_check = true
        tagged_images = AWS::EC2.new.images.tagged('server').tagged_values(id)
        tagged_images.each{ |i|
          if i.state == :pending
            all_check = false
            Rails.logger.info("waiting for backup... #{i.name}")
            sleep 60
          end
        }
      end until all_check

      image_hash = {}
      tagged_images.each{|i| image_hash[ i.id ] = i.tags.date }
      count = 1
      image_hash.sort{|a,b| b[1] <=> a[1]}.each{|key,value|
        Rails.logger.info("#{key}:#{value}")
        if count > generation
          # AMI削除前に紐付いているEBSのsnapshot_idを配列（delete_target_ebs）に保持する
          delete_target_ebs = Array.new
          array_count = 0
          AWS::EC2.new.images[key].block_devices.each{|key|
            if key[:ebs] != nil
    		      delete_target_ebs[array_count] = key[:ebs][:snapshot_id]
    		      array_count = array_count + 1
    		    end
          }
          # AMI削除
          AWS::EC2.new.images[key].deregister
          Rails.logger.info("AMI(#{key}) is deregistered.")
          # snaphostの削除
          delete_target_ebs.each{ |key|
            AWS::EC2.new.snapshots[key].delete
            Rails.logger.info("Snaphost(#{key}) is deleted.")
          }
        end
        count = count + 1
      }
    end
    
    # delete snapshot over generations
    #snapshot_hash = {}
    #AWS::EC2.new.snapshots.with_owner(:self).each{|snap|
    #  if snap.description != nil
    #    if (snap.description).index(id) != nil
    #      snapshot_hash[ snap.id ] = snap.start_time
    #   end
    #  end
    #}
    #count = 1
    #snapshot_hash.sort{|a,b| b[1] <=> a[1]}.each{|key,value|
    #  Rails.logger.info("#{key}:#{value}")
    #  if count > generation
    #    AWS::EC2.new.snapshots[key].delete
    #    Rails.logger.info("Snapshot(#{key}) is deleted.")
    #  end
    #  count = count + 1
    #}
  end

  def schedule_analyze( str )
  	now_hour = DateTime.now.strftime("%H").to_i
  	wdays = ["Sunday","Monday","Tuesay","Wednesday","Thrsday","Friday","Saturday"]
  	day = Time.now #=> Sun Dec 31 00:00:00 JST 2000
  	Rails.logger.info("Today is #{wdays[day.wday]} and hour is #{now_hour}")
    Rails.logger.info(str)

  	if now_hour > 0 then
  		pre_hour = now_hour -1
  	else
  		#pre_hour = ( 24 * 7 ) - 1
  		if DateTime.now.wday == 0 then
  		  pre_hour = ( 24 * 7 ) - 1 #(24*7)-1=167
  		else
  		  pre_hour = -1
  		end
  	end

  	baseNumber = DateTime.now.wday * 24
  	Rails.logger.info("Compare pre-ind[#{pre_hour+baseNumber}] with now-ind[#{now_hour+baseNumber}]")
  	#現在の時間のビットと１時間前のビットを比較して相違があれば、出力
  	if str.slice(pre_hour+baseNumber,1) != str.slice(now_hour+baseNumber,1) then
  		return str.slice(now_hour+baseNumber,1)
  	else
  		return "99"
  	end
  end

  def aws_operation( config={} )
    response = schedule_analyze( config["schedule"] )
    case response
    when "0"
      Rails.logger.info( "analyze result :0--> stop server." )
      ec2_control_by_id("stop",config)
    when "1"
      Rails.logger.info("analyze result :1--> start server.")
      ec2_control_by_id("start",config)
    when "2"
      Rails.logger.info("analyze result :2--> stop server & start backup.")
      ec2_control_by_id("stop",config)
      ec2_backup_by_id(config)
    else
      Rails.logger.info("analyze result other.")
      ec2_control_by_id("status",config)
    end
  end

  def self.execute

    now = DateTime.now.strftime("%Y/%m/%d-%H:%M:%S")
    Rails.logger.info("*START IN PROCESS* DATE:#{now}***************************************")
    
    cron = Tasks::AwsOperationTask.new()
    if ARGV.count != 0
      Rails.logger.info("-Mode:arguments process-")
      ARGV.each{|address|
        Auth.where(:email => address).each{|auth|
          Rails.logger.info("-Start- Account:#{auth.email} ----------")
          config={}
          config["access_key"] = auth.access_key
          config["secret_key"] = auth.secret_key
          Server.where(:user_id => auth.user_id).each{|server|
            config["servername"] = server.name
            config["generation"] = server.generation
            config["ec2_endpoint"] = server.region
            config["schedule"] = server.schedule
            cron.aws_operation( config )
          }
          Rails.logger.info("-E n d- Account:#{auth.email} ----------")
        }
      }
    else
      Rails.logger.info("-Mode:batch process-")
      Auth.all.each{|auth|
        Rails.logger.info("-Start- Account:#{auth.email} ----------")
        config={}
        config["access_key"] = auth.access_key
        config["secret_key"] = auth.secret_key
        Server.where(:user_id => auth.user_id).each{|server|
          config["servername"] = server.name
          config["generation"] = server.generation
          config["ec2_endpoint"] = server.region
          config["schedule"] = server.schedule
          cron.aws_operation( config )
        }
        Rails.logger.info("-E n d- Account:#{auth.email} ----------")
      }
      end
    now = DateTime.now.strftime("%Y/%m/%d-%H:%M:%S")
    Rails.logger.info("*END IN PROCESS* DATE:#{now}***************************************")
  end
end
