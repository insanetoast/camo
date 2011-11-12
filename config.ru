require 'rack/contrib'
require 'rack-rewrite'

use Rack::Static, :urls => %w(/images /stylesheets /javascripts /robots.txt /favicon.ico), :root => "public"
use Rack::ETag
use Rack::Rewrite do
  rewrite '/', '/index.html'
  rewrite %r{(.*)}, '$1.html', :if => lambda { |rack_env|
    html_file = File.join '.', 'public', rack_env['SCRIPT_NAME']
    full_path = File.absolute html_file
    File.exists? full_path
  }
end
run Rack::Directory.new('public')
