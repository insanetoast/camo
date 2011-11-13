require 'rack/contrib'
require 'rack-rewrite'

require 'erb'
require 'pony'
require 'cgi'

module Rack
  class FormMail
    def initialize app, options
      @app =                    app
      @to =                     Array(options[:to])
      @from =                   options[:from] || "registration@mydaddyisasoldier.org"
      @subject =                options[:subject] || "Event Registration"
      @template =               ERB.new TEMPLATE
      @path =                   options[:path]
      @method =                 options[:method].to_s.upcase
    end

    def call env
      send_notification env if send_notification? env
      @app.call env
    end

    def send_notification? env
      return false unless env['PATH_INFO'] == @path
      return false unless env['REQUEST_METHOD'] == @method
      true
    end

    def send_notification env
      body = @template.result binding
      Pony.mail :to => @to, :from => @from, :subject  => @subject, :body => body, :via => :smtp, :via_options => {
  :address              => ENV['EMAIL_SERVER'],
  :port                 => ENV['EMAIL_PORT'],
  :enable_starttls_auto => true,
  :user_name            => ENV['EMAIL_USERNAME'],
  :password             => ENV['EMAIL_PASSWORD'],
  :authentication       => :plain,
  :domain               => ENV['EMAIL_DOMAIN']
}
    end

    def extract_body env
      if io = env['rack.input']
        io.rewind if io.respond_to? :rewind
        body = io.read
        pairs = body.split /\&/
        pairs.sort.map do |pair|
          key, value = pair.split /\=/, 2
          "%-40s | %s" % [ CGI.unescape(key), CGI.unescape(value).gsub(/\n/, "\n" + (' ' * 40) + ' | ') ]
        end.join("\n")
      end
    end

    TEMPLATE = (<<-'EMAIL').gsub(/^ {4}/, '')
    Hello,

    Someone registered for an event on the mydaddyisasoldier.org site. Details
    follow:

    <%= extract_body env %>
    EMAIL
  end
end

use Rack::Static, :urls => %w(/images /stylesheets /javascripts /robots.txt /favicon.ico), :root => "public"
use Rack::ETag
use Rack::FormMail, :path => '/send_details', :method => :post, :to => ENV['EMAIL_DESTINATION']
use Rack::Rewrite do
  rewrite '/', '/index.html'
  rewrite %r{(.*)}, '$1.html', :if => lambda { |rack_env|
    html_file = File.join '.', 'public', rack_env['SCRIPT_NAME']
    full_path = File.absolute_path html_file
    File.exists? full_path
  }
end
run Rack::Directory.new('public')
