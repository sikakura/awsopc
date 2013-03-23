################################################################################
# encoding: utf-8
################################################################################
require 'rubygems'
require 'yaml'
require 'aws-sdk'
require 'date'
require 'logger'
################################################################################
today_string = DateTime.now.strftime("%Y-%m-%d")
now_dir = File.expand_path(File.dirname($0))
log_file = "#{now_dir}/#{$0}_#{today_string}.log"  
flag = true
$h = {}
$log = Logger.new(log_file)
################################################################################
def load_cfg_file

  dir = Dir.open( File.expand_path(File.dirname($0)) )
  dir.each { |name|
    if File.extname(name) == ".cfg" then
       config = YAML.load(File.read("#{File.expand_path(File.dirname($0))}/#{name}"))
       $h[File.basename(name,".cfg")] = config
    end
  }
  dir.close
end
################################################################################


################################################################################
def ec2_control_by_tag(tagname, command, region)

	config = YAML.load(File.read("config.yml"))
	config["ec2_endpoint"] = region
	AWS.config(config)
	$log.info( "tagname is #{tagname}, command is #{command}.")

	tagged_servers = AWS::EC2.new.instances.tagged('Name').tagged_values(tagname)
	if tagged_servers.count == 0
		$log.warn("#{tagname} is not found.")
	else
		tagged_servers.each{ |i|
			if command == "start"
				if i.status == :stopped
					$log.info("#{tagname}(id:#{i}) is going to start.")
					i.start
				end
			end
			if command == "stop"
				if i.status == :running
					$log.info("#{tagname}(id:#{i}) is going to stop.")
					i.stop
				end
			end
			if command == "status"
				$log.info("#{tagname}(id:#{i}) is " + i.status.to_s)
			end
		}
	end
end
################################################################################


################################################################################
def ec2_control_by_id(id, command, region)

	config = YAML.load(File.read("config.yml"))
	config["ec2_endpoint"] = region
	AWS.config(config)
	$log.info( "Instance-ID is #{id}, command is #{command}.")

	instance = AWS::EC2.new.instances[id]
	if instance.exists?
		if command == "start"
			if instance.status == :stopped
				$log.info("Instance-ID:#{id} is going to start.")
				instance.start
			end
		end
		if command == "stop"
			if instance.status == :running
				$log.info("Instance-ID:#{id} is going to stop.")
				instance.stop
			end
		end
		if command == "status"
			$log.info("Instance-ID:#{id} is " + instance.status.to_s)
		end
	else
		$log.warn("Instance-ID:#{id} is not found.")
	end
end
################################################################################


################################################################################
def ec2_backup_by_tag(tagname, generation, region)
  now_string = DateTime.now.strftime("%Y-%m-%d %H-%M-%S")
  config = YAML.load(File.read("config.yml"))
  config["ec2_endpoint"] = region
  AWS.config(config)
  $log.info( "tagname is #{tagname}, generation is #{generation}.")

  tagged_servers = AWS::EC2.new.instances.tagged('Name').tagged_values(tagname)
  if tagged_servers.count == 0
    $log.warn("#{tagname} is not found.")
  else
    tagged_servers.each{ |i|
      new_image = nil
      if i.status == :stopped
        $log.info("#{tagname}(id:#{i}) is going to backup.")
        new_image = i.create_image("Backup for #{tagname} on #{now_string}")
      else
        # wait for complete
        $log.info "waiting for stop server: #{tagname}"
        begin
          sleep 1
          target = AWS::EC2.new.instances[i.id]
        end until target.status == :stopped
        $log.info("#{tagname}(id:#{i}) is going to backup.")
        new_image = i.create_image("Backup for #{tagname}")
      end
      
      new_image.tag('date', :value => DateTime.now.strftime("%Y%m%d")) if new_image != nil
      new_image.tag('server', :value => tagname) if new_image != nil
    }
  end

  # delete image over generations
  tagged_images = AWS::EC2.new.images.tagged('server').tagged_values(tagname)
  if tagged_images.count == 0
    $log.warn("#{tagname}'s image is not found.")
  else
    # wait for complete
    begin
      all_check = true
      tagged_images = AWS::EC2.new.images.tagged('server').tagged_values(tagname)
      tagged_images.each{ |i|
        if i.state == :pending
          all_check = false
          $log.info("waiting for backup... #{i.name}")
          sleep 60
        end
      }
    end until all_check

    tagged_images.each{ |i|
      if i.state == :pending
	sleep 60 until i.state == :available
      end
    }
    image_hash = {}
    tagged_images.each{ |i|
	image_hash[ i.id ] = i.tags.date
    }
    count = 1
    image_hash.sort{|a,b| b[1] <=> a[1]}.each{|key,value|
      $log.info("#{key}:#{value}")
      if count > generation
        AWS::EC2.new.images[key].deregister
        $log.info("AMI(#{key}) is deregistered.")
      end
      count = count + 1
    }
  end
  
  # delete snapshot over generations
  
  
  
end
################################################################################

################################################################################
def ec2_backup_by_id(id, generation, region)
  now_string = DateTime.now.strftime("%Y-%m-%d %H-%M-%S")
  config = YAML.load(File.read("config.yml"))
  config["ec2_endpoint"] = region
  AWS.config(config)
  $log.info( "Instance-ID is #{id}, generation is #{generation}.")

  instance = AWS::EC2.new.instances[id]
  if instance.exists?
      new_image = nil
      if instance.status == :stopped
        $log.info("Instance-ID :#{id} is going to backup.")
        new_image = instance.create_image("Backup #{id} on #{now_string}")
      else
        # wait for complete
        $log.info "waiting for stop server: #{id}"
        begin
          sleep 5
          target = AWS::EC2.new.instances[id]
        end until target.status == :stopped
        $log.info("Instance-ID :#{id} is going to backup.")
        new_image = instance.create_image("Backup #{id} on #{now_string}")
      end
      new_image.tag('date', :value => DateTime.now.strftime("%Y%m%d%H%M%S")) if new_image != nil
      new_image.tag('server', :value => id) if new_image != nil
  else
    $log.warn("Instance-ID is #{id} is not found.")
  end

  # delete image over generations
  tagged_images = AWS::EC2.new.images.tagged('server').tagged_values(id)
  if tagged_images.count == 0
    $log.warn("#{id}'s image is not found.")
  else
    # wait for complete
    begin
      all_check = true
      tagged_images = AWS::EC2.new.images.tagged('server').tagged_values(id)
      tagged_images.each{ |i|
        if i.state == :pending
          all_check = false
          $log.info("waiting for backup... #{i.name}")
          sleep 60
        end
      }
    end until all_check

    image_hash = {}
    tagged_images.each{|i| image_hash[ i.id ] = i.tags.date }
    count = 1
    image_hash.sort{|a,b| b[1] <=> a[1]}.each{|key,value|
      $log.info("#{key}:#{value}")
      if count > generation
        AWS::EC2.new.images[key].deregister
        $log.info("AMI(#{key}) is deregistered.")
      end
      count = count + 1
    }
  end
  
  # delete snapshot over generations
  snapshot_hash = {}
  AWS::EC2.new.snapshots.with_owner(:self).each{|snap|
    if snap.description != nil
      if (snap.description).index(id) != nil
        snapshot_hash[ snap.id ] = snap.start_time
      end
    end
  }
  count = 1
  snapshot_hash.sort{|a,b| b[1] <=> a[1]}.each{|key,value|
    $log.info("#{key}:#{value}")
    if count > generation
      AWS::EC2.new.snapshots[key].delete
      $log.info("Snapshot(#{key}) is deleted.")
    end
    count = count + 1
  }
end
################################################################################


################################################################################
def query_cfg(str)
	now_hour = DateTime.now.strftime("%H").to_i
	wdays = ["Sunday","Monday","Tuesay","Wednesday","Thrsday","Friday","Saturday"]
	day = Time.now #=> Sun Dec 31 00:00:00 JST 2000
	$log.info("Today is #{wdays[day.wday]} and hour is #{now_hour}")
	
  $log.info(str)

	if now_hour > 0 then
		pre_hour = now_hour -1
	else
		pre_hour = ( 24 * 7 ) - 1
	end

	baseNumber = DateTime.now.wday * 24
	#現在の時間のビットと１時間前のビットを比較して相違があれば、出力
	if str.slice(pre_hour+baseNumber,1) != str.slice(now_hour+baseNumber,1) then
		return str.slice(now_hour+baseNumber,1)
	else
		return "99"
	end
end
################################################################################

################################################################################
def query_cfgs

  $h.each{ |key,value|
    config = value 
    response = query_cfg(config["schedule"])
    case response
    when "0"
      $log.info( "analyze result :0--> stop server." )
      ec2_control_by_id(config["servername"],"stop",config["region"])
    when "1"
      $log.info("analyze result :1--> start server.")
      ec2_control_by_id(config["servername"],"start",config["region"])
    when "2"
      $log.info("analyze result :2--> stop server & start backup.")
      ec2_control_by_id(config["servername"],"stop",config["region"])
      ec2_backup_by_id(config["servername"],config["generation"],config["region"])
    else
      $log.info("analyze result other.")
      ec2_control_by_id(config["servername"],"status",config["region"])
    end
  }

end
################################################################################

load_cfg_file
query_cfgs

