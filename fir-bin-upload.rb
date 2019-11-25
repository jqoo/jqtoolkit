#!/usr/bin/ruby

require 'json'
require 'net/https'
require 'uri'

def post(url, param)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == "https"
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    req = Net::HTTP::Post.new(uri.path, {
                              'Content-Type' => 'application/json'
                              })
    req.body = param.to_json
    res = http.request(req)
    data = JSON.parse(res.body)
    return data
end

args = ARGV.select{|e| e =~ /^--/}
       .map{|e| e[2..-1] }
       .inject({}) { |m,e|
    i = e.index('=')
    if i != nil
        m[e[0...i]] = e[i+1..-1]
    else
        m[e] = 0
    end
    next m
}

required_keys = ['type', 'bundle_id', 'api_token', 'file', 'version']
doc = 'fir-bin-upload.rb --type=[android|ios] --bundle_id=[bundle_id] --api_token=[api_token] --file=[ipa_path] --version=[version] --changelog=[changelog]'

if !required_keys.inject(true){|v,e| v && args.has_key?(e)}
    puts doc
    exit
end

auth = post('http://api.fir.im/apps', {
     :type => args['type'],
     :bundle_id => args['bundle_id'],
     :api_token => args['api_token']
     })

puts auth

binary = auth['cert']['binary']

parts = {
    'key' => binary['key'],
    'token' => binary['token'],
    'file' => "@#{args['file']}",
    'x:name' => "#{args['file'].split('/')[-1]}",
    'x:version' => args['version'],
    'x:build' => "#{Time.now}",
    'x:release_type' => 'Adhoc',
    'x:changelog' => args['changelog']
}

parts_str = parts.map {|p| "-F '#{p[0]}=#{p[1]}'" }.join(' ')

# http2容易出现问题：curl: (92) HTTP/2 stream 0 was not closed cleanly: PROTOCOL_ERROR (err 1)
# result = "curl --http1.1 #{parts_str} #{binary['upload_url']}"
result = `curl --http1.1 #{parts_str} #{binary['upload_url']}`


puts result

