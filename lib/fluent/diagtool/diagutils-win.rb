#
# Fluentd
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#

require 'logger'
require 'fileutils'
require 'fluent/diagtool/collectutils'
include Diagtool

# Splitting the implementation just to easily provide minimal support for Windows.
# If we are going to support more features for Windows, it would be better to remove
# this file and improve the origin file "diagutils.rb".
module Diagtool
  class DiagUtils
    def initialize(params)
      time = Time.new
      @time_format = time.strftime("%Y%m%d%0k%M%0S")
      @conf = parse_diagconf(params)
      if fluent_package?
        @conf[:package_name] = "fluent-package"
        @conf[:service_name] = "fluentd"
      else
        @conf[:package_name] = "td-agent"
        @conf[:service_name] = "td-agent"
      end
    end
    
    def run_precheck()
      raise "[Precheck] Precheck feature is not supported on Windows."
    end

    def run_diagtool()
      @conf[:time] = @time_format
      @conf[:workdir] = @conf[:basedir] + '/' + @time_format
      @conf[:outdir] = @conf[:workdir] + '/output'
      FileUtils.mkdir_p(@conf[:workdir])
      FileUtils.mkdir_p(@conf[:outdir])
      diaglog = @conf[:workdir] + '/diagtool.output'

      @logger = Logger.new(STDOUT, formatter: proc {|severity, datetime, progname, msg|
        "#{datetime}: [Diagtool] [#{severity}] #{msg}\n"
      })
      @logger_file = Logger.new(diaglog, formatter: proc {|severity, datetime, progname, msg|
        "#{datetime}: [Diagtool] [#{severity}] #{msg}\n"
      })
      diaglogger_info("Parsing command options...")
      diaglogger_info("   Option : Output directory = #{@conf[:basedir]}")

      loglevel = 'WARN'
      diaglogger_info("Initializing parameters...")
      c = CollectUtils.new(@conf, loglevel, on_windows: true)

      diaglogger_info("[Collect] Collecting #{@conf[:package_name]} gem information...")
      tdgem = c.collect_tdgems()
      diaglogger_info("[Collect] #{@conf[:package_name]} gem information is stored in #{tdgem}")

      gem_info = c.collect_manually_installed_gems(tdgem)
      diaglogger_info("[Collect] #{@conf[:package_name]} gem information (bundled by default) is stored in #{gem_info[:bundled]}")
      diaglogger_info("[Collect] #{@conf[:package_name]} manually installed gem information is stored in #{gem_info[:local]}")
      local_gems = File.read(gem_info[:local]).lines(chomp: true)
      unless local_gems == [""]
        diaglogger_info("[Collect] #{@conf[:package_name]} manually installed gems:")
        local_gems.each do |gem|
          diaglogger_info("[Collect]   * #{gem}")
        end
      end
    end

    def parse_diagconf(params)
      options = {
        :precheck => '', :basedir => '', :type =>'', :mask => '', :words => [], :wfile => '', :seed => '', :tdconf =>'', :tdlog => ''
      }

      supported_options = [:type, :output]

      unless params[:type] == nil || params[:type] == 'fluentd'
        raise "fluentd type '-t' only supports 'fluentd' on Windows."
      end
      options[:type] = 'fluentd'

      if params[:output] != nil
        if Dir.exist?(params[:output])
          options[:basedir] = params[:output]
        else
          raise "output directory '#{params[:output]}' does not exist"
        end
      else
        raise "output directory '-o' must be specified"
      end

      params.keys.each do |option|
        unless supported_options.include?(option)
          raise "#{option} is not supported on Windows."
        end
      end

      return options
    end
    
    def diaglogger_debug(str)
      @logger.debug(str)
      @logger_file.debug(str)
    end
    
    def diaglogger_info(str)
      @logger.info(str)
      @logger_file.info(str)
    end
    
    def diaglogger_warn(str)
      @logger.warn(str)
      @logger_file.warn(str)
    end
    
    def diaglogger_error(str)
      @logger.error(str)
      @logger_file.error(str)
    end

    def fluent_package?
      File.exist?("/etc/fluent/fluentd.conf") || File.exist?("/opt/fluent/bin/fluentd")
    end
  end
end
