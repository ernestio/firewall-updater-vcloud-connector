# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require 'rubygems'
require 'bundler/setup'
require 'json'

require 'myst'

include Myst::Providers::VCloud

def update_firewall(data)
  usr = ENV['DT_USR'] || data[:datacenter_username]
  pwd = ENV['DT_PWD'] || data[:datacenter_password]
  credentials = usr.split('@')
  provider = Provider.new(endpoint:     data[:vcloud_url],
                          organisation: credentials.last,
                          username:     credentials.first,
                          password:     pwd)

  datacenter = provider.datacenter(data[:datacenter_name])
  router = datacenter.router(data[:router_name])

  firewall = router.firewall
  firewall.purge_rules

  data[:rules].each do |rule|
    firewall.add_rule({ ip: rule[:source_ip], port_range: rule[:source_port] },
                      { ip: rule[:destination_ip], port_range: rule[:destination_port] }, rule[:protocol].to_sym)
  end

  router.update_service(firewall)

  'firewall.update.vcloud.done'
rescue => e
  puts e
  puts e.backtrace
  'firewall.update.vcloud.error'
end

unless defined? @@test
  @data       = { id: SecureRandom.uuid, type: ARGV[0] }
  @data.merge! JSON.parse(ARGV[1], symbolize_names: true)
  original_stdout = $stdout
  $stdout = StringIO.new
  begin
    @data[:type] = update_firewall(@data)
    if @data[:type].include? 'error'
      @data['error'] = { code: 0, message: $stdout.string.to_s }
    end

  ensure
    $stdout = original_stdout
  end

  puts @data.to_json
end
