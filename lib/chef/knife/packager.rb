$: << File.expand_path(File.dirname(__FILE__))

require 'chef/knife'
require 'fileutils'
require 'digest/md5'
require 'mime/types'
require 'berkshelf/cli'
require 's3'
require 'pathname'
require 'yaml'
require "voxconfig"

module Packager

  class Packager < Chef::Knife

    deps do
    end

    banner "knife packager"

    def run
      Berkshelf::Config.new
      @config = VoxConfig.new(Dir.pwd)
      get_dependencies
      pkg = package_files
      upload_cookbooks(pkg)
    end


    def get_dependencies()
      puts ui.highline.color  "Gathering cookbook dependencies", :green
      FileUtils.rm_rf("/tmp/cookbooks")
      `berks install --path /tmp/cookbooks`
    end

    def package_files
      puts ui.highline.color  "== Packaging cookbook", :green
      `cd /tmp; tar zcf #{get_cookbook_name}.#{get_cookbook_version}.tgz ./cookbooks`
      return "/tmp/#{get_cookbook_name}.#{get_cookbook_version}.tgz"
    end

    def get_cookbook_version
      IO.read(Berkshelf.find_metadata).match(/^version.*/).to_s.split('"')[1]
    end

    def get_folder_name
      if @config.project_name
        return @config.project_name
      else
        get_cookbook_name
      end
    end

    def get_cookbook_name
      name = IO.read(Berkshelf.find_metadata).match(/^name.*/).to_s.split('"')[1]
      if name.nil?
        return Dir.pwd.split("/")[-1]
      else
        return name
      end

    end

    def upload_cookbooks(file)
      service = S3::Service.new({
                                  :access_key_id     =>  @config.aws_key,
                                  :secret_access_key =>  @config.aws_secret
      })
      bucket = service.buckets.find(@config.bucket_name)
      puts ui.highline.color  "== Uploading cookbook [#{file}]", :green

      ## Only upload files, we're not interested in directories
      if File.file?(file)
        remote_file = "#{get_folder_name}/#{file.split("/")[-1]}"

        begin
          obj = bucket.objects.find_first(remote_file)
          if yes? "This cookbook version already exists, do you want to overwrite it ?", :red
            puts ui.highline.color  "== Ok, we'll overwrite it", :green
          else
            puts ui.highline.color  "== Ok, exiting", :green
            exit 0
          end
        rescue
          obj = nil
        end

        puts ui.highline.color  "== Uploading #{@config.bucket_name}/#{get_folder_name}/#{file.split("/")[-1]}", :green
        obj = bucket.objects.build(remote_file)
        obj.content = open(file)
        obj.content_type = MIME::Types.type_for(file).to_s
        obj.save

      end
      puts ui.highline.color  "== Done syncing #{file.split('/')[-1]}",:green
    end

  end
end
