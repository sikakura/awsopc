class ApplicationController < ActionController::Base
  protect_from_forgery

  def now_dir
    return File.expand_path(File.dirname($0))
  end

  def work_dir
    now_dir = File.expand_path(File.dirname($0))
    return "#{now_dir}/#{current_user.email}"
  end

  def create_work_dir
    FileUtils.mkdir_p(work_dir) unless FileTest.exist?(work_dir)
  end

  def delete_work_dir
    # サブディレクトリを階層が深い順にソートした配列を作成
    dirlist = Dir::glob(work_dir + "**/").sort {
      |a,b| b.split('/').size <=> a.split('/').size
    }
    # サブディレクトリ配下の全ファイルを削除後、サブディレクトリを削除
    dirlist.each {|d|
      Dir::foreach(d) {|f|
        File::delete(d+f) if ! (/\.+$/ =~ f)
      }
      Dir::rmdir(d)
    }
  end

  def create_auth_file(access_key,secret_key)
    auth_file = open("#{work_dir}/config.yml","w")
    auth_file.write("access_key_id: #{access_key}\n")
    auth_file.write("secret_access_key: #{secret_key}\n")
    auth_file.close
  end

  def copy_cron_script
    FileUtils.copy("#{now_dir}/ec2_cron.rb", "#{work_dir}/ec2_cron.rb")
  end
  
end
