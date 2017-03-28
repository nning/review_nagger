require 'httparty'
require 'rufus-scheduler'
require 'singleton'
require 'slack-ruby-client'

$:.unshift(File.join(File.dirname(__FILE__), 'review_nagger'))
require 'app_config'
require 'git_lab'
require 'nagger'
