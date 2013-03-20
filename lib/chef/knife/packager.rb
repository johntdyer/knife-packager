$: << File.expand_path(File.dirname(__FILE__))

# workaround for https://github.com/RiotGames/berkshelf/issues/270
lang = ENV['LANG']
require 'berkshelf/cli'
ENV['LANG'] = lang unless lang.nil?

require 'chef/knife'
require 'digest/md5'
require 'fileutils'
require 'mime/types'
require 'pathname'
require 's3'
require 'tmpdir'
require 'voxconfig'
require 'yaml'

module Packager

  class Packager < Chef::Knife

    deps do
    end

    banner "knife packager"

     option :"version-override",
            :long => "--version-override VERSION",
            :description => "Override version number of uploaded cookook",
            :default => nil


    def run
        $stdout.sync = true
        @cookbook_version = get_cookbook_version(config[:"version-override"])
        Berkshelf::Config.new
        @config = VoxConfig.new(Dir.pwd)
        @tmp = Dir.mktmpdir
        get_dependencies
        pkg = package_files
        upload_cookbooks(pkg)
        FileUtils.remove_entry_secure(@tmp)
    end


    def get_dependencies()
      puts ui.highline.color  "Gathering cookbook dependencies (this will take a minute)", :green
      STDOUT.sync = true
      berks =  `berks install --path #{@tmp}/cookbooks`
      unless $?.exitstatus == 0
        puts ui.highline.color  "Failed to gather dependencies", :red
        exit 3
      end
      puts berks
    end

    def package_files
      puts ui.highline.color  "== Packaging cookbook", :green
      `cd #{@tmp}; tar zcf #{get_cookbook_name}.#{@cookbook_version}.tgz ./cookbooks`
      unless $?.exitstatus == 0
        puts ui.highline.color  "Failed to archive cookbooks", :red
        exit 3
      end
      return "#{@tmp}/#{get_cookbook_name}.#{@cookbook_version}.tgz"
    end

    def get_cookbook_version(params)
        if params
            return params
        else
            IO.read(Berkshelf.find_metadata).match(/^version.*/).to_s.split('"')[1]
        end
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

        puts ui.highline.color  "== Uploading http://#{@config.bucket_name}/#{get_folder_name}/#{file.split("/")[-1]}", :blue
        obj = bucket.objects.build(remote_file)
        obj.content = open(file)
        obj.content_type = MIME::Types.type_for(file).to_s
        obj.save

      end
      puts ui.highline.color  "== Done syncing #{file.split('/')[-1]}",:green
    end

  end
end
